//*************
//***ENTITIES**
//*************
@genType.as("Id")
type id = string

@@warning("-30")
@genType
type rec accountLoaderConfig = bool
and collectionLoaderConfig = {loadOwner?: accountLoaderConfig}
and factory_CollectionDeployedLoaderConfig = bool
and nftLoaderConfig = {loadCollection?: collectionLoaderConfig, loadOwner?: accountLoaderConfig}
and sokosERC721_TransferLoaderConfig = bool
@@warning("+30")

@genType
type entityRead =
  | AccountRead(id)
  | CollectionRead(id, collectionLoaderConfig)
  | Factory_CollectionDeployedRead(id)
  | NftRead(id, nftLoaderConfig)
  | SokosERC721_TransferRead(id)

@genType
type rawEventsEntity = {
  @as("chain_id") chainId: int,
  @as("event_id") eventId: string,
  @as("block_number") blockNumber: int,
  @as("log_index") logIndex: int,
  @as("transaction_index") transactionIndex: int,
  @as("transaction_hash") transactionHash: string,
  @as("src_address") srcAddress: Ethers.ethAddress,
  @as("block_hash") blockHash: string,
  @as("block_timestamp") blockTimestamp: int,
  @as("event_type") eventType: Js.Json.t,
  params: string,
}

@genType
type dynamicContractRegistryEntity = {
  @as("chain_id") chainId: int,
  @as("event_id") eventId: Ethers.BigInt.t,
  @as("block_timestamp") blockTimestamp: int,
  @as("contract_address") contractAddress: Ethers.ethAddress,
  @as("contract_type") contractType: string,
}

//Re-exporting types for backwards compatability
@genType.as("AccountEntity")
type accountEntity = Entities.Account.t
@genType.as("CollectionEntity")
type collectionEntity = Entities.Collection.t
@genType.as("Factory_CollectionDeployedEntity")
type factory_CollectionDeployedEntity = Entities.Factory_CollectionDeployed.t
@genType.as("NftEntity")
type nftEntity = Entities.Nft.t
@genType.as("SokosERC721_TransferEntity")
type sokosERC721_TransferEntity = Entities.SokosERC721_Transfer.t

type eventIdentifier = {
  chainId: int,
  blockTimestamp: int,
  blockNumber: int,
  logIndex: int,
}

type entityUpdateAction<'entityType> =
  | Set('entityType)
  | Delete(string)

type entityUpdate<'entityType> = {
  eventIdentifier: eventIdentifier,
  shouldSaveHistory: bool,
  entityUpdateAction: entityUpdateAction<'entityType>,
}

let mkEntityUpdate = (~shouldSaveHistory=true, ~eventIdentifier, entityUpdateAction) => {
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

@genType
type inMemoryStoreRowMeta<'a> = 'a

//*************
//**CONTRACTS**
//*************

@genType.as("EventLog")
type eventLog<'a> = {
  params: 'a,
  chainId: int,
  txOrigin: option<Ethers.ethAddress>,
  txTo: option<Ethers.ethAddress>,
  blockNumber: int,
  blockTimestamp: int,
  blockHash: string,
  srcAddress: Ethers.ethAddress,
  transactionHash: string,
  transactionIndex: int,
  logIndex: int,
}

module FactoryContract = {
  module CollectionDeployedEvent = {
    //Note: each parameter is using a binding of its index to help with binding in ethers
    //This handles both unamed params and also named params that clash with reserved keywords
    //eg. if an event param is called "values" it will clash since eventArgs will have a '.values()' iterator
    type ethersEventArgs = {
      @as("0") tokenAddress: Ethers.ethAddress,
      @as("1") owner: Ethers.ethAddress,
      @as("2") isERC1155: bool,
      @as("3") name: string,
      @as("4") symbol: string,
      @as("5") uri: string,
    }

    @genType
    type eventArgs = {
      tokenAddress: Ethers.ethAddress,
      owner: Ethers.ethAddress,
      isERC1155: bool,
      name: string,
      symbol: string,
      uri: string,
    }
    let eventArgsSchema = S.object((. s) => {
      tokenAddress: s.field("tokenAddress", Ethers.ethAddressSchema),
      owner: s.field("owner", Ethers.ethAddressSchema),
      isERC1155: s.field("isERC1155", S.bool),
      name: s.field("name", S.string),
      symbol: s.field("symbol", S.string),
      uri: s.field("uri", S.string),
    })

    @genType.as("FactoryContract_CollectionDeployed_EventLog")
    type log = eventLog<eventArgs>

    // Entity: Account
    type accountEntityHandlerContext = {
      get: id => option<Entities.Account.t>,
      set: Entities.Account.t => unit,
      deleteUnsafe: id => unit,
    }

    type accountEntityHandlerContextAsync = {
      get: id => promise<option<Entities.Account.t>>,
      set: Entities.Account.t => unit,
      deleteUnsafe: id => unit,
    }

    // Entity: Collection
    type collectionEntityHandlerContext = {
      get: id => option<Entities.Collection.t>,
      getOwner: Entities.Collection.t => Entities.Account.t,
      set: Entities.Collection.t => unit,
      deleteUnsafe: id => unit,
    }

    type collectionEntityHandlerContextAsync = {
      get: id => promise<option<Entities.Collection.t>>,
      getOwner: Entities.Collection.t => promise<Entities.Account.t>,
      set: Entities.Collection.t => unit,
      deleteUnsafe: id => unit,
    }

    // Entity: Factory_CollectionDeployed
    type factory_CollectionDeployedEntityHandlerContext = {
      get: id => option<Entities.Factory_CollectionDeployed.t>,
      set: Entities.Factory_CollectionDeployed.t => unit,
      deleteUnsafe: id => unit,
    }

    type factory_CollectionDeployedEntityHandlerContextAsync = {
      get: id => promise<option<Entities.Factory_CollectionDeployed.t>>,
      set: Entities.Factory_CollectionDeployed.t => unit,
      deleteUnsafe: id => unit,
    }

    // Entity: Nft
    type nftEntityHandlerContext = {
      get: id => option<Entities.Nft.t>,
      getCollection: Entities.Nft.t => Entities.Collection.t,
      getOwner: Entities.Nft.t => Entities.Account.t,
      set: Entities.Nft.t => unit,
      deleteUnsafe: id => unit,
    }

    type nftEntityHandlerContextAsync = {
      get: id => promise<option<Entities.Nft.t>>,
      getCollection: Entities.Nft.t => promise<Entities.Collection.t>,
      getOwner: Entities.Nft.t => promise<Entities.Account.t>,
      set: Entities.Nft.t => unit,
      deleteUnsafe: id => unit,
    }

    // Entity: SokosERC721_Transfer
    type sokosERC721_TransferEntityHandlerContext = {
      get: id => option<Entities.SokosERC721_Transfer.t>,
      set: Entities.SokosERC721_Transfer.t => unit,
      deleteUnsafe: id => unit,
    }

    type sokosERC721_TransferEntityHandlerContextAsync = {
      get: id => promise<option<Entities.SokosERC721_Transfer.t>>,
      set: Entities.SokosERC721_Transfer.t => unit,
      deleteUnsafe: id => unit,
    }

    @genType
    type handlerContext = {
      log: Logs.userLogger,
      @as("Account") account: accountEntityHandlerContext,
      @as("Collection") collection: collectionEntityHandlerContext,
      @as("Factory_CollectionDeployed")
      factory_CollectionDeployed: factory_CollectionDeployedEntityHandlerContext,
      @as("Nft") nft: nftEntityHandlerContext,
      @as("SokosERC721_Transfer") sokosERC721_Transfer: sokosERC721_TransferEntityHandlerContext,
    }
    @genType
    type handlerContextAsync = {
      log: Logs.userLogger,
      @as("Account") account: accountEntityHandlerContextAsync,
      @as("Collection") collection: collectionEntityHandlerContextAsync,
      @as("Factory_CollectionDeployed")
      factory_CollectionDeployed: factory_CollectionDeployedEntityHandlerContextAsync,
      @as("Nft") nft: nftEntityHandlerContextAsync,
      @as("SokosERC721_Transfer")
      sokosERC721_Transfer: sokosERC721_TransferEntityHandlerContextAsync,
    }

    @genType
    type accountEntityLoaderContext = {load: id => unit}
    @genType
    type collectionEntityLoaderContext = {load: (id, ~loaders: collectionLoaderConfig=?) => unit}
    @genType
    type factory_CollectionDeployedEntityLoaderContext = {load: id => unit}
    @genType
    type nftEntityLoaderContext = {load: (id, ~loaders: nftLoaderConfig=?) => unit}
    @genType
    type sokosERC721_TransferEntityLoaderContext = {load: id => unit}

    @genType
    type contractRegistrations = {
      //TODO only add contracts we've registered for the event in the config
      addFactory: Ethers.ethAddress => unit,
      //TODO only add contracts we've registered for the event in the config
      addSokosERC721: Ethers.ethAddress => unit,
    }
    @genType
    type loaderContext = {
      log: Logs.userLogger,
      contractRegistration: contractRegistrations,
      @as("Account") account: accountEntityLoaderContext,
      @as("Collection") collection: collectionEntityLoaderContext,
      @as("Factory_CollectionDeployed")
      factory_CollectionDeployed: factory_CollectionDeployedEntityLoaderContext,
      @as("Nft") nft: nftEntityLoaderContext,
      @as("SokosERC721_Transfer") sokosERC721_Transfer: sokosERC721_TransferEntityLoaderContext,
    }
  }
}
module SokosERC721Contract = {
  module TransferEvent = {
    //Note: each parameter is using a binding of its index to help with binding in ethers
    //This handles both unamed params and also named params that clash with reserved keywords
    //eg. if an event param is called "values" it will clash since eventArgs will have a '.values()' iterator
    type ethersEventArgs = {
      @as("0") from: Ethers.ethAddress,
      @as("1") to: Ethers.ethAddress,
      @as("2") tokenId: Ethers.BigInt.t,
    }

    @genType
    type eventArgs = {
      from: Ethers.ethAddress,
      to: Ethers.ethAddress,
      tokenId: Ethers.BigInt.t,
    }
    let eventArgsSchema = S.object((. s) => {
      from: s.field("from", Ethers.ethAddressSchema),
      to: s.field("to", Ethers.ethAddressSchema),
      tokenId: s.field("tokenId", Ethers.BigInt.schema),
    })

    @genType.as("SokosERC721Contract_Transfer_EventLog")
    type log = eventLog<eventArgs>

    // Entity: Account
    type accountEntityHandlerContext = {
      get: id => option<Entities.Account.t>,
      set: Entities.Account.t => unit,
      deleteUnsafe: id => unit,
    }

    type accountEntityHandlerContextAsync = {
      get: id => promise<option<Entities.Account.t>>,
      set: Entities.Account.t => unit,
      deleteUnsafe: id => unit,
    }

    // Entity: Collection
    type collectionEntityHandlerContext = {
      get: id => option<Entities.Collection.t>,
      getOwner: Entities.Collection.t => Entities.Account.t,
      set: Entities.Collection.t => unit,
      deleteUnsafe: id => unit,
    }

    type collectionEntityHandlerContextAsync = {
      get: id => promise<option<Entities.Collection.t>>,
      getOwner: Entities.Collection.t => promise<Entities.Account.t>,
      set: Entities.Collection.t => unit,
      deleteUnsafe: id => unit,
    }

    // Entity: Factory_CollectionDeployed
    type factory_CollectionDeployedEntityHandlerContext = {
      get: id => option<Entities.Factory_CollectionDeployed.t>,
      set: Entities.Factory_CollectionDeployed.t => unit,
      deleteUnsafe: id => unit,
    }

    type factory_CollectionDeployedEntityHandlerContextAsync = {
      get: id => promise<option<Entities.Factory_CollectionDeployed.t>>,
      set: Entities.Factory_CollectionDeployed.t => unit,
      deleteUnsafe: id => unit,
    }

    // Entity: Nft
    type nftEntityHandlerContext = {
      get: id => option<Entities.Nft.t>,
      getCollection: Entities.Nft.t => Entities.Collection.t,
      getOwner: Entities.Nft.t => Entities.Account.t,
      set: Entities.Nft.t => unit,
      deleteUnsafe: id => unit,
    }

    type nftEntityHandlerContextAsync = {
      get: id => promise<option<Entities.Nft.t>>,
      getCollection: Entities.Nft.t => promise<Entities.Collection.t>,
      getOwner: Entities.Nft.t => promise<Entities.Account.t>,
      set: Entities.Nft.t => unit,
      deleteUnsafe: id => unit,
    }

    // Entity: SokosERC721_Transfer
    type sokosERC721_TransferEntityHandlerContext = {
      get: id => option<Entities.SokosERC721_Transfer.t>,
      set: Entities.SokosERC721_Transfer.t => unit,
      deleteUnsafe: id => unit,
    }

    type sokosERC721_TransferEntityHandlerContextAsync = {
      get: id => promise<option<Entities.SokosERC721_Transfer.t>>,
      set: Entities.SokosERC721_Transfer.t => unit,
      deleteUnsafe: id => unit,
    }

    @genType
    type handlerContext = {
      log: Logs.userLogger,
      @as("Account") account: accountEntityHandlerContext,
      @as("Collection") collection: collectionEntityHandlerContext,
      @as("Factory_CollectionDeployed")
      factory_CollectionDeployed: factory_CollectionDeployedEntityHandlerContext,
      @as("Nft") nft: nftEntityHandlerContext,
      @as("SokosERC721_Transfer") sokosERC721_Transfer: sokosERC721_TransferEntityHandlerContext,
    }
    @genType
    type handlerContextAsync = {
      log: Logs.userLogger,
      @as("Account") account: accountEntityHandlerContextAsync,
      @as("Collection") collection: collectionEntityHandlerContextAsync,
      @as("Factory_CollectionDeployed")
      factory_CollectionDeployed: factory_CollectionDeployedEntityHandlerContextAsync,
      @as("Nft") nft: nftEntityHandlerContextAsync,
      @as("SokosERC721_Transfer")
      sokosERC721_Transfer: sokosERC721_TransferEntityHandlerContextAsync,
    }

    @genType
    type accountEntityLoaderContext = {load: id => unit}
    @genType
    type collectionEntityLoaderContext = {load: (id, ~loaders: collectionLoaderConfig=?) => unit}
    @genType
    type factory_CollectionDeployedEntityLoaderContext = {load: id => unit}
    @genType
    type nftEntityLoaderContext = {load: (id, ~loaders: nftLoaderConfig=?) => unit}
    @genType
    type sokosERC721_TransferEntityLoaderContext = {load: id => unit}

    @genType
    type contractRegistrations = {
      //TODO only add contracts we've registered for the event in the config
      addFactory: Ethers.ethAddress => unit,
      //TODO only add contracts we've registered for the event in the config
      addSokosERC721: Ethers.ethAddress => unit,
    }
    @genType
    type loaderContext = {
      log: Logs.userLogger,
      contractRegistration: contractRegistrations,
      @as("Account") account: accountEntityLoaderContext,
      @as("Collection") collection: collectionEntityLoaderContext,
      @as("Factory_CollectionDeployed")
      factory_CollectionDeployed: factory_CollectionDeployedEntityLoaderContext,
      @as("Nft") nft: nftEntityLoaderContext,
      @as("SokosERC721_Transfer") sokosERC721_Transfer: sokosERC721_TransferEntityLoaderContext,
    }
  }
}

type event =
  | FactoryContract_CollectionDeployed(eventLog<FactoryContract.CollectionDeployedEvent.eventArgs>)
  | SokosERC721Contract_Transfer(eventLog<SokosERC721Contract.TransferEvent.eventArgs>)

type eventName =
  | @as("Factory_CollectionDeployed") Factory_CollectionDeployed
  | @as("SokosERC721_Transfer") SokosERC721_Transfer
// true
let eventNameSchema = S.union([
  S.literal(Factory_CollectionDeployed),
  S.literal(SokosERC721_Transfer),
])

let eventNameToString = (eventName: eventName) =>
  switch eventName {
  | Factory_CollectionDeployed => "CollectionDeployed"
  | SokosERC721_Transfer => "Transfer"
  }

exception UnknownEvent(string, string)
let eventTopicToEventName = (contractName, topic0) =>
  switch (contractName, topic0) {
  | ("Factory", "0xd92929f2fc968c1e7209cebe8cc0a6804a8dea358496b35f07a20e1af21e4e88") =>
    Factory_CollectionDeployed
  | ("SokosERC721", "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef") =>
    SokosERC721_Transfer
  | (contractName, topic0) => UnknownEvent(contractName, topic0)->raise
  }

@genType
type chainId = int

type eventBatchQueueItem = {
  timestamp: int,
  chain: ChainMap.Chain.t,
  blockNumber: int,
  logIndex: int,
  event: event,
  //Default to false, if an event needs to
  //be reprocessed after it has loaded dynamic contracts
  //This gets set to true and does not try and reload events
  hasRegisteredDynamicContracts?: bool,
}
