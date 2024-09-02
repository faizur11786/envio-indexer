//*************
//***ENTITIES**
//*************
@genType.as("Id")
type id = string

@genType
type contractRegistrations = {
  // TODO: only add contracts we've registered for the event in the config
  addFactory: (Address.t) => unit,
  addSokosERC721: (Address.t) => unit,
}

@genType
type entityLoaderContext<'entity, 'indexedFieldOperations> = {
  get: id => promise<option<'entity>>,
  getWhere: 'indexedFieldOperations,
}

@genType
type loaderContext = {
  log: Logs.userLogger,
  @as("Account") account: entityLoaderContext<Entities.Account.t, Entities.Account.indexedFieldOperations>,
  @as("Collection") collection: entityLoaderContext<Entities.Collection.t, Entities.Collection.indexedFieldOperations>,
  @as("Factory_CollectionDeployed") factory_CollectionDeployed: entityLoaderContext<Entities.Factory_CollectionDeployed.t, Entities.Factory_CollectionDeployed.indexedFieldOperations>,
  @as("Nft") nft: entityLoaderContext<Entities.Nft.t, Entities.Nft.indexedFieldOperations>,
  @as("SokosERC721_Transfer") sokosERC721_Transfer: entityLoaderContext<Entities.SokosERC721_Transfer.t, Entities.SokosERC721_Transfer.indexedFieldOperations>,
}

@genType
type entityHandlerContext<'entity> = {
  get: id => promise<option<'entity>>,
  set: 'entity => unit,
  deleteUnsafe: id => unit,
}


@genType
type handlerContext = {
  log: Logs.userLogger,
  @as("Account") account: entityHandlerContext<Entities.Account.t>,
  @as("Collection") collection: entityHandlerContext<Entities.Collection.t>,
  @as("Factory_CollectionDeployed") factory_CollectionDeployed: entityHandlerContext<Entities.Factory_CollectionDeployed.t>,
  @as("Nft") nft: entityHandlerContext<Entities.Nft.t>,
  @as("SokosERC721_Transfer") sokosERC721_Transfer: entityHandlerContext<Entities.SokosERC721_Transfer.t>,
}

//Re-exporting types for backwards compatability
@genType.as("Account")
type account = Entities.Account.t
@genType.as("Collection")
type collection = Entities.Collection.t
@genType.as("Factory_CollectionDeployed")
type factory_CollectionDeployed = Entities.Factory_CollectionDeployed.t
@genType.as("Nft")
type nft = Entities.Nft.t
@genType.as("SokosERC721_Transfer")
type sokosERC721_Transfer = Entities.SokosERC721_Transfer.t

type eventIdentifier = {
  chainId: int,
  blockTimestamp: int,
  blockNumber: int,
  logIndex: int,
}

type entityUpdateAction<'entityType> =
  | Set('entityType)
  | Delete

type entityUpdate<'entityType> = {
  eventIdentifier: eventIdentifier,
  shouldSaveHistory: bool,
  entityId: id,
  entityUpdateAction: entityUpdateAction<'entityType>,
}

let mkEntityUpdate = (~shouldSaveHistory=true, ~eventIdentifier, ~entityId, entityUpdateAction) => {
  entityId,
  shouldSaveHistory,
  eventIdentifier,
  entityUpdateAction,
}

type entityValueAtStartOfBatch<'entityType> =
  | NotSet // The entity isn't in the DB yet
  | AlreadySet('entityType)

type existingValueInDb<'entityType> =
  | Retrieved(entityValueAtStartOfBatch<'entityType>)
  // NOTE: We use an postgres function solve the issue of this entities previous value not being known.
  | Unknown

type updatedValue<'entityType> = {
  // Initial value within a batch
  initial: existingValueInDb<'entityType>,
  latest: entityUpdate<'entityType>,
  history: array<entityUpdate<'entityType>>,
}
@genType
type inMemoryStoreRowEntity<'entityType> =
  | Updated(updatedValue<'entityType>)
  | InitialReadFromDb(entityValueAtStartOfBatch<'entityType>) // This means there is no change from the db.

//*************
//**CONTRACTS**
//*************

module Log = {
  type t = {
    address: Address.t,
    data: string,
    topics: array<Ethers.EventFilter.topic>,
    logIndex: int,
  }

  let fieldNames = ["address", "data", "topics", "logIndex"]
}

module Transaction = {
  @genType
  type t = {
  }

  let schema: S.schema<t> = S.object((_s): t => {
  })

  let querySelection: array<HyperSyncClient.QueryTypes.transactionField> = [
  ]

  let nonOptionalFieldNames: array<string> = [
  ]
}

module Block = {
  type selectableFields = {
  }

  let schema: S.schema<selectableFields> = S.object((_s): selectableFields => {
  })

  @genType
  type t = {
    number: int,
    timestamp: int,
    hash: string,
    ...selectableFields,
  }

  let getSelectableFields = ({
    }: t): selectableFields => {
    }

  let querySelection: array<HyperSyncClient.QueryTypes.blockField> = [
    Number,
    Timestamp,
    Hash,
  ]

  let nonOptionalFieldNames: array<string> = [
    "number",
    "timestamp",
    "hash",
  ]
}

@genType.as("EventLog")
type eventLog<'a> = {
  params: 'a,
  chainId: int,
  srcAddress: Address.t,
  logIndex: int,
  transaction: Transaction.t,
  block: Block.t,
}

type internalEventArgs

module type Event = {
  let key: string
  let name: string
  let contractName: string
  let sighash: string // topic0 for Evm and rb for Fuel receipts

  type eventArgs
  let eventArgsSchema: S.schema<eventArgs>
  let convertHyperSyncEventArgs: HyperSyncClient.Decoder.decodedEvent => eventArgs
  let decodeHyperFuelData: string => eventArgs
}
module type InternalEvent = Event with type eventArgs = internalEventArgs

external eventToInternal: eventLog<'a> => eventLog<internalEventArgs> = "%identity"
external eventModToInternal: module(Event with type eventArgs = 'a) => module(InternalEvent) = "%identity"
external eventModWithoutArgTypeToInternal: module(Event) => module(InternalEvent) = "%identity"

module Factory = {
  module CollectionDeployed = {
    let key = "Factory_0xd92929f2fc968c1e7209cebe8cc0a6804a8dea358496b35f07a20e1af21e4e88"
    let name = "CollectionDeployed"
    let contractName = "Factory"
    let sighash = "0xd92929f2fc968c1e7209cebe8cc0a6804a8dea358496b35f07a20e1af21e4e88"
    @genType
    type eventArgs = {tokenAddress: Address.t, owner: Address.t, isERC1155: bool, name: string, symbol: string, uri: string}
    let eventArgsSchema = S.object(s => {tokenAddress: s.field("tokenAddress", Address.schema), owner: s.field("owner", Address.schema), isERC1155: s.field("isERC1155", S.bool), name: s.field("name", S.string), symbol: s.field("symbol", S.string), uri: s.field("uri", S.string)})
    let convertHyperSyncEventArgs = (decodedEvent: HyperSyncClient.Decoder.decodedEvent): eventArgs => {
      {
        tokenAddress: decodedEvent.indexed->Js.Array2.unsafe_get(0)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        owner: decodedEvent.body->Js.Array2.unsafe_get(0)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        isERC1155: decodedEvent.body->Js.Array2.unsafe_get(1)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        name: decodedEvent.body->Js.Array2.unsafe_get(2)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        symbol: decodedEvent.body->Js.Array2.unsafe_get(3)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        uri: decodedEvent.body->Js.Array2.unsafe_get(4)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
      }
    }
    let decodeHyperFuelData = (_) => Js.Exn.raiseError("HyperFuel decoder not implemented")
  }

}

module SokosERC721 = {
  module Transfer = {
    let key = "SokosERC721_0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
    let name = "Transfer"
    let contractName = "SokosERC721"
    let sighash = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
    @genType
    type eventArgs = {from: Address.t, to: Address.t, tokenId: bigint}
    let eventArgsSchema = S.object(s => {from: s.field("from", Address.schema), to: s.field("to", Address.schema), tokenId: s.field("tokenId", BigInt.schema)})
    let convertHyperSyncEventArgs = (decodedEvent: HyperSyncClient.Decoder.decodedEvent): eventArgs => {
      {
        from: decodedEvent.indexed->Js.Array2.unsafe_get(0)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        to: decodedEvent.indexed->Js.Array2.unsafe_get(1)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        tokenId: decodedEvent.indexed->Js.Array2.unsafe_get(2)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
      }
    }
    let decodeHyperFuelData = (_) => Js.Exn.raiseError("HyperFuel decoder not implemented")
  }

}

@genType
type chainId = int

type eventBatchQueueItem = {
  timestamp: int,
  chain: ChainMap.Chain.t,
  blockNumber: int,
  logIndex: int,
  event: eventLog<internalEventArgs>,
  eventMod: module(InternalEvent),
  //Default to false, if an event needs to
  //be reprocessed after it has loaded dynamic contracts
  //This gets set to true and does not try and reload events
  hasRegisteredDynamicContracts?: bool,
}
