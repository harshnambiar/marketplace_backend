import Error "mo:base/Error";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import T "dip721_types";

actor class DRC721(_name : Text, _symbol : Text) {

    //Using DIP721 standard, adapted from https://github.com/SuddenlyHazel/DIP721/blob/main/src/DIP721/DIP721.mo
    private stable var tokenPk : Nat = 0;

    public type CollectionMetadata = {
        name: Text;
        logo: Text;
        symbol: Text;
        custodians: [Principal];
        created_at: Nat64;
        upgraded_at: Nat64;
        max_items: Nat64;
    };

    public type Stats = {
        total_transactions: Nat;
        total_supply: Nat;
        cycles: Nat;
        total_unique_holders: Nat;
    };

    public type GenericValue = {
        #boolContent: Bool;
        #textContent: Text;
        #blobContent: [Nat8];
        #principal: Principal;
        #nat8Content: Nat8;
        #nat16Content: Nat16;
        #nat32Content: Nat32;
        #nat64Content: Nat64;
        #natContent: Nat;
        #int8Content: Int8;
        #int16Content: Int16;
        #int32Content: Int32;
        #int64Content: Int64;
        #intContent: Int;
        #floatContent: Float;
        #nestedContent: [(Text, GenericValue)];
    };
    
    public type TokenMetadata = {
        token_identifier: Nat;
        owner: ?Principal;
        operator_: ?Principal;
        is_burned: Bool;
        properties: [(Text, GenericValue)];
        minted_at: Nat64;
        minted_by: Principal;
        transferred_at: ?Nat64;
        transferred_by: ?Principal;
        approved_at: ?Nat64;
        approved_by: ?Principal;
        burned_at: ?Nat64;
        burned_by: ?Principal;
        collection: ?CollectionMetadata;
    };

    public type TxEvent = {
        time: Nat64;
        caller: Principal;
        operation: Text;
        details: [(Text, GenericValue)];
    };

    
    public type SupportedInterface = {
        #approval;
        #mint;
        #burn;
        #transactionHistory;
    };
    
    public type NftError = {
        #unauthorizedOwner;
        #unauthorizedOperator;
        #ownerNotFound;
        #operatorNotFound;
        #tokenNotFound;
        #existedNFT;
        #selfApprove;
        #selfTransfer;
        #txNotFound;
        #other;
    };

    

    private stable var tokenURIEntries : [(T.TokenId, Text)] = [];
    private stable var tokenMetadataEntries : [(Text, TokenMetadata)] = [];
    private stable var ownersEntries : [(T.TokenId, Principal)] = [];
    private stable var balancesEntries : [(Principal, Nat)] = [];
    private stable var tokenApprovalsEntries : [(T.TokenId, Principal)] = [];
    private stable var operatorApprovalsEntries : [(Principal, [Principal])] = [];
    private stable var activeAuctionEntries : [(T.TokenId, Nat)] = [];
    private stable var auctionApplicationEntries : [(Text, Nat)] = [];  

    private let tokenURIs : HashMap.HashMap<T.TokenId, Text> = HashMap.fromIter<T.TokenId, Text>(tokenURIEntries.vals(), 10, Nat.equal, Hash.hash);
    private let tokenMetadataHash : HashMap.HashMap<Text, TokenMetadata> = HashMap.fromIter<Text, TokenMetadata>(tokenMetadataEntries.vals(), 10, Text.equal, Text.hash);
    private let owners : HashMap.HashMap<T.TokenId, Principal> = HashMap.fromIter<T.TokenId, Principal>(ownersEntries.vals(), 10, Nat.equal, Hash.hash);
    private let balances : HashMap.HashMap<Principal, Nat> = HashMap.fromIter<Principal, Nat>(balancesEntries.vals(), 10, Principal.equal, Principal.hash);
    private let tokenApprovals : HashMap.HashMap<T.TokenId, Principal> = HashMap.fromIter<T.TokenId, Principal>(tokenApprovalsEntries.vals(), 10, Nat.equal, Hash.hash);
    private let operatorApprovals : HashMap.HashMap<Principal, [Principal]> = HashMap.fromIter<Principal, [Principal]>(operatorApprovalsEntries.vals(), 10, Principal.equal, Principal.hash);
    private let activeAuctions : HashMap.HashMap<T.TokenId, Nat> = HashMap.fromIter<T.TokenId, Nat>(activeAuctionEntries.vals(), 10, Nat.equal, Hash.hash);
    private let auctionApplications : HashMap.HashMap<Text, Nat> = HashMap.fromIter<Text, Nat>(auctionApplicationEntries.vals(), 10, Text.equal, Text.hash);
    
    
    public shared func balanceOf(p : Principal) : async ?Nat {
        return balances.get(p);
    };

    public shared func ownerOf(tokenId : T.TokenId) : async ?Principal {
        return _ownerOf(tokenId);
    };

    public shared query func tokenURI(tokenId : T.TokenId) : async ?Text {
        return _tokenURI(tokenId);
    };

    public shared query func name() : async Text {
        return _name;
    };

    public shared query func symbol() : async Text {
        return _symbol;
    };

    public shared func isApprovedForAll(owner : Principal, opperator : Principal) : async Bool {
        return _isApprovedForAll(owner, opperator);
    };

    public shared(msg) func approve(to : Principal, tokenId : T.TokenId) : async () {
        switch(_ownerOf(tokenId)) {
            case (?owner) {
                 assert to != owner;
                 assert msg.caller == owner or _isApprovedForAll(owner, msg.caller);
                 _approve(to, tokenId);
            };
            case (null) {
                throw Error.reject("No owner for token")
            };
        }
    };

    public shared func getApproved(tokenId : Nat) : async Principal {
        switch(_getApproved(tokenId)) {
            case (?v) { return v };
            case null { throw Error.reject("None approved")}
        }
    };

    public shared(msg) func setApprovalForAll(op : Principal, isApproved : Bool) : () {
        assert msg.caller != op;

        switch (isApproved) {
            case true {
                switch (operatorApprovals.get(msg.caller)) {
                    case (?opList) {
                        var array = Array.filter<Principal>(opList,func (p) { p != op });
                        array := Array.append<Principal>(array, [op]);
                        operatorApprovals.put(msg.caller, array);
                    };
                    case null {
                        operatorApprovals.put(msg.caller, [op]);
                    };
                };
            };
            case false {
                switch (operatorApprovals.get(msg.caller)) {
                    case (?opList) {
                        let array = Array.filter<Principal>(opList, func(p) { p != op });
                        operatorApprovals.put(msg.caller, array);
                    };
                    case null {
                        operatorApprovals.put(msg.caller, []);
                    };
                };
            };
        };
        
    };

    public shared(msg) func transferFrom(from : Principal, to : Principal, tokenId : Nat) : () {
        assert _isApprovedOrOwner(msg.caller, tokenId);

        _transfer(from, to, tokenId);
    };

    // Mint without authentication
    public func mint_principal(uri : Text, meta : TokenMetadata, principal : Principal) : async Nat {
        tokenPk += 1;
        _mint(principal, tokenPk, uri, meta);
        return tokenPk;
    };

    // Mint requires authentication in the frontend as we are using caller.
     public shared ({caller}) func mint(uri : Text, meta : TokenMetadata) : async Nat {
        tokenPk += 1;
        _mint(caller, tokenPk, uri, meta);
        return tokenPk;
    };

    //To hold an auction for owned NFT
    public shared ({caller}) func auction(t : T.TokenId, minSale : Nat) : async Bool {
        let tokenOwner = owners.get(t);
        switch (tokenOwner) {
            case null {
                return false;
            };
            case (?principal) {
                if (principal != caller){
                    return false;
                } 
                else {
                    activeAuctions.put(t,minSale);
                    return true;
                };
            };
        };
    };

    // Internal

    private func _ownerOf(tokenId : T.TokenId) : ?Principal {
        return owners.get(tokenId);
    };

    private func _tokenURI(tokenId : T.TokenId) : ?Text {
        return tokenURIs.get(tokenId);
    };

    private func _tokenMetadata(uri: Text) : ?TokenMetadata {
        return tokenMetadataHash.get(uri);
    };

    private func _isApprovedForAll(owner : Principal, opperator : Principal) : Bool {
        switch (operatorApprovals.get(owner)) {
            case(?whiteList) {
                for (allow in whiteList.vals()) {
                    if (allow == opperator) {
                        return true;
                    };
                };
            };
            case null {return false;};
        };
        return false;
    };

    private func _approve(to : Principal, tokenId : Nat) : () {
        tokenApprovals.put(tokenId, to);
    };

    private func _removeApprove(tokenId : Nat) : () {
        let _ = tokenApprovals.remove(tokenId);
    };

    private func _exists(tokenId : Nat) : Bool {
        return Option.isSome(owners.get(tokenId));
    };

    private func _getApproved(tokenId : Nat) : ?Principal {
        assert _exists(tokenId) == true;
        switch(tokenApprovals.get(tokenId)) {
            case (?v) { return ?v };
            case null {
                return null;
            };
        }
    };

    private func _hasApprovedAndSame(tokenId : Nat, spender : Principal) : Bool {
        switch(_getApproved(tokenId)) {
            case (?v) {
                return v == spender;
            };
            case null { return false}
        }
    };

    private func _isApprovedOrOwner(spender : Principal, tokenId : Nat) : Bool {
        assert _exists(tokenId);
        var owner = Principal.fromText("");
        switch (_ownerOf(tokenId)){
            case null {
                owner := Principal.fromText("");
            };
            case (?principal){
                owner := principal;
            };
        };
        return spender == owner or _hasApprovedAndSame(tokenId, spender) or _isApprovedForAll(owner, spender);
    };

    private func _transfer(from : Principal, to : Principal, tokenId : Nat) : () {
        assert _exists(tokenId);
        var owner = Principal.fromText("");
        switch (_ownerOf(tokenId)){
            case null {
                owner := Principal.fromText("");
            };
            case (?principal){
                owner := principal;
            };
        };
        assert owner == from;

        // Bug in HashMap https://github.com/dfinity/motoko-base/pull/253/files
        // this will throw unless you patch your file
        _removeApprove(tokenId);

        _decrementBalance(from);
        _incrementBalance(to);
        owners.put(tokenId, to);
    };

    private func _incrementBalance(address : Principal) {
        switch (balances.get(address)) {
            case (?v) {
                balances.put(address, v + 1);
            };
            case null {
                balances.put(address, 1);
            }
        }
    };

    private func _decrementBalance(address : Principal) {
        switch (balances.get(address)) {
            case (?v) {
                balances.put(address, v - 1);
            };
            case null {
                balances.put(address, 0);
            }
        }
    };

    private func _mint(to : Principal, tokenId : Nat, uri : Text, meta : TokenMetadata) : () {
        assert not _exists(tokenId);

        _incrementBalance(to);
        owners.put(tokenId, to);
        tokenURIs.put(tokenId,uri);
        tokenMetadataHash.put(uri,meta);
    };

    private func _burn(tokenId : Nat) {
        var owner = Principal.fromText("");
        switch (_ownerOf(tokenId)){
            case null {
                owner := Principal.fromText("");
            };
            case (?principal){
                owner := principal;
            };
        };
        assert Principal.toText(owner) != "";

        _removeApprove(tokenId);
        _decrementBalance(owner);

        ignore owners.remove(tokenId);
    };

    system func preupgrade() {
        tokenURIEntries := Iter.toArray(tokenURIs.entries());
        tokenMetadataEntries := Iter.toArray(tokenMetadataHash.entries());
        ownersEntries := Iter.toArray(owners.entries());
        balancesEntries := Iter.toArray(balances.entries());
        tokenApprovalsEntries := Iter.toArray(tokenApprovals.entries());
        operatorApprovalsEntries := Iter.toArray(operatorApprovals.entries());
        activeAuctionEntries := Iter.toArray(activeAuctions.entries());
        auctionApplicationEntries := Iter.toArray(auctionApplications.entries());
        
    };

    system func postupgrade() {
        tokenURIEntries := [];
        tokenMetadataEntries := [];
        ownersEntries := [];
        balancesEntries := [];
        tokenApprovalsEntries := [];
        operatorApprovalsEntries := [];
        auctionApplicationEntries := [];
        activeAuctionEntries := [];
    };
};
