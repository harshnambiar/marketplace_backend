export const idlFactory = ({ IDL }) => {
  const GenericValue = IDL.Rec();
  const TokenId = IDL.Nat;
  const CollectionMetadata = IDL.Record({
    'logo' : IDL.Text,
    'name' : IDL.Text,
    'created_at' : IDL.Nat64,
    'upgraded_at' : IDL.Nat64,
    'custodians' : IDL.Vec(IDL.Principal),
    'max_items' : IDL.Nat64,
    'symbol' : IDL.Text,
  });
  GenericValue.fill(
    IDL.Variant({
      'principal' : IDL.Principal,
      'boolContent' : IDL.Bool,
      'nat64Content' : IDL.Nat64,
      'nat8Content' : IDL.Nat8,
      'nat32Content' : IDL.Nat32,
      'intContent' : IDL.Int,
      'natContent' : IDL.Nat,
      'nestedContent' : IDL.Vec(IDL.Tuple(IDL.Text, GenericValue)),
      'int8Content' : IDL.Int8,
      'int64Content' : IDL.Int64,
      'nat16Content' : IDL.Nat16,
      'int32Content' : IDL.Int32,
      'floatContent' : IDL.Float64,
      'blobContent' : IDL.Vec(IDL.Nat8),
      'int16Content' : IDL.Int16,
      'textContent' : IDL.Text,
    })
  );
  const TokenMetadata = IDL.Record({
    'transferred_at' : IDL.Opt(IDL.Nat64),
    'transferred_by' : IDL.Opt(IDL.Principal),
    'collection' : IDL.Opt(CollectionMetadata),
    'owner' : IDL.Opt(IDL.Principal),
    'operator' : IDL.Opt(IDL.Principal),
    'approved_at' : IDL.Opt(IDL.Nat64),
    'approved_by' : IDL.Opt(IDL.Principal),
    'properties' : IDL.Vec(IDL.Tuple(IDL.Text, GenericValue)),
    'is_burned' : IDL.Bool,
    'token_identifier' : IDL.Nat,
    'burned_at' : IDL.Opt(IDL.Nat64),
    'burned_by' : IDL.Opt(IDL.Principal),
    'minted_at' : IDL.Nat64,
    'minted_by' : IDL.Principal,
  });
  const DRC721 = IDL.Service({
    'approve' : IDL.Func([IDL.Principal, TokenId], [], []),
    'balanceOf' : IDL.Func([IDL.Principal], [IDL.Opt(IDL.Nat)], []),
    'getApproved' : IDL.Func([IDL.Nat], [IDL.Principal], []),
    'isApprovedForAll' : IDL.Func(
        [IDL.Principal, IDL.Principal],
        [IDL.Bool],
        [],
      ),
    'mint' : IDL.Func([IDL.Text, TokenMetadata], [IDL.Nat], []),
    'mint_principal' : IDL.Func(
        [IDL.Text, TokenMetadata, IDL.Principal],
        [IDL.Nat],
        [],
      ),
    'name' : IDL.Func([], [IDL.Text], ['query']),
    'ownerOf' : IDL.Func([TokenId], [IDL.Opt(IDL.Principal)], []),
    'setApprovalForAll' : IDL.Func([IDL.Principal, IDL.Bool], [], ['oneway']),
    'symbol' : IDL.Func([], [IDL.Text], ['query']),
    'tokenURI' : IDL.Func([TokenId], [IDL.Opt(IDL.Text)], ['query']),
    'transferFrom' : IDL.Func(
        [IDL.Principal, IDL.Principal, IDL.Nat],
        [],
        ['oneway'],
      ),
  });
  return DRC721;
};
export const init = ({ IDL }) => { return [IDL.Text, IDL.Text]; };
