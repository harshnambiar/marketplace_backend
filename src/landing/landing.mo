import Text "mo:base/Text";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Minter "../minter/main"

actor class Landing(
    _owner: Principal
    ) = this{
    private stable var collectionEntries : [(Text, Principal)] = [];
    private stable var collectionCanisterEntries : [(Text, Text)] = [];
    private let collections : HashMap.HashMap<Text, Principal> = HashMap.fromIter<Text, Principal>(collectionEntries.vals(), 10, Text.equal, Text.hash);
    private let collectionCanisters : HashMap.HashMap<Text, Text> = HashMap.fromIter<Text, Text>(collectionCanisterEntries.vals(), 10, Text.equal, Text.hash);

    public shared({caller}) func requestApproval(collName: Text): async Bool{
        let creator = collections.get(collName);
        switch creator{
            case null{
                let res = collections.put(collName, caller);
                let status = collectionCanisters.get(collName);
                switch status{
                    case null{
                        let res2 = collectionCanisters.put(collName, "pending");
                        return true;
                    };
                    case (?text){
                        return false;
                    };
                };
            };
            case (?principal){
                return false;
            };
        };
        return false;
    };

    public shared({caller}) func approveCollection(collName: Text): async Bool{
        if (caller != _owner){
            return false;
        };
        let creator = collections.get(collName);
        switch creator{
            case null{
                return false;
            };
            case (?principal){
                let status = collectionCanisters.get(collName);
                switch status{
                    case null{
                        let res = collectionCanisters.put(collName,"approved");
                        return true;
                    };
                    case (?text){
                        if (text == "pending"){
                            let res = collectionCanisters.replace(collName, "approved");
                            return true;
                        }
                        else {
                            return false;
                        };
                    };
                };
            };
        };
        return false;

    };

    public func listCollections(): async [(Text, Principal)]{
        return Iter.toArray(collections.entries());
    };

    public func listCollectionStatuses(): async [(Text, Text)]{
        return Iter.toArray(collectionCanisters.entries());
    };

    public func showCollectionNFTs(collName: Text): async [(Nat,Text)]{
        let status = collectionCanisters.get(collName);
        var canisterId = "";
        switch status{
            case null{
                return [];
            };
            case (?text){
                if (text == "pending" or text == "approved"){
                    return [];
                }
                else {
                    canisterId := text;
                };
            };
        };
        let act = actor(canisterId):actor {showNFTs: () -> async ([(Nat,Text)])};
        let allNFT = await act.showNFTs();
        return allNFT;
    };

    public type DRC721 = Minter.DRC721;
    public shared({caller}) func launchCollection(collName: Text, symbol: Text, tags: [Text]): async (?DRC721){
        let creator = collections.get(collName);
        var creatorId = Principal.fromText("2vxsx-fae");
        switch creator{
            case null{
                return null;
            };
            case (?principal){
                creatorId := principal;
                if (creatorId != caller){
                    return null;
                };
            };
        };
        let status = collectionCanisters.get(collName);
        switch status{
            case null{
                return null;
            };
            case (?text){
                if (text != "approved"){
                    return null;
                };
            };
        };
        let t = await Minter.DRC721(collName, symbol, tags);
        let res = collectionCanisters.replace(collName, Principal.toText(Principal.fromActor(t)));
        return (?t);
    };

    public shared({caller}) func mint(collName: Text, uri: Text) : async Bool{
        let status = collectionCanisters.get(collName);
        var canisterId = "";
        switch status{
            case null{
                return false;
            };
            case (?text){
                if (text == "pending" or text == "approved"){
                    return false;
                }
                else {
                    canisterId := text;
                };
            };
        };
        let act = actor(canisterId):actor {mintFromParameters2: (Principal, Text) -> async (Nat)};
        let mintedNFT = await act.mintFromParameters2(caller,uri);
        return true;
    };

    public shared({caller}) func upvoteNFT(collName: Text, tid: Nat) : async Bool{
        let status = collectionCanisters.get(collName);
        var canisterId = "";
        switch status{
            case null{
                return false;
            };
            case (?text){
                if (text == "pending" or text == "approved"){
                    return false;
                }
                else {
                    canisterId := text;
                };
            };
        };
        let act = actor(canisterId):actor {upvoteNFT2: (Principal, Nat) -> async (Bool)};
        let res = await act.upvoteNFT2(caller,tid);
        return res;
    }; 

    public shared({caller}) func downvoteNFT(collName: Text, tid: Nat) : async Bool{
        let status = collectionCanisters.get(collName);
        var canisterId = "";
        switch status{
            case null{
                return false;
            };
            case (?text){
                if (text == "pending" or text == "approved"){
                    return false;
                }
                else {
                    canisterId := text;
                };
            };
        };
        let act = actor(canisterId):actor {downvoteNFT2: (Principal, Nat) -> async (Bool)};
        let res = await act.downvoteNFT2(caller,tid);
        return res;
    }; 
    

    system func preupgrade() {
        collectionEntries := Iter.toArray(collections.entries());
        collectionCanisterEntries := Iter.toArray(collectionCanisters.entries());
    };

    system func postupgrade() {
        collectionEntries := [];
        collectionCanisterEntries := [];
    };

};