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
    private stable var nestedCollectionEntries : [(Text, Text)] = [];
    private stable var allowedNestingEntries : [(Text, [(Text, [Text])])] = [];
    private stable var allowedNestedMetadataEntries : [(Text, [(Text, [[(Text, Text)]])])] = [];
    private let collections : HashMap.HashMap<Text, Principal> = HashMap.fromIter<Text, Principal>(collectionEntries.vals(), 10, Text.equal, Text.hash);
    private let collectionCanisters : HashMap.HashMap<Text, Text> = HashMap.fromIter<Text, Text>(collectionCanisterEntries.vals(), 10, Text.equal, Text.hash);
    private let collectionPopularity : HashMap.HashMap<Text, Int> = HashMap.fromIter<Text, Int>(collectionPopularityEntries.vals(), 10, Text.equal, Text.hash);
    private let upvoteRecords : HashMap.HashMap<Text, [Principal]> = HashMap.fromIter<Text, [Principal]>(upvoteCollectionEntries.vals(), 10, Text.equal, Text.hash);
    private let downvoteRecords : HashMap.HashMap<Text, [Principal]> = HashMap.fromIter<Text, [Principal]>(downvoteCollectionEntries.vals(), 10, Text.equal, Text.hash);
    private let collectionVolume : HashMap.HashMap<Text, Nat> = HashMap.fromIter<Text, Nat>(collectionVolumeEntries.vals(), 10, Text.equal, Text.hash);
    private let collectionAllowables : HashMap.HashMap<Text, [Text]> = HashMap.fromIter<Text, [Text]>(collectionAllowableEntries.vals(), 10, Text.equal, Text.hash);
    private let nestedCollections : HashMap.HashMap<Text, Text> = HashMap.fromIter<Text, Text>(nestedCollectionEntries.vals(), 10, Text.equal, Text.hash);
    private let allowedNesting : HashMap.HashMap<Text, [(Text, [Text])]> = HashMap.fromIter<Text, [(Text, [Text])]>(allowedNestingEntries.vals(), 10, Text.equal, Text.hash);
    private let allowedNestedMetadata : HashMap.HashMap<Text, [(Text, [[(Text,Text)]])]> = HashMap.fromIter<Text, [(Text, [[(Text, Text)]])]>(allowedNestedMetadataEntries.vals(), 10, Text.equal, Text.hash);

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

    public shared({caller}) func requestApprovalForNested(collName: Text, parentName: Text, allowed: [Text], combinations: [(Text,[Text])], metaCombinations: [(Text,[[(Text,Text)]])]): async Bool{
        let parent = collections.get(parentName);
        switch parent{
            case null{
                return false;
            };
            case (?principal){
                if (caller != principal){
                    return false;
                };
            };
        };
        let creator = collections.get(collName);
        switch creator{
            case null{
                
                let status = collectionCanisters.get(collName);
                switch status{
                    case null{
                        let nested = nestedCollections.get(collName);
                        switch nested{
                            case null{
                                allowedNesting.put(collName,combinations);
                                allowedNestedMetadata.put(collName, metaCombinations);
                                nestedCollections.put(collName,parentName);
                                collectionCanisters.put(collName, "pending");
                                collectionAllowables.put(collName, allowed);
                                collections.put(collName, caller);
                                return true;
                            };
                            case (?text2){
                                return false;
                            };
                        };
                        
                    };
                    case (?text){
                        return false;
                    };
                };
            };
            case (?principal2){
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
                //Debug.print(debug_show "hiiii");
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

     public shared({caller}) func equipNested(collName: Text, parentName: Text, tidc: Nat, tidp: Nat): async Bool{
        let childCollOpt = collections.get(collName);
        var childCanister = "";
        switch childCollOpt{
            case null{
                
                return false;
            };
            case (?principal){ };
            
        };
        let statusChild = collectionCanisters.get(collName);
        switch statusChild{
            case null{
                
                return false;
            };
            case (?text){
                if (text == "approved" or text == "pending"){
                    
                    return false;
                }
                else{
                    childCanister := text;
                }
            };
        };
        let parentCollOpt = collections.get(parentName);
        var parentCanister = "";
        switch parentCollOpt{
            case null{
                
                return false;
            };
            case (?principal){ };
            
        };
        let statusParent = collectionCanisters.get(parentName);
        switch statusParent{
            case null{
                
                return false;
            };
            case (?text){
                if (text == "approved" or text == "pending"){
                    
                    return false;
                }
                else {
                    parentCanister := text;
                    
                };
            };
        };
        let actc = actor(childCanister):actor {ownerOf: (Nat) -> async (?Principal)};
        let ownerC = await actc.ownerOf(tidc);
        let actp = actor(parentCanister):actor {ownerOf: (Nat) -> async (?Principal)};
        let ownerP = await actp.ownerOf(tidp);
        
        switch ownerC{
            case null{
                return false;
            };
            case (?principal){
                if (principal != caller){
                    return false;
                }; 
            };
        };
        
        switch ownerP{
            case null{
                return false;
            };
            case (?principal){
                if (principal != caller){
                    return false;
                }; 
            };
        };
        
        let actc2 = actor(childCanister):actor {equip: (Nat, Nat) -> async (Nat)};
        
        let eq = await actc2.equip(tidc, tidp);

        let actp4 = actor(parentCanister):actor {isOccupyTrue: (Nat) -> async (Bool)};
        
        let occ = await actp4.isOccupyTrue(tidp);
        
        if (eq == 0 or occ){
            
            return false;
        }
        else{
            let actp5 = actor(parentCanister):actor {setOccupyTrue: (Nat) -> async (Bool)};
            
            let occ2 = await actp5.setOccupyTrue(tidp);
            if (not occ2){
                return false;
            };
            let imageOpt = allowedNesting.get(collName);
            var meta2: [(Text, Text)] = [];
            var image2 = "";
            switch imageOpt{
                case null{
                    return false;
                };
                case (?arr){
                    let metaOpt = allowedNestedMetadata.get(collName);
                    switch metaOpt{
                        case null{
                            return false;
                        };
                        case (?x){
                        var k = 0;
                        let actc3 = actor(childCanister):actor {getURI: (Nat) -> async (Text)};
                        let actp3 = actor(parentCanister):actor {getURI: (Nat) -> async (Text)};
                        let equip1 = await actc3.getURI(tidc);
                        let image1 = await actp3.getURI(tidp);
                        while (k < arr.size()){
                            if (arr[k].0 == equip1){
                                var kk = 1;
                                while (kk < arr[k].1.size()){
                                    if (image1 == arr[k].1[kk]){
                                        image2 := arr[k].1[kk-1];
                                        meta2 := x[k].1[kk-1];
                                    };
                                    kk += 1;
                                };
                            };
                            k += 1;
                        };
                    };
                    //architecture of arr: [(Child1 [P1 P1default P2 P2default...]]
                    };
                    
                    
                    
                };
            };
            if (image2 == "" or meta2.size() == 0){
                return false;
            };
            
            let actp2 = actor(parentCanister):actor {updateDNFT2: (Principal,Nat,Text,[(Text,Text)]) -> async (Bool)};
            let dnft = await actp2.updateDNFT2(caller, tidp, image2, meta2);
            return true;
        };
    return false;


    };

     public shared({caller}) func deequipNested(collName: Text, parentName: Text, tidc: Nat, tidp: Nat): async Bool{
        let childCollOpt = collections.get(collName);
        var childCanister = "";
        switch childCollOpt{
            case null{
                
                return false;
            };
            case (?principal){ };
            
        };
        let statusChild = collectionCanisters.get(collName);
        switch statusChild{
            case null{
                
                return false;
            };
            case (?text){
                if (text == "approved" or text == "pending"){
                    
                    return false;
                }
                else{
                    childCanister := text;
                }
            };
        };
        let parentCollOpt = collections.get(parentName);
        var parentCanister = "";
        switch parentCollOpt{
            case null{
                
                return false;
            };
            case (?principal){ };
            
        };
        let statusParent = collectionCanisters.get(parentName);
        switch statusParent{
            case null{
                
                return false;
            };
            case (?text){
                if (text == "approved" or text == "pending"){
                    
                    return false;
                }
                else {
                    parentCanister := text;
                    
                };
            };
        };
        let actc = actor(childCanister):actor {ownerOf: (Nat) -> async (?Principal)};
        let ownerC = await actc.ownerOf(tidc);
        let actp = actor(parentCanister):actor {ownerOf: (Nat) -> async (?Principal)};
        let ownerP = await actp.ownerOf(tidp);
        
        switch ownerC{
            case null{
                return false;
            };
            case (?principal){
                if (principal != caller){
                    return false;
                }; 
            };
        };
        
        switch ownerP{
            case null{
                return false;
            };
            case (?principal){
                if (principal != caller){
                    return false;
                }; 
            };
        };
        
        let actc2 = actor(childCanister):actor {dequip: (Nat, Nat) -> async (Nat)};
        
        let eq = await actc2.dequip(tidc, tidp);

        let actp4 = actor(parentCanister):actor {isOccupyTrue: (Nat) -> async (Bool)};
        
        let occ = await actp4.isOccupyTrue(tidp);
        
        if (eq == 0 or not occ){
            Debug.print("mri");
            Debug.print(debug_show eq);
            Debug.print(debug_show occ);
            return false;
        }
        else{
            let actp5 = actor(parentCanister):actor {setOccupyFalse: (Nat) -> async (Bool)};
            
            let occ2 = await actp5.setOccupyFalse(tidp);
            if (not occ2){
                return false;
            };
            let imageOpt = allowedNesting.get(collName);
            var meta2: [(Text, Text)] = [];
            var image2 = "";
            switch imageOpt{
                case null{
                    return false;
                };
                case (?arr){
                    let metaOpt = allowedNestedMetadata.get(collName);
                    switch metaOpt{
                        case null{
                            return false;
                        };
                        case (?x){
                        var k = 0;
                        let actc3 = actor(childCanister):actor {getURI: (Nat) -> async (Text)};
                        let actp3 = actor(parentCanister):actor {getURI: (Nat) -> async (Text)};
                        let equip1 = await actc3.getURI(tidc);
                        let image1 = await actp3.getURI(tidp);
                        while (k < arr.size()){
                            if (arr[k].0 == equip1){
                                var kk = 0;
                                while (kk + 1 < arr[k].1.size()){
                                    if (image1 == arr[k].1[kk]){
                                        image2 := arr[k].1[kk+1];
                                        meta2 := x[k].1[kk+1];
                                    };
                                    kk += 1;
                                };
                            };
                            k += 1;
                        };
                    };
                    //architecture of arr: [(Child1 [P1 P1default P2 P2default...]]
                    };
                    
                    
                    
                };
            };
            if (image2 == "" or meta2.size() == 0){
                return false;
            };
            
            let actp2 = actor(parentCanister):actor {updateDNFT2: (Principal,Nat,Text,[(Text,Text)]) -> async (Bool)};
            let dnft = await actp2.updateDNFT2(caller, tidp, image2, meta2);
            return true;
        };
    return false;


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
        var price2 : Int = res2 - res1;
        var price : Nat = 0;
        if (price2 >= 0){
            price := res2 - res1;
        };
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
        nestedCollectionEntries := Iter.toArray(nestedCollections.entries());
        allowedNestedMetadataEntries := Iter.toArray(allowedNestedMetadata.entries());
        allowedNestingEntries := Iter.toArray(allowedNesting.entries());
        collectionAllowableEntries := Iter.toArray(collectionAllowables.entries());
    };

    system func postupgrade() {
        collectionEntries := [];
        collectionCanisterEntries := [];
        collectionPopularityEntries := [];
        upvoteCollectionEntries := [];
        downvoteCollectionEntries := [];
        collectionVolumeEntries := [];
        nestedCollectionEntries := [];
        allowedNestedMetadataEntries := [];
        allowedNestingEntries := [];
        collectionAllowableEntries := [];
    };

};