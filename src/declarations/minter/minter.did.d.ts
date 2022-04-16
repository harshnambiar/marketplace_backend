import type { Principal } from '@dfinity/principal';
export interface CollectionMetadata {
  'logo' : string,
  'name' : string,
  'created_at' : bigint,
  'upgraded_at' : bigint,
  'custodians' : Array<Principal>,
  'max_items' : bigint,
  'symbol' : string,
}
export interface DRC721 {
  'approve' : (arg_0: Principal, arg_1: TokenId) => Promise<undefined>,
  'auctionBid' : (arg_0: TokenId, arg_1: bigint) => Promise<boolean>,
  'auctionEnd' : (arg_0: TokenId) => Promise<boolean>,
  'auctionStart' : (arg_0: TokenId, arg_1: bigint) => Promise<boolean>,
  'balanceOf' : (arg_0: Principal) => Promise<[] | [bigint]>,
  'getApproved' : (arg_0: bigint) => Promise<Principal>,
  'isApprovedForAll' : (arg_0: Principal, arg_1: Principal) => Promise<boolean>,
  'mint' : (arg_0: string, arg_1: TokenMetadata) => Promise<bigint>,
  'mint_principal' : (
      arg_0: string,
      arg_1: TokenMetadata,
      arg_2: Principal,
    ) => Promise<bigint>,
  'name' : () => Promise<string>,
  'ownerOf' : (arg_0: TokenId) => Promise<[] | [Principal]>,
  'setApprovalForAll' : (arg_0: Principal, arg_1: boolean) => Promise<
      undefined
    >,
  'symbol' : () => Promise<string>,
  'tokenURI' : (arg_0: TokenId) => Promise<[] | [string]>,
  'transferFrom' : (
      arg_0: Principal,
      arg_1: Principal,
      arg_2: bigint,
    ) => Promise<undefined>,
}
export type GenericValue = { 'principal' : Principal } |
  { 'boolContent' : boolean } |
  { 'nat64Content' : bigint } |
  { 'nat8Content' : number } |
  { 'nat32Content' : number } |
  { 'intContent' : bigint } |
  { 'natContent' : bigint } |
  { 'nestedContent' : Array<[string, GenericValue]> } |
  { 'int8Content' : number } |
  { 'int64Content' : bigint } |
  { 'nat16Content' : number } |
  { 'int32Content' : number } |
  { 'floatContent' : number } |
  { 'blobContent' : Array<number> } |
  { 'int16Content' : number } |
  { 'textContent' : string };
export type TokenId = bigint;
export interface TokenMetadata {
  'transferred_at' : [] | [bigint],
  'transferred_by' : [] | [Principal],
  'collection' : [] | [CollectionMetadata],
  'owner' : [] | [Principal],
  'operator' : [] | [Principal],
  'approved_at' : [] | [bigint],
  'approved_by' : [] | [Principal],
  'properties' : Array<[string, GenericValue]>,
  'is_burned' : boolean,
  'token_identifier' : bigint,
  'burned_at' : [] | [bigint],
  'burned_by' : [] | [Principal],
  'minted_at' : bigint,
  'minted_by' : Principal,
}
export interface _SERVICE extends DRC721 {}
