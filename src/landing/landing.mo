import Text "mo:base/Text";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Minter "../minter/main";
import Array "mo:base/Array";
import Debug "mo:base/Debug";

actor class Landing(
    _owner: Principal
    ) = this{
    private stable var collectionEntries : [(Text, Principal)] = [];
    private stable var collectionCanisterEntries : [(Text, Text)] = [];
    private stable var collectionPopularityEntries : [(Text, Int)] = [];
    private stable var upvoteCollectionEntries : [(Text, [Principal])] = [];
    private stable var downvoteCollectionEntries : [(Text, [Principal])] = [];
    private stable var collectionVolumeEntries : [(Text, Nat)] = [];
    private stable var collectionAllowableEntries : [(Text,[Text])] = [];
    private let collections : HashMap.HashMap<Text, Principal> = HashMap.fromIter<Text, Principal>(collectionEntries.vals(), 10, Text.equal, Text.hash);
    private let collectionCanisters : HashMap.HashMap<Text, Text> = HashMap.fromIter<Text, Text>(collectionCanisterEntries.vals(), 10, Text.equal, Text.hash);
    private let collectionPopularity : HashMap.HashMap<Text, Int> = HashMap.fromIter<Text, Int>(collectionPopularityEntries.vals(), 10, Text.equal, Text.hash);
    private let upvoteRecords : HashMap.HashMap<Text, [Principal]> = HashMap.fromIter<Text, [Principal]>(upvoteCollectionEntries.vals(), 10, Text.equal, Text.hash);
    private let downvoteRecords : HashMap.HashMap<Text, [Principal]> = HashMap.fromIter<Text, [Principal]>(downvoteCollectionEntries.vals(), 10, Text.equal, Text.hash);
    private let collectionVolume : HashMap.HashMap<Text, Nat> = HashMap.fromIter<Text, Nat>(collectionVolumeEntries.vals(), 10, Text.equal, Text.hash);
    private let collectionAllowables : HashMap.HashMap<Text, [Text]> = HashMap.fromIter<Text, [Text]>(collectionAllowableEntries.vals(), 10, Text.equal, Text.hash);

    type Order = {#less; #equal; #greater};

    func arSort(a: (Text,Int), b: (Text,Int)): Order{
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

    func arSort2(a: (Text,Nat), b: (Text,Nat)): Order{
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


    public func showPopular(): async [(Text, Int)]{
        var popArr : [(Text, Int)] = Iter.toArray(collectionPopularity.entries());
        var sortArr = Array.sort<(Text, Int)>(popArr, arSort);
        var i = 0;
        var k = 0;
        var retArr : [(Text, Int)] = [];
        while (i < sortArr.size() and k < 5){
            retArr := Array.append(retArr, Array.make(sortArr[sortArr.size() - i - 1]));
            i += 1;
            k += 1;
        };
        return retArr;

    };

    public func showHot(): async [(Text, Nat)]{
        var popArr : [(Text, Nat)] = Iter.toArray(collectionVolume.entries());
        var sortArr = Array.sort<(Text, Nat)>(popArr, arSort2);
        var i = 0;
        var k = 0;
        var retArr : [(Text, Nat)] = [];
        while (i < sortArr.size() and k < 5){
            retArr := Array.append(retArr, Array.make(sortArr[sortArr.size() - i - 1]));
            i += 1;
            k += 1;
        };
        return retArr;

    };
    
    public shared({caller}) func requestApproval(collName: Text, allowed: [Text]): async Bool{
        let creator = collections.get(collName);
        switch creator{
            case null{
                let res = collections.put(collName, caller);
                let status = collectionCanisters.get(collName);
                switch status{
                    case null{
                        collectionCanisters.put(collName, "pending");
                        collectionAllowables.put(collName, allowed);
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

    public func listActiveCanisters(): async [Text]{
        return Iter.toArray(collectionCanisters.vals());
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
        let t = await Minter.DRC721(collName, symbol, tags, caller, _owner);
        let res = collectionCanisters.replace(collName, Principal.toText(Principal.fromActor(t)));
        return (?t);
    };

    public shared({caller}) func mint(collName: Text, uri: Text, md: [(Text,Text)]) : async Bool{
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
        let allowedImages = collectionAllowables.get(collName);
        switch allowedImages{
            case null{
                return false;
            };
            case (?arr){
                var newArr = Array.filter(arr, func(val: Text) : Bool {uri != val});
                if(newArr.size() == arr.size()){
                    Debug.print(debug_show newArr.size());
                    return false;
                }
                else{
                    let rs = collectionAllowables.replace(collName, newArr);
                };

            };
        };
        let act = actor(canisterId):actor {mintFromParameters2: (Principal, Text, [(Text,Text)]) -> async (Nat)};
        let mintedNFT = await act.mintFromParameters2(caller,uri, md);
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

    public shared({caller}) func listNFT(collName: Text, tid: Nat, price: Nat) : async Bool{
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
        let act = actor(canisterId):actor {listForSale2: (Principal, Nat, Nat) -> async (Bool)};
        let res = await act.listForSale2(caller,tid, price);
        return res;
    }; 

    public shared({caller}) func buyNFT(collName: Text, tid: Nat) : async Bool{
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
        let act2 = actor(canisterId):actor {showPrice: (Nat) -> async (?Nat)};
        let res2 = await act2.showPrice(tid);
        let act = actor(canisterId):actor {buyNFT2: (Principal, Nat) -> async (Bool)};
        let res = await act.buyNFT2(caller,tid);
        var price = 0;
        switch res2{
            case null {};
            case (?nat){
                price := nat;
            };
        };
       
        if (res){
            let currentVol = collectionVolume.get(collName);
            switch currentVol{
                case null{
                    collectionVolume.put(collName, price);
                };
                case (?vol){
                    let res3 = collectionVolume.replace(collName, price + vol);
                };
            };
        };
        return res;
    }; 

    public shared({caller}) func auctionStart(collName: Text, tid: Nat, minSale: Nat) : async Bool{
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
        let act = actor(canisterId):actor {auctionStart2: (Principal, Nat, Nat) -> async (Bool)};
        let res = await act.auctionStart2(caller,tid, minSale);
        return res;
    }; 

    public shared({caller}) func auctionBid(collName: Text, tid: Nat, bid: Nat) : async Bool{
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
        let act = actor(canisterId):actor {auctionBid2: (Principal, Nat, Nat) -> async (Bool)};
        let res = await act.auctionBid2(caller,tid, bid);
        return res;
    }; 

    public shared({caller}) func auctionEnd(collName: Text, tid: Nat) : async Bool{
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
        let act1 = actor("r7inp-6aaaa-aaaaa-aaabq-cai"):actor {showBal: (Principal) -> async (Nat)};
        let res1 = await act1.showBal(caller);
        let act = actor(canisterId):actor {auctionEnd2: (Principal, Nat) -> async (Bool)};
        let res = await act.auctionEnd2(caller,tid);
        
        let res2 = await act1.showBal(caller);
        var price = res2 - res1;
        Debug.print(debug_show price);
         if (res){
            let currentVol = collectionVolume.get(collName);
            switch currentVol{
                case null{
                    collectionVolume.put(collName, price);
                };
                case (?vol){
                    let res3 = collectionVolume.replace(collName, price + vol);
                };
            };
        };
        return res;
    }; 
    
    public shared({caller}) func infinityRank(collName: Text) : async [(Nat, Nat)]{
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
        let act = actor(canisterId):actor {infinityRank: () -> async ([(Nat,Nat)])};
        let res = await act.infinityRank();
        return res;
    }; 

    public shared({caller}) func upvoteCollection(collName: Text): async Bool{
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
        
        let currentlyDownvoted = downvoteRecords.get(collName);
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
        let currentlyUpvoted = upvoteRecords.get(collName);
        switch currentlyUpvoted{
            case (?array){
                for (upvoter in array.vals()){
                    if (upvoter == caller){
                        return false;
                    };
                };
                let newArr : [Principal] = Array.append<Principal>(array,Array.make(caller));
                let replacedArr = upvoteRecords.replace(collName,newArr);
            };
            case null{
                upvoteRecords.put(collName,Array.make(caller));
            };
        };
        let currentUpvotes = collectionPopularity.get(collName);
        switch currentUpvotes{
            case null{
                let res = collectionPopularity.put(collName,1);
            };
            case (?int){
                let res = collectionPopularity.replace(collName,int+1);
            };
        };
        return true;
    };

    public shared({caller}) func downvoteCollection(collName: Text): async Bool{
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
        
        let currentlyUpvoted = upvoteRecords.get(collName);
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
        let currentlyDownvoted = downvoteRecords.get(collName);
        switch currentlyDownvoted{
            case (?array){
                for (downvoter in array.vals()){
                    if (downvoter == caller){
                        return false;
                    };
                };
                let newArr : [Principal] = Array.append<Principal>(array,Array.make(caller));
                let replacedArr = downvoteRecords.replace(collName,newArr);
            };
            case null{
                downvoteRecords.put(collName,Array.make(caller));
            };
        };
        let currentDownvotes = collectionPopularity.get(collName);
        switch currentDownvotes{
            case null{
                let res = collectionPopularity.put(collName,-1);
            };
            case (?int){
                let res = collectionPopularity.replace(collName,int-1);
            };
        };
        return true;
    };

    public func displayPopularity(collName: Text): async ?Int{
        return collectionPopularity.get(collName);
    };

    system func preupgrade() {
        collectionEntries := Iter.toArray(collections.entries());
        collectionCanisterEntries := Iter.toArray(collectionCanisters.entries());
        collectionPopularityEntries := Iter.toArray(collectionPopularity.entries());
        upvoteCollectionEntries := Iter.toArray(upvoteRecords.entries());
        downvoteCollectionEntries := Iter.toArray(downvoteRecords.entries());
        collectionVolumeEntries := Iter.toArray(collectionVolume.entries());
    };

    system func postupgrade() {
        collectionEntries := [];
        collectionCanisterEntries := [];
        collectionPopularityEntries := [];
        upvoteCollectionEntries := [];
        downvoteCollectionEntries := [];
        collectionVolumeEntries := [];
    };

};