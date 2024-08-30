open Table
type id = string

//shorthand for punning
let isPrimaryKey = true
let isNullable = true
let isArray = true
let isIndex = true

module type Entity = {
  type t
  let schema: S.schema<t>
  let rowsSchema: S.schema<array<t>>
  let table: Table.table
}

let batchRead = (type entity, ~entityMod: module(Entity with type t = entity)) => {
  let module(EntityMod) = entityMod
  let {table, rowsSchema} = module(EntityMod)
  DbFunctionsEntities.makeReadEntities(~table, ~rowsSchema)
}

let batchSet = (type entity, ~entityMod: module(Entity with type t = entity)) => {
  let module(EntityMod) = entityMod
  let {table, rowsSchema} = module(EntityMod)
  DbFunctionsEntities.makeBatchSet(~table, ~rowsSchema)
}

let batchDelete = (type entity, ~entityMod: module(Entity with type t = entity)) => {
  let module(EntityMod) = entityMod
  let {table} = module(EntityMod)
  DbFunctionsEntities.makeBatchDelete(~table)
}

module Account = {
  @genType
  type t = {id: id}

  let schema = S.object((. s) => {
    id: s.field("id", S.string),
  })

  let rowsSchema = S.array(schema)

  let table = mkTable(
    "Account",
    ~fields=[
      mkField("id", Text, ~isPrimaryKey),
      mkField("db_write_timestamp", Timestamp, ~default="CURRENT_TIMESTAMP"),
    ],
  )
}

module Collection = {
  @genType
  type t = {
    contractAddress: string,
    id: id,
    isERC1155: bool,
    name: string,
    owner_id: id,
    symbol: string,
    uri: string,
  }

  let schema = S.object((. s) => {
    contractAddress: s.field("contractAddress", S.string),
    id: s.field("id", S.string),
    isERC1155: s.field("isERC1155", S.bool),
    name: s.field("name", S.string),
    owner_id: s.field("owner_id", S.string),
    symbol: s.field("symbol", S.string),
    uri: s.field("uri", S.string),
  })

  let rowsSchema = S.array(schema)

  let table = mkTable(
    "Collection",
    ~fields=[
      mkField("contractAddress", Text),
      mkField("id", Text, ~isPrimaryKey),
      mkField("isERC1155", Boolean),
      mkField("name", Text),
      mkField("owner", Text, ~linkedEntity="Account"),
      mkField("symbol", Text),
      mkField("uri", Text),
      mkField("db_write_timestamp", Timestamp, ~default="CURRENT_TIMESTAMP"),
      mkDerivedFromField("nfts", ~derivedFromEntity="Nft", ~derivedFromField="collection"),
    ],
    ~compositeIndices=[["contractAddress", "owner"]],
  )
}

module Factory_CollectionDeployed = {
  @genType
  type t = {
    id: id,
    isERC1155: bool,
    name: string,
    owner: string,
    symbol: string,
    tokenAddress: string,
    uri: string,
  }

  let schema = S.object((. s) => {
    id: s.field("id", S.string),
    isERC1155: s.field("isERC1155", S.bool),
    name: s.field("name", S.string),
    owner: s.field("owner", S.string),
    symbol: s.field("symbol", S.string),
    tokenAddress: s.field("tokenAddress", S.string),
    uri: s.field("uri", S.string),
  })

  let rowsSchema = S.array(schema)

  let table = mkTable(
    "Factory_CollectionDeployed",
    ~fields=[
      mkField("id", Text, ~isPrimaryKey),
      mkField("isERC1155", Boolean),
      mkField("name", Text),
      mkField("owner", Text),
      mkField("symbol", Text),
      mkField("tokenAddress", Text),
      mkField("uri", Text),
      mkField("db_write_timestamp", Timestamp, ~default="CURRENT_TIMESTAMP"),
    ],
  )
}

module Nft = {
  @genType
  type t = {
    attributes: string,
    collection_id: id,
    description: string,
    id: id,
    image: string,
    isPhygital: bool,
    name: string,
    owner_id: id,
    standard: string,
    supply: string,
    tokenId: Ethers.BigInt.t,
    tokenUrl: string,
  }

  let schema = S.object((. s) => {
    attributes: s.field("attributes", S.string),
    collection_id: s.field("collection_id", S.string),
    description: s.field("description", S.string),
    id: s.field("id", S.string),
    image: s.field("image", S.string),
    isPhygital: s.field("isPhygital", S.bool),
    name: s.field("name", S.string),
    owner_id: s.field("owner_id", S.string),
    standard: s.field("standard", S.string),
    supply: s.field("supply", S.string),
    tokenId: s.field("tokenId", Ethers.BigInt.schema),
    tokenUrl: s.field("tokenUrl", S.string),
  })

  let rowsSchema = S.array(schema)

  let table = mkTable(
    "Nft",
    ~fields=[
      mkField("attributes", Text),
      mkField("collection", Text, ~isIndex, ~linkedEntity="Collection"),
      mkField("description", Text),
      mkField("id", Text, ~isPrimaryKey),
      mkField("image", Text),
      mkField("isPhygital", Boolean),
      mkField("name", Text),
      mkField("owner", Text, ~isIndex, ~linkedEntity="Account"),
      mkField("standard", Text),
      mkField("supply", Text),
      mkField("tokenId", Numeric),
      mkField("tokenUrl", Text),
      mkField("db_write_timestamp", Timestamp, ~default="CURRENT_TIMESTAMP"),
    ],
  )
}

module SokosERC721_Transfer = {
  @genType
  type t = {
    from: string,
    id: id,
    to: string,
    tokenId: Ethers.BigInt.t,
  }

  let schema = S.object((. s) => {
    from: s.field("from", S.string),
    id: s.field("id", S.string),
    to: s.field("to", S.string),
    tokenId: s.field("tokenId", Ethers.BigInt.schema),
  })

  let rowsSchema = S.array(schema)

  let table = mkTable(
    "SokosERC721_Transfer",
    ~fields=[
      mkField("from", Text),
      mkField("id", Text, ~isPrimaryKey),
      mkField("to", Text),
      mkField("tokenId", Numeric),
      mkField("db_write_timestamp", Timestamp, ~default="CURRENT_TIMESTAMP"),
    ],
  )
}

type entity =
  | AccountEntity(Account.t)
  | CollectionEntity(Collection.t)
  | Factory_CollectionDeployedEntity(Factory_CollectionDeployed.t)
  | NftEntity(Nft.t)
  | SokosERC721_TransferEntity(SokosERC721_Transfer.t)

type entityName =
  | @as("Account") Account
  | @as("Collection") Collection
  | @as("Factory_CollectionDeployed") Factory_CollectionDeployed
  | @as("Nft") Nft
  | @as("SokosERC721_Transfer") SokosERC721_Transfer

let entityNameSchema = S.union([
  S.literal(Account),
  S.literal(Collection),
  S.literal(Factory_CollectionDeployed),
  S.literal(Nft),
  S.literal(SokosERC721_Transfer),
])

let getEntityParamsDecoder = entityName =>
  switch entityName {
  | Account =>
    json => json->S.parseWith(. Account.schema)->Belt.Result.map(decoded => AccountEntity(decoded))
  | Collection =>
    json =>
      json->S.parseWith(. Collection.schema)->Belt.Result.map(decoded => CollectionEntity(decoded))
  | Factory_CollectionDeployed =>
    json =>
      json
      ->S.parseWith(. Factory_CollectionDeployed.schema)
      ->Belt.Result.map(decoded => Factory_CollectionDeployedEntity(decoded))
  | Nft => json => json->S.parseWith(. Nft.schema)->Belt.Result.map(decoded => NftEntity(decoded))
  | SokosERC721_Transfer =>
    json =>
      json
      ->S.parseWith(. SokosERC721_Transfer.schema)
      ->Belt.Result.map(decoded => SokosERC721_TransferEntity(decoded))
  }

let allTables: array<table> = [
  Account.table,
  Collection.table,
  Factory_CollectionDeployed.table,
  Nft.table,
  SokosERC721_Transfer.table,
]
let schema = Schema.make(allTables)
