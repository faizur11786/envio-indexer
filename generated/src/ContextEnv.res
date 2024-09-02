open Types

/**
The context holds all the state for a given events loader and handler.
*/
type t<'eventArgs> = {
  logger: Pino.t,
  chain: ChainMap.Chain.t,
  addedDynamicContractRegistrations: array<TablesStatic.DynamicContractRegistry.t>,
  event: Types.eventLog<'eventArgs>,
}

let getUserLogger = (logger): Logs.userLogger => {
  info: (message: string) => logger->Logging.uinfo(message),
  debug: (message: string) => logger->Logging.udebug(message),
  warn: (message: string) => logger->Logging.uwarn(message),
  error: (message: string) => logger->Logging.uerror(message),
  errorWithExn: (exn: option<Js.Exn.t>, message: string) =>
    logger->Logging.uerrorWithExn(exn, message),
}

let makeEventIdentifier = (event: Types.eventLog<'a>): Types.eventIdentifier => {
  chainId: event.chainId,
  blockTimestamp: event.block.timestamp,
  blockNumber: event.block.number,
  logIndex: event.logIndex,
}

let getEventId = (event: Types.eventLog<'a>) => {
  EventUtils.packEventIndex(~blockNumber=event.block.number, ~logIndex=event.logIndex)
}

let make = (~chain, ~event: Types.eventLog<'eventArgs>, ~eventMod: module(Types.InternalEvent), ~logger) => {
  let {block, logIndex} = event
  let module(Event) = eventMod
  let logger = logger->(
    Logging.createChildFrom(
      ~logger=_,
      ~params={
        "context": `Event '${Event.name}' for contract '${Event.contractName}'`,
        "chainId": chain->ChainMap.Chain.toChainId,
        "block": block.number,
        "logIndex": logIndex,
      },
    )
  )

  {
    event,
    logger,
    chain,
    addedDynamicContractRegistrations: [],
  }
}

let getAddedDynamicContractRegistrations = (contextEnv: t<'eventArgs>) =>
  contextEnv.addedDynamicContractRegistrations

let makeDynamicContractRegisterFn = (~contextEnv: t<'eventArgs>, ~contractName, ~inMemoryStore) => (
  contractAddress: Address.t,
) => {
  // Even though it's the Address.t on ReScript side, for TS side it's a string.
  // So we need to ensure that it's a valid checksummed address.
  let contractAddress = contractAddress->Address.Evm.fromAddressOrThrow

  let {event, chain, addedDynamicContractRegistrations} = contextEnv

  let eventId = event->getEventId
  let chainId = chain->ChainMap.Chain.toChainId
  let dynamicContractRegistration: TablesStatic.DynamicContractRegistry.t = {
    chainId,
    eventId,
    blockTimestamp: event.block.timestamp,
    contractAddress,
    contractType: contractName,
  }

  addedDynamicContractRegistrations->Js.Array2.push(dynamicContractRegistration)->ignore

  inMemoryStore.InMemoryStore.dynamicContractRegistry->InMemoryTable.set(
    {chainId, contractAddress},
    dynamicContractRegistration,
  )
}

let makeWhereLoader = (loadLayer, ~entityMod, ~inMemoryStore, ~fieldName, ~fieldValueSchema, ~logger) => {
  Entities.eq: loadLayer->LoadLayer.makeWhereEqLoader(~entityMod, ~fieldName, ~fieldValueSchema, ~inMemoryStore, ~logger)
}

let makeEntityHandlerContext = (
  type entity,
  ~eventIdentifier,
  ~inMemoryStore,
  ~entityMod: module(Entities.Entity with type t = entity),
  ~logger,
  ~getKey,
  ~loadLayer,
): entityHandlerContext<entity> => {
  let inMemTable = inMemoryStore->InMemoryStore.getInMemTable(~entityMod)
  {
    set: entity => {
      inMemTable->InMemoryTable.Entity.set(
        Set(entity)->Types.mkEntityUpdate(~eventIdentifier, ~entityId=getKey(entity)),
      )
    },
    deleteUnsafe: entityId => {
      inMemTable->InMemoryTable.Entity.set(
        Delete->Types.mkEntityUpdate(~eventIdentifier, ~entityId),
      )
    },
    get: loadLayer->LoadLayer.makeLoader(~entityMod, ~logger, ~inMemoryStore),
  }
}

let getContractRegisterContext = (contextEnv, ~inMemoryStore) => {
  //TODO only add contracts we've registered for the event in the config
  addFactory:  makeDynamicContractRegisterFn(~contextEnv, ~inMemoryStore, ~contractName=Factory),
  addSokosERC721:  makeDynamicContractRegisterFn(~contextEnv, ~inMemoryStore, ~contractName=SokosERC721),
}

let getLoaderContext = (contextEnv: t<'eventArgs>, ~inMemoryStore: InMemoryStore.t, ~loadLayer: LoadLayer.t): loaderContext => {
  let {logger} = contextEnv
  {
    log: logger->getUserLogger,
    account: {
      get: loadLayer->LoadLayer.makeLoader(
        ~entityMod=module(Entities.Account),
        ~inMemoryStore,
        ~logger,
      ),
      getWhere: {
        
      },
    },
    collection: {
      get: loadLayer->LoadLayer.makeLoader(
        ~entityMod=module(Entities.Collection),
        ~inMemoryStore,
        ~logger,
      ),
      getWhere: {
        
      },
    },
    factory_CollectionDeployed: {
      get: loadLayer->LoadLayer.makeLoader(
        ~entityMod=module(Entities.Factory_CollectionDeployed),
        ~inMemoryStore,
        ~logger,
      ),
      getWhere: {
        
      },
    },
    nft: {
      get: loadLayer->LoadLayer.makeLoader(
        ~entityMod=module(Entities.Nft),
        ~inMemoryStore,
        ~logger,
      ),
      getWhere: {
        
        collection_id: loadLayer->makeWhereLoader(
          ~entityMod=module(Entities.Nft),
          ~inMemoryStore,
          ~fieldName="collection_id",
          ~fieldValueSchema=S.string,
          ~logger,
        ),
      
        owner_id: loadLayer->makeWhereLoader(
          ~entityMod=module(Entities.Nft),
          ~inMemoryStore,
          ~fieldName="owner_id",
          ~fieldValueSchema=S.string,
          ~logger,
        ),
      
      },
    },
    sokosERC721_Transfer: {
      get: loadLayer->LoadLayer.makeLoader(
        ~entityMod=module(Entities.SokosERC721_Transfer),
        ~inMemoryStore,
        ~logger,
      ),
      getWhere: {
        
      },
    },
  }
}

let getHandlerContext = (context, ~inMemoryStore: InMemoryStore.t, ~loadLayer) => {
  let {event, logger} = context

  let eventIdentifier = event->makeEventIdentifier
  {
    log: logger->getUserLogger,
    account: makeEntityHandlerContext(
      ~eventIdentifier,
      ~inMemoryStore,
      ~entityMod=module(Entities.Account),
      ~getKey=entity => entity.id,
      ~logger,
      ~loadLayer,
    ),
    collection: makeEntityHandlerContext(
      ~eventIdentifier,
      ~inMemoryStore,
      ~entityMod=module(Entities.Collection),
      ~getKey=entity => entity.id,
      ~logger,
      ~loadLayer,
    ),
    factory_CollectionDeployed: makeEntityHandlerContext(
      ~eventIdentifier,
      ~inMemoryStore,
      ~entityMod=module(Entities.Factory_CollectionDeployed),
      ~getKey=entity => entity.id,
      ~logger,
      ~loadLayer,
    ),
    nft: makeEntityHandlerContext(
      ~eventIdentifier,
      ~inMemoryStore,
      ~entityMod=module(Entities.Nft),
      ~getKey=entity => entity.id,
      ~logger,
      ~loadLayer,
    ),
    sokosERC721_Transfer: makeEntityHandlerContext(
      ~eventIdentifier,
      ~inMemoryStore,
      ~entityMod=module(Entities.SokosERC721_Transfer),
      ~getKey=entity => entity.id,
      ~logger,
      ~loadLayer,
    ),
  }
}

let getContractRegisterArgs = (contextEnv, ~inMemoryStore) => {
  RegisteredEvents.event: contextEnv.event,
  context: contextEnv->getContractRegisterContext(~inMemoryStore),
}

let getLoaderArgs = (contextEnv, ~inMemoryStore, ~loadLayer) => {
  RegisteredEvents.event: contextEnv.event,
  context: contextEnv->getLoaderContext(~inMemoryStore, ~loadLayer),
}

let getHandlerArgs = (contextEnv, ~inMemoryStore, ~loaderReturn, ~loadLayer) => {
  RegisteredEvents.event: contextEnv.event,
  context: contextEnv->getHandlerContext(~inMemoryStore, ~loadLayer),
  loaderReturn,
}
