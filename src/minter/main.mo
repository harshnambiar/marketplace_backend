import Error "mo:base/Error";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import T "dip721_types";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
//import Token "canister:token";

actor class DRC721(_name : Text, _symbol : Text, _tags: [Text], _publisher : Principal, _royalty: Principal) {

    //Using DIP721 standard, adapted from https://github.com/SuddenlyHazel/DIP721/blob/main/src/DIP721/DIP721.mo
    private stable var tokenPk : Nat = 0;

    public type CollectionMetadata = {
        name: Text;
        logo: Text;
        symbol: Text;
        tags: [Text];
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
        //properties: [(Text, GenericValue)];
        properties: [(Text,Text)];
        minted_at: Int;
        minted_by: Principal;
        transferred_at: ?Int;
        transferred_by: ?Principal;
        approved_at: ?Nat64;
        approved_by: ?Principal;
        burned_at: ?Nat64;
        burned_by: ?Principal;
        collection: ?CollectionMetadata;
    };

    func toTokenMetadata(tid: Nat, _owner: Principal, mdVal: [(Text,Text)]) : TokenMetadata{
        var gv: GenericValue =     #textContent "Testing Session";
        var output : TokenMetadata = {
            token_identifier = tid;
            owner = ?(_owner);
            operator_ = null;
            is_burned = false;
            //properties = [("Purpose",gv)];
            properties = mdVal;
            minted_at = Time.now();
            minted_by = _owner;
            transferred_at = null;
            transferred_by = null;
            approved_at = null;
            approved_by = null;
            burned_at = null;
            burned_by = null;
            collection = null;
        };
        return output;
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

    public type TxReceipt = {
        #Ok: Nat;
        #Err: {
            #InsufficientAllowance;
            #InsufficientBalance;
            #ErrorOperationStyle;
            #Unauthorized;
            #LedgerTrap;
            #ErrorTo;
            #Other: Text;
            #BlockUsed;
            #AmountTooSmall;
            #WrongCode;
            #NotEnoughUnlockedTokens;
            #IncompatibleSpecialTransferCombination;
        };
    };

    

    private stable var tokenURIEntries : [(T.TokenId, Text)] = [];
    private stable var tokenMetadataEntries : [(Text, TokenMetadata)] = [];
    private stable var ownersEntries : [(T.TokenId, Principal)] = [];
    private stable var balancesEntries : [(Principal, Nat)] = [];
    private stable var propertiesEntries : [(T.TokenId, [(Text,Text)])] = [];
    private stable var propertyFrequencyEntries : [(Text, Nat)] = [];
    private stable var tokenApprovalsEntries : [(T.TokenId, Principal)] = [];
    private stable var operatorApprovalsEntries : [(Principal, [Principal])] = [];
    private stable var activeAuctionEntries : [(T.TokenId, Nat)] = [];
    private stable var auctionApplicationEntries : [(Text, Nat)] = [];  
    private stable var nftPriceEntries : [(T.TokenId, Nat)] = [];
    private stable var nftUpvoteEntries : [(T.TokenId, Nat)] = [];
    private stable var nftDownvoteEntries : [(T.TokenId, Nat)] = [];
    private stable var upvoteRecordEntries : [(T.TokenId, [Principal])] = [];
    private stable var downvoteRecordEntries : [(T.TokenId, [Principal])] = [];
    private stable var equippedEntries: [(T.TokenId, T.TokenId)] = [];
    private stable var occupiedEntries: [(T.TokenId, Bool)] = [];

    private let tokenURIs : HashMap.HashMap<T.TokenId, Text> = HashMap.fromIter<T.TokenId, Text>(tokenURIEntries.vals(), 10, Nat.equal, Hash.hash);
    private let tokenMetadataHash : HashMap.HashMap<Text, TokenMetadata> = HashMap.fromIter<Text, TokenMetadata>(tokenMetadataEntries.vals(), 10, Text.equal, Text.hash);
    private let owners : HashMap.HashMap<T.TokenId, Principal> = HashMap.fromIter<T.TokenId, Principal>(ownersEntries.vals(), 10, Nat.equal, Hash.hash);
    private let balances : HashMap.HashMap<Principal, Nat> = HashMap.fromIter<Principal, Nat>(balancesEntries.vals(), 10, Principal.equal, Principal.hash);
    private let properties : HashMap.HashMap<T.TokenId, [(Text,Text)]> = HashMap.fromIter<T.TokenId, [(Text,Text)]>(propertiesEntries.vals(), 10, Nat.equal, Hash.hash);
    private let propertyFrequencies : HashMap.HashMap<Text, Nat> = HashMap.fromIter<Text, Nat>(propertyFrequencyEntries.vals(), 10, Text.equal, Text.hash);
    private let tokenApprovals : HashMap.HashMap<T.TokenId, Principal> = HashMap.fromIter<T.TokenId, Principal>(tokenApprovalsEntries.vals(), 10, Nat.equal, Hash.hash);
    private let operatorApprovals : HashMap.HashMap<Principal, [Principal]> = HashMap.fromIter<Principal, [Principal]>(operatorApprovalsEntries.vals(), 10, Principal.equal, Principal.hash);
    private let activeAuctions : HashMap.HashMap<T.TokenId, Nat> = HashMap.fromIter<T.TokenId, Nat>(activeAuctionEntries.vals(), 10, Nat.equal, Hash.hash);
    private let auctionApplications : HashMap.HashMap<Text, Nat> = HashMap.fromIter<Text, Nat>(auctionApplicationEntries.vals(), 10, Text.equal, Text.hash);
    private let nftPrices: HashMap.HashMap<T.TokenId, Nat> = HashMap.fromIter<T.TokenId, Nat>(nftPriceEntries.vals(), 10, Nat.equal, Hash.hash);
    private let nftUpvotes: HashMap.HashMap<T.TokenId, Nat> = HashMap.fromIter<T.TokenId, Nat>(nftUpvoteEntries.vals(), 10, Nat.equal, Hash.hash);
    private let nftDownvotes: HashMap.HashMap<T.TokenId, Nat> = HashMap.fromIter<T.TokenId, Nat>(nftDownvoteEntries.vals(), 10, Nat.equal, Hash.hash);
    private let upvoteRecords : HashMap.HashMap<T.TokenId, [Principal]> = HashMap.fromIter<T.TokenId, [Principal]>(upvoteRecordEntries.vals(), 10, Nat.equal, Hash.hash);
    private let downvoteRecords : HashMap.HashMap<T.TokenId, [Principal]> = HashMap.fromIter<T.TokenId, [Principal]>(downvoteRecordEntries.vals(), 10, Nat.equal, Hash.hash);
    private let equipped: HashMap.HashMap<T.TokenId, T.TokenId> = HashMap.fromIter<T.TokenId, T.TokenId>(equippedEntries.vals(), 10, Nat.equal, Hash.hash);
    private let occupied: HashMap.HashMap<T.TokenId, Bool> = HashMap.fromIter<T.TokenId, Bool>(occupiedEntries.vals(), 10, Nat.equal,Hash.hash);

    type Order = {#less; #equal; #greater};

    func textToNat(t : Text) : ?Nat{
        let s = t.size();
        if (s == 0){
            return null;
        };
        var num : Nat = 0;
        var i = 0;
        for (c in t.chars()){
            if (c != '0' and c != '1' and c != '2' and c != '3' and c != '4' and c != '5' and c != '6' and c != '7' and c != '8' and c != '9'){
                return null;                
            }
            else {
                var dig : Nat = 0;
                switch (c) {
                    case '0' {
                        dig := 0;
                    };
                    case '1' {
                        dig := 1;
                    };
                    case '2' {
                        dig := 2;
                    };
                    case '3' {
                        dig := 3;
                    };
                    case '4' {
                        dig := 4;
                    };
                    case '5' {
                        dig := 5;
                    };
                    case '6' {
                        dig := 6;
                    };
                    case '7' {
                        dig := 7;
                    };
                    case '8' {
                        dig := 8;
                    };
                    case default {
                        dig := 9;
                    };
                };
                num := num + dig * (10**(s - i - 1));
            };
            i += 1;
        };
        return (?num);
    };
    
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

    public shared query func tags() : async [Text] {
        return _tags;
    };

    public shared func isApprovedForAll(owner : Principal, opperator : Principal) : async Bool {
        return _isApprovedForAll(owner, opperator);
    };

    public shared query func showNFTs() : async [(Nat,Text)]{
        return Iter.toArray(tokenURIs.entries());
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

    public func getURI(tid: T.TokenId): async Text{
        let uriOpt = tokenURIs.get(tid);
        switch uriOpt{
            case null{
                return "";
            };
            case (?text){
                return text;
            };
        };
        return "";
    };

    public func showAllPropertyFrequency(): async [(Text, Nat)]{
        return Iter.toArray(propertyFrequencies.entries());
    };

    func infinityVal(tid: T.TokenId): Nat{
        let props = properties.get(tid);
        var total = 1;
        switch props{
            case null{
                return 0;
            };
            case (?arr){
                var i = 0;
                while (i < arr.size()){
                    let propFreq = propertyFrequencies.get(arr[i].1 # " " # Nat.toText(i));
                    switch propFreq{
                        case null{
                            return 0;
                        };
                        case (?nat){
                            total *= nat;
                        };
                    };
                    i += 1;
                };
            };
        };
        return (total);
    };

    func ivEqual(a: (Nat,Nat), b: (Nat,Nat)): Order{
        if (a.1 >  b.1){
            return #greater;
        };
        if (a.1 < b.1){
            return #less;
        }
        else {
            return #equal;
        }
    };

    public func infinityRank(): async [(T.TokenId, Nat)]{
        var i = 1;
        var ivArray : [(T.TokenId, Nat)]= [];
        while (i <= tokenPk){
            ivArray := Array.append<(Nat,Nat)>(ivArray,Array.make((i,infinityVal(i))));
            i += 1;
        };
        let ivSortedArray =  Array.sort<(Nat,Nat)>(ivArray,ivEqual);
        var ifArray: [(T.TokenId, Nat)] = [];
        ifArray := Array.append<(Nat,Nat)>(ifArray,Array.make((ivSortedArray[0].0,1)));
        i := 1;
        while (i < tokenPk){
            if (ivSortedArray[i].1 == ivSortedArray[i - 1].1){
                ifArray := Array.append<(Nat,Nat)>(ifArray, Array.make((ivSortedArray[i].0, ifArray[i-1].1)));
            }
            else{
                ifArray := Array.append<(Nat,Nat)>(ifArray, Array.make((ivSortedArray[i].0, ifArray[i-1].1 + 1)));
            };
            i += 1;
        };
        return ifArray;
    };

    //List an NFT under your ownership for sale. The NFT must not be under auction at this time.
    public shared(msg) func listForSale(tid: T.TokenId, price: Nat): async Bool{
        let isAuctioned = activeAuctions.get(tid);
        switch isAuctioned{
            case (?nat){
                return false;
            };
            case null{};
        };
        let ownerOfNFT = owners.get(tid);
        switch ownerOfNFT{
            case null{
                return false;
            };
            case (?principal){
                if (principal != msg.caller){
                    return false;
                }
                else {
                    let newPriceEntry = nftPrices.replace(tid,price);
                };
            };
        };
        return true;

    };

    /*  List an NFT under your ownership for sale via Intercanister call from Landing. 
        The NFT must not be under auction at this time.
    */
    public shared({caller}) func listForSale2(address: Principal, tid: T.TokenId, price: Nat): async Bool{
        if (caller != Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")){
            return false;
        };
        let isAuctioned = activeAuctions.get(tid);
        switch isAuctioned{
            case (?nat){
                return false;
            };
            case null{};
        };
        let ownerOfNFT = owners.get(tid);
        switch ownerOfNFT{
            case null{
                return false;
            };
            case (?principal){
                if (principal != address){
                    return false;
                }
                else {
                    let newPriceEntry = nftPrices.replace(tid,price);
                };
            };
        };
        return true;

    };

    //to get the price based on token id
    public query func showPrice(tid : T.TokenId): async ?Nat{
        return nftPrices.get(tid);
        
    };

    //to upvote an NFT and increase its visibility via meriticratic constraints
    public shared({caller}) func upvoteNFT(tid: T.TokenId): async Bool{
        assert _exists(tid);
        let currentlyDownvoted = downvoteRecords.get(tid);
        switch currentlyDownvoted{
            case (?array){
                for (downvoter in array.vals()){
                    if (downvoter == caller){
                        return false;
                    };
                };
            };
            case null {};
        };
        let currentlyUpvoted = upvoteRecords.get(tid);
        switch currentlyUpvoted{
            case (?array){
                for (upvoter in array.vals()){
                    if (upvoter == caller){
                        return false;
                    };
                };
                let newArr : [Principal] = Array.append<Principal>(array,Array.make(caller));
                let replacedArr = upvoteRecords.replace(tid,newArr);
            };
            case null{
                upvoteRecords.put(tid,Array.make(caller));
            };
        };
        let currentUpvotes = nftUpvotes.get(tid);
        switch currentUpvotes{
            case null{
                let res = nftUpvotes.put(tid,1);
            };
            case (?nat){
                let res = nftUpvotes.replace(tid,nat+1);
            };
        };
        return true;
    };

    //to upvote an NFT and increase its visibility via meriticratic constraints vua intercanister calls from landing
    public shared({caller}) func upvoteNFT2(address: Principal, tid: T.TokenId): async Bool{
        Debug.print(debug_show caller);
        if (caller != Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")){
            return false;
        };
        assert _exists(tid);
        let currentlyDownvoted = downvoteRecords.get(tid);
        switch currentlyDownvoted{
            case (?array){
                for (downvoter in array.vals()){
                    if (downvoter == address){
                        return false;
                    };
                };
            };
            case null {};
        };
        let currentlyUpvoted = upvoteRecords.get(tid);
        switch currentlyUpvoted{
            case (?array){
                for (upvoter in array.vals()){
                    if (upvoter == address){
                        return false;
                    };
                };
                let newArr : [Principal] = Array.append<Principal>(array,Array.make(address));
                let replacedArr = upvoteRecords.replace(tid,newArr);
            };
            case null{
                upvoteRecords.put(tid,Array.make(address));
            };
        };
        let currentUpvotes = nftUpvotes.get(tid);
        switch currentUpvotes{
            case null{
                let res = nftUpvotes.put(tid,1);
            };
            case (?nat){
                let res = nftUpvotes.replace(tid,nat+1);
            };
        };
        return true;
    };

    //to decrease the visibility of an NFT via meritocratic constraints
    public shared({caller}) func downvoteNFT(tid: T.TokenId): async Bool{
        assert _exists(tid);
        let currentlyUpvoted = upvoteRecords.get(tid);
        switch currentlyUpvoted{
            case (?array){
                for (upvoter in array.vals()){
                    if (upvoter == caller){
                        return false;
                    };
                };
            };
            case null {};
        };
        let currentlyDownvoted = downvoteRecords.get(tid);
        switch currentlyDownvoted{
            case (?array){
                for (downvoter in array.vals()){
                    if (downvoter == caller){
                        return false;
                    };
                };
                let newArr : [Principal] = Array.append<Principal>(array,Array.make(caller));
                let replacedArr = downvoteRecords.replace(tid,newArr);
            };
            case null{
                downvoteRecords.put(tid,Array.make(caller));
            };
        };
        let currentDownvotes = nftDownvotes.get(tid);
        switch currentDownvotes{
            case null{
                let res = nftDownvotes.put(tid,1);
            };
            case (?nat){
                let res = nftDownvotes.replace(tid,nat+1);
            };
        };
        return true;
    };

    //to decrease the visibility of an NFT via meritocratic constraints
    public shared({caller}) func downvoteNFT2(address: Principal, tid: T.TokenId): async Bool{
        if (caller != Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")){
            return false;
        };
        assert _exists(tid);
        let currentlyUpvoted = upvoteRecords.get(tid);
        switch currentlyUpvoted{
            case (?array){
                for (upvoter in array.vals()){
                    if (upvoter == address){
                        return false;
                    };
                };
            };
            case null {};
        };
        let currentlyDownvoted = downvoteRecords.get(tid);
        switch currentlyDownvoted{
            case (?array){
                for (downvoter in array.vals()){
                    if (downvoter == address){
                        return false;
                    };
                };
                let newArr : [Principal] = Array.append<Principal>(array,Array.make(address));
                let replacedArr = downvoteRecords.replace(tid,newArr);
            };
            case null{
                downvoteRecords.put(tid,Array.make(address));
            };
        };
        let currentDownvotes = nftDownvotes.get(tid);
        switch currentDownvotes{
            case null{
                let res = nftDownvotes.put(tid,1);
            };
            case (?nat){
                let res = nftDownvotes.replace(tid,nat+1);
            };
        };
        return true;
    };

    //directly transfer an NFT provided it is NOT undergoing an auction, and takes it off sale
    public shared(msg) func transferFrom(from : Principal, to : Principal, tokenId : Nat) : async Bool {
        let isAuctioned = activeAuctions.get(tokenId);
        switch isAuctioned{
            case (?nat){
                return false;
            };
            case null {};
        };
        assert _isApprovedOrOwner(msg.caller, tokenId);
        
        _transfer(from, to, tokenId);
        nftPrices.delete(tokenId);
        return true;
    };

    //Purchase a listed NFT
    public shared(msg) func buyNFT(tokenId: T.TokenId) : async Bool{
        let priceOpt = nftPrices.get(tokenId);
        var price = 0;
        switch priceOpt{
            case null{
                return false;
            };
            case (?nat){
                price := nat;
            };
        };
        
        let ownerOpt = owners.get(tokenId);
        var currentOwner: Principal = Principal.fromText("2vxsx-fae");
        switch ownerOpt{
            case null{
                return false;
            };
            case (?principal){
                currentOwner := principal;
            };
        };
        let act = actor("r7inp-6aaaa-aaaaa-aaabq-cai"):actor {getMinBal: (Principal) -> async Nat};
        let minbal = await act.getMinBal(msg.caller);
        let act2 = actor("r7inp-6aaaa-aaaaa-aaabq-cai"):actor {balanceOf: (Principal) -> async Nat};
        let bal = await act2.balanceOf(msg.caller);

        if (bal < minbal + price){
            return false;
        };
        
        
        Debug.print(debug_show currentOwner);
        Debug.print(debug_show price);

        let act3 = actor("r7inp-6aaaa-aaaaa-aaabq-cai"):actor {transferForNFT: (Principal, Principal, Nat) -> async TxReceipt};
        let txn = await act3.transferForNFT(msg.caller,currentOwner,price);
        let newBal = await act2.balanceOf(msg.caller);
        if (newBal != bal){
            
        
            Debug.print(debug_show txn);
            let priceEntryRemoval = nftPrices.delete(tokenId);
            _transfer(currentOwner, msg.caller, tokenId);
            return true;
        }
        else {
            return false;
        };
    };

    //Purchase a listed NFT via an intercanister call from Landing
    public shared({caller}) func buyNFT2(address: Principal, tokenId: T.TokenId) : async Bool{
        if (caller != Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")){
            return false;
        };
        let priceOpt = nftPrices.get(tokenId);
        var price = 0;
        switch priceOpt{
            case null{
                return false;
            };
            case (?nat){
                price := nat;
            };
        };
        
        let ownerOpt = owners.get(tokenId);
        var currentOwner: Principal = Principal.fromText("2vxsx-fae");
        switch ownerOpt{
            case null{
                return false;
            };
            case (?principal){
                currentOwner := principal;
            };
        };
        let act = actor("r7inp-6aaaa-aaaaa-aaabq-cai"):actor {getMinBal: (Principal) -> async Nat};
        let minbal = await act.getMinBal(address);
        let act2 = actor("r7inp-6aaaa-aaaaa-aaabq-cai"):actor {balanceOf: (Principal) -> async Nat};
        let bal = await act2.balanceOf(address);

        if (bal < minbal + price){
            return false;
        };
        
        
        Debug.print(debug_show currentOwner);
        Debug.print(debug_show price);

        let act3 = actor("r7inp-6aaaa-aaaaa-aaabq-cai"):actor {transferForNFT: (Principal, Principal, Nat) -> async TxReceipt};
        let txn = await act3.transferForNFT(address,currentOwner,price);
        let newBal = await act2.balanceOf(address);
        if (newBal != bal){
            
        
            Debug.print(debug_show txn);
            let priceEntryRemoval = nftPrices.delete(tokenId);
            _transfer(currentOwner, address, tokenId);
            return true;
        }
        else {
            return false;
        };
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

    //Mint requires authentication in the frontend, but metadata is self created at runtime.
    public shared ({caller}) func mintFromParameters(uri: Text, md: [(Text,Text)]) : async Nat{
        
        let meta: TokenMetadata = toTokenMetadata(tokenPk + 1, caller,md);
        _mint(caller, tokenPk + 1, uri, meta);
        tokenPk += 1;
        properties.put(tokenPk,md);
        var i = 0;
        while (i < md.size()){
            let pval = propertyFrequencies.get(md[i].1 # " " # Nat.toText(i));
            switch pval{
                case null{
                    propertyFrequencies.put((md[i].1 # " " # Nat.toText(i)),1);
                };
                case (?nat){
                    let res = propertyFrequencies.replace((md[i].1 # " " # Nat.toText(i)),nat + 1);
                };
            };
            i += 1;
        };
        return tokenPk;
    };

    //Mint requires authentication in the frontend, but metadata is self created at runtime.
    public shared ({caller}) func mintFromParameters2(to: Principal, uri: Text, md: [(Text,Text)]) : async Nat{
        Debug.print(debug_show caller);
        assert(caller == Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai"));
        
        
        let meta: TokenMetadata = toTokenMetadata(tokenPk + 1, to, md);
        _mint(to, tokenPk + 1, uri, meta);
        tokenPk += 1;
        properties.put(tokenPk,md);
        var i = 0;
        while (i < md.size()){
            let pval = propertyFrequencies.get(md[i].1 # " " # Nat.toText(i));
            switch pval{
                case null{
                    propertyFrequencies.put((md[i].1 # " " # Nat.toText(i)),1);
                };
                case (?nat){
                    let res = propertyFrequencies.replace((md[i].1 # " " # Nat.toText(i)),nat + 1);
                };
            };
            i += 1;
        };
        return tokenPk;
    };

    public func md(): async [(Text,Text)]{
        return Array.append(Array.make(("hello","world")), Array.make(("hey","there")));
    };

    /*  
        To hold an auction for owned NFT. It needs to be NOT listed for sale so owenership does
        not change during the auction.
    */
    public shared ({caller}) func auctionStart(t : T.TokenId, minSale : Nat) : async Bool {
        let tokenOwner = owners.get(t);
        let alreadyListed = nftPrices.get(t);
        switch alreadyListed{
            case (?nat){
                return false;
            };
            case null{};
        };
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

    /*  
        To hold an auction for owned NFT using an intercanister call from Landing. 
        It needs to be NOT listed for sale so owenership does not change during the auction.
    */
    public shared ({caller}) func auctionStart2(address: Principal, t : T.TokenId, minSale : Nat) : async Bool {
        if (caller != Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")){
            return false;
        };
        let tokenOwner = owners.get(t);
        let alreadyListed = nftPrices.get(t);
        switch alreadyListed{
            case (?nat){
                return false;
            };
            case null{};
        };
        switch (tokenOwner) {
            case null {
                return false;
            };
            case (?principal) {
                if (principal != address){
                    return false;
                } 
                else {
                    activeAuctions.put(t,minSale);
                    return true;
                };
            };
        };
    };

    //To participate in an auction for an NFT
    public shared({caller}) func auctionBid(t: T.TokenId, bid: Nat) : async Bool {
        let tokenOwner = owners.get(t);
        switch (tokenOwner) {
            case null {
                return false;
            };
            case default {
                var i = 0;
            };
        };
        let minBid = activeAuctions.get(t);
        switch (minBid) {
            case null {
                return false;
            };
            case (?nat) {
                if (nat > bid) {
                    return false;
                }
                else {
                    let bid_identifier : Text = Nat.toText(t) # "<<<>>>" # Principal.toText(caller);
                    auctionApplications.put(bid_identifier,bid);
                    return true;
                }; 
            };
        };
    };

    //To participate in an auction for an NFT using intercanister calls from Landing
    public shared({caller}) func auctionBid2(address: Principal, t: T.TokenId, bid: Nat) : async Bool {
        if (caller != Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")){
            return false;
        };
        let tokenOwner = owners.get(t);
        switch (tokenOwner) {
            case null {
                return false;
            };
            case default {
                var i = 0;
            };
        };
        let minBid = activeAuctions.get(t);
        switch (minBid) {
            case null {
                return false;
            };
            case (?nat) {
                if (nat > bid) {
                    return false;
                }
                else {
                    let bid_identifier : Text = Nat.toText(t) # "<<<>>>" # Principal.toText(address);
                    auctionApplications.put(bid_identifier,bid);
                    return true;
                }; 
            };
        };
    };

    //To end an auction for owned NFT
    public shared({caller}) func auctionEnd(t : T.TokenId) : async Bool {
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
                    var winningBidder : Principal = Principal.fromText("2vxsx-fae");
                    var winningBid : Nat = 0;
                    for ((key,item) in auctionApplications.entries()){
                        let iter = Text.split(key,#text("<<<>>>"));
                        let iterArray = Iter.toArray<Text>(iter);
                        let tID  = textToNat(iterArray[0]);
                        var tid : Nat = 0;
                        switch (tID){
                            case null {
                                tid := 0;
                            };
                            case (?nat) {
                                tid := nat;
                            };
                        };
                        if (tid == t){
                            let bidder : Principal = Principal.fromText(iterArray[1]);
                            let bid = item;
                            let act = actor("r7inp-6aaaa-aaaaa-aaabq-cai"):actor {getMinBal: (Principal) -> async Nat};
                            let minbal = await act.getMinBal(bidder);
                            let act2 = actor("r7inp-6aaaa-aaaaa-aaabq-cai"):actor {balanceOf: (Principal) -> async Nat};
                            let bal = await act2.balanceOf(bidder);
                            if (bid > winningBid and bal > minbal + bid){
                                winningBid := bid;
                                winningBidder := bidder;
                            };
                        };
                        auctionApplications.delete(key);
                    };
                    activeAuctions.delete(t);
                    if (winningBid != 0){
                        let act3 = actor("r7inp-6aaaa-aaaaa-aaabq-cai"):actor {transferForNFT: (Principal, Principal, Nat) -> async TxReceipt};
                        let txn = await act3.transferForNFT(winningBidder,caller,winningBid);
                        _transfer(caller, winningBidder, t);
                        return true;
                    }
                    else {
                        return false;
                    };
                };
            };
        };
    };

    //To end an auction for owned NFT using intercanister calls from Landing
    public shared({caller}) func auctionEnd2(address: Principal, t : T.TokenId) : async Bool {
        if (caller != Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")){
            return false;
        };
        let tokenOwner = owners.get(t);
        switch (tokenOwner) {
            case null {
                return false;
            };
            case (?principal) {
                if (principal != address){
                    return false;
                } 
                else {
                    var winningBidder : Principal = Principal.fromText("2vxsx-fae");
                    var winningBid : Nat = 0;
                    for ((key,item) in auctionApplications.entries()){
                        let iter = Text.split(key,#text("<<<>>>"));
                        let iterArray = Iter.toArray<Text>(iter);
                        let tID  = textToNat(iterArray[0]);
                        var tid : Nat = 0;
                        switch (tID){
                            case null {
                                tid := 0;
                            };
                            case (?nat) {
                                tid := nat;
                            };
                        };
                        if (tid == t){
                            let bidder : Principal = Principal.fromText(iterArray[1]);
                            let bid = item;
                            let act = actor("r7inp-6aaaa-aaaaa-aaabq-cai"):actor {getMinBal: (Principal) -> async Nat};
                            let minbal = await act.getMinBal(bidder);
                            let act2 = actor("r7inp-6aaaa-aaaaa-aaabq-cai"):actor {balanceOf: (Principal) -> async Nat};
                            let bal = await act2.balanceOf(bidder);
                            if (bid > winningBid and bal > minbal + bid){
                                winningBid := bid;
                                winningBidder := bidder;
                            };
                        };
                        auctionApplications.delete(key);
                    };
                    activeAuctions.delete(t);
                    if (winningBid != 0){
                        let act3 = actor("r7inp-6aaaa-aaaaa-aaabq-cai"):actor {transferForNFT: (Principal, Principal, Nat) -> async TxReceipt};
                        let txn = await act3.transferForNFT(winningBidder,address,winningBid);
                        _transfer(address, winningBidder, t);
                        return true;
                    }
                    else {
                        return false;
                    };
                };
            };
        };
    };

    //Edit a dynamic NFT
    public shared ({caller}) func updateDNFT(tokenId: T.TokenId, uri: Text, meta: TokenMetadata): async Bool{
        let owner = owners.get(tokenId);
        switch (owner){
            case null {
                return false;
            };
            case (?principal){
                if (principal != caller){
                    return false;
                }
                else {
                    let newUri = tokenURIs.replace(tokenId, uri);
                    let newMeta = tokenMetadataHash.replace(uri,meta);
                    return true;
                };
            
            };
        };
    };

    public shared ({caller}) func updateDNFT2(p: Principal, tokenId: T.TokenId, uri: Text, md: [(Text,Text)]): async Bool{
        if (caller != Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")){
            return false;
        };
        let newUri = tokenURIs.replace(tokenId, uri);
        let meta = toTokenMetadata(tokenId, p, md);
        let newMeta = tokenMetadataHash.replace(uri,meta);
        return true;
        
    };

    public shared ({caller}) func equip(tid: T.TokenId, tid2: T.TokenId): async T.TokenId{
        if (caller != Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")){
            return 0;
        };
        let equipStat = equipped.get(tid);
        switch equipStat{
            case null{
                equipped.put(tid, tid2);
                Debug.print(debug_show tid2);
                return tid2;
            };
            case (?nat){
                Debug.print(debug_show nat);
                return 0;
            };
        };
        Debug.print("HOW");
        return 0;
    };

    public shared ({caller}) func dequip(tid: T.TokenId, tid2: T.TokenId): async T.TokenId{
        if (caller != Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")){
            return 0;
        };
        let equipStat = equipped.get(tid);
        switch equipStat{
            case null{
                Debug.print("null");
                return 0;
            };
            case (?nat){
                if (nat != tid2){
                    Debug.print(debug_show nat);
                    return 0;
                }
                else{
                    let res = equipped.remove(tid);
                    Debug.print(debug_show res);
                    return tid2;
                };
                
            };
        };
        return 0;
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
        let owner_ = _ownerOf(tokenId);
        var owner : Principal = Principal.fromText("2vxsx-fae");
        switch (owner_){
            case null {
                owner := Principal.fromText("2vxsx-fae");
                
            };
            case (?principal){
                owner := principal;
            };
            
        };
        
        return spender == owner or _hasApprovedAndSame(tokenId, spender) or _isApprovedForAll(owner, spender);
    };

    private func _transfer(from : Principal, to : Principal, tokenId : Nat) : () {
        assert _exists(tokenId);
        var owner = Principal.fromText("2vxsx-fae");
        switch (_ownerOf(tokenId)){
            case null {
                owner := Principal.fromText("2vxsx-fae");
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
        var owner = Principal.fromText("2vxsx-fae");
        switch (_ownerOf(tokenId)){
            case null {
                owner := Principal.fromText("2vxsx-fae");
            };
            case (?principal){
                owner := principal;
            };
        };
        assert Principal.toText(owner) != "2vxsx-fae";

        _removeApprove(tokenId);
        _decrementBalance(owner);

        ignore owners.remove(tokenId);
    };

    public func x() : async Int{
        let act = actor("r7inp-6aaaa-aaaaa-aaabq-cai"):actor {show_time: () -> async Int};
        return await act.show_time();
    };

    public func setOccupyTrue(tid: T.TokenId): async Bool{
        let occOpt = occupied.get(tid);
        switch occOpt{
            case null{
                occupied.put(tid, true);
            };
            case (?bool){
                if (bool){
                    return false;
                };
                let res = occupied.replace(tid, not bool);
            };
        };
        return true;
    };

    public func setOccupyFalse(tid: T.TokenId): async Bool{
        let occOpt = occupied.get(tid);
        switch occOpt{
            case null{
                occupied.put(tid, false);
            };
            case (?bool){
                if (not bool){
                    return false;
                };
                let res = occupied.replace(tid, not bool);
            };
        };
        return true;
    };

    public func isOccupyTrue(tid: T.TokenId): async Bool{
        let occOpt = occupied.get(tid);
        switch occOpt{
            case null{
                return false;
            };
            case (?bool){
                return bool;
            };
        };
        return false;
    };

    system func preupgrade() {
        tokenURIEntries := Iter.toArray(tokenURIs.entries());
        tokenMetadataEntries := Iter.toArray(tokenMetadataHash.entries());
        ownersEntries := Iter.toArray(owners.entries());
        balancesEntries := Iter.toArray(balances.entries());
        propertiesEntries := Iter.toArray(properties.entries());
        propertyFrequencyEntries := Iter.toArray(propertyFrequencies.entries());
        tokenApprovalsEntries := Iter.toArray(tokenApprovals.entries());
        operatorApprovalsEntries := Iter.toArray(operatorApprovals.entries());
        activeAuctionEntries := Iter.toArray(activeAuctions.entries());
        auctionApplicationEntries := Iter.toArray(auctionApplications.entries());
        nftPriceEntries := Iter.toArray(nftPrices.entries());
        nftDownvoteEntries := Iter.toArray(nftDownvotes.entries());
        nftUpvoteEntries := Iter.toArray(nftUpvotes.entries());
        upvoteRecordEntries := Iter.toArray(upvoteRecords.entries());
        downvoteRecordEntries := Iter.toArray(downvoteRecords.entries());
        equippedEntries := Iter.toArray(equipped.entries());
        occupiedEntries := Iter.toArray(occupied.entries());
    };

    system func postupgrade() {
        tokenURIEntries := [];
        tokenMetadataEntries := [];
        ownersEntries := [];
        balancesEntries := [];
        propertiesEntries := [];
        propertyFrequencyEntries := [];
        tokenApprovalsEntries := [];
        operatorApprovalsEntries := [];
        auctionApplicationEntries := [];
        activeAuctionEntries := [];
        nftPriceEntries := [];
        nftDownvoteEntries := [];
        nftUpvoteEntries := [];
        upvoteRecordEntries := [];
        downvoteRecordEntries := [];
        equippedEntries := [];
        occupiedEntries := [];
    };
};
