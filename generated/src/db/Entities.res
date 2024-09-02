open Table
open Enums.EntityType
type id = string

type internalEntity
module type Entity = {
  type t
  let key: string
  let name: Enums.EntityType.t
  let schema: S.schema<t>
  let rowsSchema: S.schema<array<t>>
  let table: Table.table
}
module type InternalEntity = Entity with type t = internalEntity
external entityModToInternal: module(Entity with type t = 'a) => module(InternalEntity) = "%identity"

//shorthand for punning
let isPrimaryKey = true
let isNullable = true
let isArray = true
let isIndex = true

@genType
type whereOperations<'entity, 'fieldType> = {eq: 'fieldType => promise<array<'entity>>}

module Account = {
  let key = "Account"
  let name = Account
  @genType
  type t = {
    id: id,
  }

  let schema = S.object((s): t => {
    id: s.field("id", S.string),
  })

  let rowsSchema = S.array(schema)

  @genType
  type indexedFieldOperations = {
    
  }

  let table = mkTable(
     (name :> string),
    ~fields=[
      mkField(
      "id", 
      Text,
      ~isPrimaryKey,
      
      
      
      
      ),
      mkField("db_write_timestamp", Timestamp, ~default="CURRENT_TIMESTAMP"),
    ],
  )
}
 
module Collection = {
  let key = "Collection"
  let name = Collection
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

  let schema = S.object((s): t => {
    contractAddress: s.field("contractAddress", S.string),
    id: s.field("id", S.string),
    isERC1155: s.field("isERC1155", S.bool),
    name: s.field("name", S.string),
    
    owner_id: s.field("owner_id", S.string),
    symbol: s.field("symbol", S.string),
    uri: s.field("uri", S.string),
  })

  let rowsSchema = S.array(schema)

  @genType
  type indexedFieldOperations = {
    
  }

  let table = mkTable(
     (name :> string),
    ~fields=[
      mkField(
      "contractAddress", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "id", 
      Text,
      ~isPrimaryKey,
      
      
      
      
      ),
      mkField(
      "isERC1155", 
      Boolean,
      
      
      
      
      
      ),
      mkField(
      "name", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "owner", 
      Text,
      
      
      
      
      ~linkedEntity="Account",
      ),
      mkField(
      "symbol", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "uri", 
      Text,
      
      
      
      
      
      ),
      mkField("db_write_timestamp", Timestamp, ~default="CURRENT_TIMESTAMP"),
      mkDerivedFromField(
      "nfts", 
      ~derivedFromEntity="Nft",
      ~derivedFromField="collection",
      ),
    ],
    ~compositeIndices=[
      [
      "contractAddress",
      "owner",
      ],
    ],
  )
}
 
module Factory_CollectionDeployed = {
  let key = "Factory_CollectionDeployed"
  let name = Factory_CollectionDeployed
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

  let schema = S.object((s): t => {
    id: s.field("id", S.string),
    isERC1155: s.field("isERC1155", S.bool),
    name: s.field("name", S.string),
    owner: s.field("owner", S.string),
    symbol: s.field("symbol", S.string),
    tokenAddress: s.field("tokenAddress", S.string),
    uri: s.field("uri", S.string),
  })

  let rowsSchema = S.array(schema)

  @genType
  type indexedFieldOperations = {
    
  }

  let table = mkTable(
     (name :> string),
    ~fields=[
      mkField(
      "id", 
      Text,
      ~isPrimaryKey,
      
      
      
      
      ),
      mkField(
      "isERC1155", 
      Boolean,
      
      
      
      
      
      ),
      mkField(
      "name", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "owner", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "symbol", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "tokenAddress", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "uri", 
      Text,
      
      
      
      
      
      ),
      mkField("db_write_timestamp", Timestamp, ~default="CURRENT_TIMESTAMP"),
    ],
  )
}
 
module Nft = {
  let key = "Nft"
  let name = Nft
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
    tokenId: bigint,
    tokenUrl: string,
  }

  let schema = S.object((s): t => {
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
    tokenId: s.field("tokenId", BigInt.schema),
    tokenUrl: s.field("tokenUrl", S.string),
  })

  let rowsSchema = S.array(schema)

  @genType
  type indexedFieldOperations = {
    
      @as("collection_id") collection_id: whereOperations<t, id>,
    
      @as("owner_id") owner_id: whereOperations<t, id>,
    
  }

  let table = mkTable(
     (name :> string),
    ~fields=[
      mkField(
      "attributes", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "collection", 
      Text,
      
      
      
      ~isIndex,
      ~linkedEntity="Collection",
      ),
      mkField(
      "description", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "id", 
      Text,
      ~isPrimaryKey,
      
      
      
      
      ),
      mkField(
      "image", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "isPhygital", 
      Boolean,
      
      
      
      
      
      ),
      mkField(
      "name", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "owner", 
      Text,
      
      
      
      ~isIndex,
      ~linkedEntity="Account",
      ),
      mkField(
      "standard", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "supply", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "tokenId", 
      Numeric,
      
      
      
      
      
      ),
      mkField(
      "tokenUrl", 
      Text,
      
      
      
      
      
      ),
      mkField("db_write_timestamp", Timestamp, ~default="CURRENT_TIMESTAMP"),
    ],
  )
}
 
module SokosERC721_Transfer = {
  let key = "SokosERC721_Transfer"
  let name = SokosERC721_Transfer
  @genType
  type t = {
    from: string,
    id: id,
    to: string,
    tokenId: bigint,
  }

  let schema = S.object((s): t => {
    from: s.field("from", S.string),
    id: s.field("id", S.string),
    to: s.field("to", S.string),
    tokenId: s.field("tokenId", BigInt.schema),
  })

  let rowsSchema = S.array(schema)

  @genType
  type indexedFieldOperations = {
    
  }

  let table = mkTable(
     (name :> string),
    ~fields=[
      mkField(
      "from", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "id", 
      Text,
      ~isPrimaryKey,
      
      
      
      
      ),
      mkField(
      "to", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "tokenId", 
      Numeric,
      
      
      
      
      
      ),
      mkField("db_write_timestamp", Timestamp, ~default="CURRENT_TIMESTAMP"),
    ],
  )
}
 

type entity = 
  | Account(Account.t)
  | Collection(Collection.t)
  | Factory_CollectionDeployed(Factory_CollectionDeployed.t)
  | Nft(Nft.t)
  | SokosERC721_Transfer(SokosERC721_Transfer.t)

let makeGetter = (schema, accessor) => json => json->S.parseWith(schema)->Belt.Result.map(accessor)

let getEntityParamsDecoder = (entityName: Enums.EntityType.t) =>
  switch entityName {
  | Account => makeGetter(Account.schema, e => Account(e))
  | Collection => makeGetter(Collection.schema, e => Collection(e))
  | Factory_CollectionDeployed => makeGetter(Factory_CollectionDeployed.schema, e => Factory_CollectionDeployed(e))
  | Nft => makeGetter(Nft.schema, e => Nft(e))
  | SokosERC721_Transfer => makeGetter(SokosERC721_Transfer.schema, e => SokosERC721_Transfer(e))
  }

let allTables: array<table> = [
  Account.table,
  Collection.table,
  Factory_CollectionDeployed.table,
  Nft.table,
  SokosERC721_Transfer.table,
]
let schema = Schema.make(allTables)

@get
external getEntityId: internalEntity => string = "id"

exception UnexpectedIdNotDefinedOnEntity
let getEntityIdUnsafe = (entity: 'entity): id =>
  switch Utils.magic(entity)["id"] {
  | Some(id) => id
  | None =>
    UnexpectedIdNotDefinedOnEntity->ErrorHandling.mkLogAndRaise(
      ~msg="Property 'id' does not exist on expected entity object",
    )
  }
