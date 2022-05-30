import Text "mo:base/Text";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";

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

    system func preupgrade() {
        collectionEntries := Iter.toArray(collections.entries());
        collectionCanisterEntries := Iter.toArray(collectionCanisters.entries());
    };

    system func postupgrade() {
        collectionEntries := [];
        collectionCanisterEntries := [];
    };

};