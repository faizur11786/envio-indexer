type entityGetters = {
  getAccount: Types.id => promise<array<Entities.Account.t>>,
  getCollection: Types.id => promise<array<Entities.Collection.t>>,
  getFactory_CollectionDeployed: Types.id => promise<array<Entities.Factory_CollectionDeployed.t>>,
  getNft: Types.id => promise<array<Entities.Nft.t>>,
  getSokosERC721_Transfer: Types.id => promise<array<Entities.SokosERC721_Transfer.t>>,
}

@genType
type genericContextCreatorFunctions<'loaderContext, 'handlerContextSync, 'handlerContextAsync> = {
  logger: Pino.t,
  log: Logs.userLogger,
  getLoaderContext: unit => 'loaderContext,
  getHandlerContextSync: unit => 'handlerContextSync,
  getHandlerContextAsync: unit => 'handlerContextAsync,
  getEntitiesToLoad: unit => array<Types.entityRead>,
  getAddedDynamicContractRegistrations: unit => array<Types.dynamicContractRegistryEntity>,
}

type contextCreator<'eventArgs, 'loaderContext, 'handlerContext, 'handlerContextAsync> = (
  ~inMemoryStore: IO.InMemoryStore.t,
  ~chainId: int,
  ~event: Types.eventLog<'eventArgs>,
  ~logger: Pino.t,
  ~asyncGetters: entityGetters,
) => genericContextCreatorFunctions<'loaderContext, 'handlerContext, 'handlerContextAsync>

let getEventIdentifier = (event: Types.eventLog<'a>, ~chainId): Types.eventIdentifier => {
  chainId,
  blockTimestamp: event.blockTimestamp,
  blockNumber: event.blockNumber,
  logIndex: event.logIndex,
}

exception UnableToLoadNonNullableLinkedEntity(string)
exception LinkedEntityNotAvailableInSyncHandler(string)

module FactoryContract = {
  module CollectionDeployedEvent = {
    type loaderContext = Types.FactoryContract.CollectionDeployedEvent.loaderContext
    type handlerContext = Types.FactoryContract.CollectionDeployedEvent.handlerContext
    type handlerContextAsync = Types.FactoryContract.CollectionDeployedEvent.handlerContextAsync
    type context = genericContextCreatorFunctions<
      loaderContext,
      handlerContext,
      handlerContextAsync,
    >

    let contextCreator: contextCreator<
      Types.FactoryContract.CollectionDeployedEvent.eventArgs,
      loaderContext,
      handlerContext,
      handlerContextAsync,
    > = (~inMemoryStore, ~chainId, ~event, ~logger, ~asyncGetters) => {
      let eventIdentifier = event->getEventIdentifier(~chainId)
      // NOTE: we could optimise this code to onle create a logger if there was a log called.
      let logger = logger->Logging.createChildFrom(
        ~logger=_,
        ~params={
          "context": "Factory.CollectionDeployed",
          "chainId": chainId,
          "block": event.blockNumber,
          "logIndex": event.logIndex,
          "txHash": event.transactionHash,
        },
      )

      let contextLogger: Logs.userLogger = {
        info: (message: string) => logger->Logging.uinfo(message),
        debug: (message: string) => logger->Logging.udebug(message),
        warn: (message: string) => logger->Logging.uwarn(message),
        error: (message: string) => logger->Logging.uerror(message),
        errorWithExn: (exn: option<Js.Exn.t>, message: string) =>
          logger->Logging.uerrorWithExn(exn, message),
      }

      let optSetOfIds_account: Set.t<Types.id> = Set.make()
      let optSetOfIds_collection: Set.t<Types.id> = Set.make()
      let optSetOfIds_factory_CollectionDeployed: Set.t<Types.id> = Set.make()
      let optSetOfIds_nft: Set.t<Types.id> = Set.make()
      let optSetOfIds_sokosERC721_Transfer: Set.t<Types.id> = Set.make()

      let entitiesToLoad: array<Types.entityRead> = []

      let addedDynamicContractRegistrations: array<Types.dynamicContractRegistryEntity> = []

      //Loader context can be defined as a value and the getter can return that value

      @warning("-16")
      let loaderContext: loaderContext = {
        log: contextLogger,
        contractRegistration: {
          //TODO only add contracts we've registered for the event in the config
          addFactory: (contractAddress: Ethers.ethAddress) => {
            let eventId = EventUtils.packEventIndex(
              ~blockNumber=event.blockNumber,
              ~logIndex=event.logIndex,
            )
            let dynamicContractRegistration: Types.dynamicContractRegistryEntity = {
              chainId,
              eventId,
              blockTimestamp: event.blockTimestamp,
              contractAddress,
              contractType: "Factory",
            }

            addedDynamicContractRegistrations->Js.Array2.push(dynamicContractRegistration)->ignore

            inMemoryStore.dynamicContractRegistry->IO.InMemoryStore.DynamicContractRegistry.set(
              ~key={chainId, contractAddress},
              ~entity=dynamicContractRegistration,
            )
          },
          //TODO only add contracts we've registered for the event in the config
          addSokosERC721: (contractAddress: Ethers.ethAddress) => {
            let eventId = EventUtils.packEventIndex(
              ~blockNumber=event.blockNumber,
              ~logIndex=event.logIndex,
            )
            let dynamicContractRegistration: Types.dynamicContractRegistryEntity = {
              chainId,
              eventId,
              blockTimestamp: event.blockTimestamp,
              contractAddress,
              contractType: "SokosERC721",
            }

            addedDynamicContractRegistrations->Js.Array2.push(dynamicContractRegistration)->ignore

            inMemoryStore.dynamicContractRegistry->IO.InMemoryStore.DynamicContractRegistry.set(
              ~key={chainId, contractAddress},
              ~entity=dynamicContractRegistration,
            )
          },
        },
        account: {
          load: (id: Types.id) => {
            let _ = optSetOfIds_account->Set.add(id)
            let _ = Js.Array2.push(entitiesToLoad, Types.AccountRead(id))
          },
        },
        collection: {
          load: (id: Types.id, ~loaders={}) => {
            let _ = optSetOfIds_collection->Set.add(id)
            let _ = Js.Array2.push(entitiesToLoad, Types.CollectionRead(id, loaders))
          },
        },
        factory_CollectionDeployed: {
          load: (id: Types.id) => {
            let _ = optSetOfIds_factory_CollectionDeployed->Set.add(id)
            let _ = Js.Array2.push(entitiesToLoad, Types.Factory_CollectionDeployedRead(id))
          },
        },
        nft: {
          load: (id: Types.id, ~loaders={}) => {
            let _ = optSetOfIds_nft->Set.add(id)
            let _ = Js.Array2.push(entitiesToLoad, Types.NftRead(id, loaders))
          },
        },
        sokosERC721_Transfer: {
          load: (id: Types.id) => {
            let _ = optSetOfIds_sokosERC721_Transfer->Set.add(id)
            let _ = Js.Array2.push(entitiesToLoad, Types.SokosERC721_TransferRead(id))
          },
        },
      }

      //handler context must be defined as a getter function so that it can construct the context
      //without stale values whenever it is used
      let getHandlerContextSync: unit => handlerContext = () => {
        {
          log: contextLogger,
          account: {
            set: entity => {
              inMemoryStore.account->IO.InMemoryStore.Account.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.account->IO.InMemoryStore.Account.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: (id: Types.id) => {
              if optSetOfIds_account->Set.has(id) {
                inMemoryStore.account->IO.InMemoryStore.Account.get(id)
              } else {
                Logging.warn(
                  `The loader for a "Account" of entity with id "${id}" was not used please add it to your default loader function (ie. place 'context.account.load("${id}")' inside your loader) to avoid unexpected behaviour. This is a runtime validation check.`,
                )

                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                inMemoryStore.account->IO.InMemoryStore.Account.get(id)

                // TODO: add a further step to synchronously try fetch this from the DB if it isn't in the in-memory store - similar to this PR: https://github.com/Float-Capital/indexer/pull/759
              }
            },
          },
          collection: {
            set: entity => {
              inMemoryStore.collection->IO.InMemoryStore.Collection.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.collection->IO.InMemoryStore.Collection.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: (id: Types.id) => {
              if optSetOfIds_collection->Set.has(id) {
                inMemoryStore.collection->IO.InMemoryStore.Collection.get(id)
              } else {
                Logging.warn(
                  `The loader for a "Collection" of entity with id "${id}" was not used please add it to your default loader function (ie. place 'context.collection.load("${id}")' inside your loader) to avoid unexpected behaviour. This is a runtime validation check.`,
                )

                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                inMemoryStore.collection->IO.InMemoryStore.Collection.get(id)

                // TODO: add a further step to synchronously try fetch this from the DB if it isn't in the in-memory store - similar to this PR: https://github.com/Float-Capital/indexer/pull/759
              }
            },
            getOwner: collection => {
              let optOwner =
                inMemoryStore.account->IO.InMemoryStore.Account.get(collection.owner_id)
              switch optOwner {
              | Some(owner) => owner
              | None =>
                Logging.error(
                  `Linked entity field 'owner' not found  for 'Collection' entity.
Please ensure this field 'owner' is loaded in the 'Collection' entity loader for this entity with id ${collection.id}.

It is also possible that you have saved an ID for an entity that doesn't exist in the code. Please validate in the Database that an entity of type 'Account' with ID ${collection.owner_id} exists. If it doesn't you need to examine the code that is meant to create and save that entity initially.`,
                )

                raise(
                  LinkedEntityNotAvailableInSyncHandler(
                    "The required linked entity owner was not defined in the loader for entity Collection",
                  ),
                )
              }
            },
          },
          factory_CollectionDeployed: {
            set: entity => {
              inMemoryStore.factory_CollectionDeployed->IO.InMemoryStore.Factory_CollectionDeployed.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.factory_CollectionDeployed->IO.InMemoryStore.Factory_CollectionDeployed.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: (id: Types.id) => {
              if optSetOfIds_factory_CollectionDeployed->Set.has(id) {
                inMemoryStore.factory_CollectionDeployed->IO.InMemoryStore.Factory_CollectionDeployed.get(
                  id,
                )
              } else {
                Logging.warn(
                  `The loader for a "Factory_CollectionDeployed" of entity with id "${id}" was not used please add it to your default loader function (ie. place 'context.factory_CollectionDeployed.load("${id}")' inside your loader) to avoid unexpected behaviour. This is a runtime validation check.`,
                )

                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                inMemoryStore.factory_CollectionDeployed->IO.InMemoryStore.Factory_CollectionDeployed.get(
                  id,
                )

                // TODO: add a further step to synchronously try fetch this from the DB if it isn't in the in-memory store - similar to this PR: https://github.com/Float-Capital/indexer/pull/759
              }
            },
          },
          nft: {
            set: entity => {
              inMemoryStore.nft->IO.InMemoryStore.Nft.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.nft->IO.InMemoryStore.Nft.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: (id: Types.id) => {
              if optSetOfIds_nft->Set.has(id) {
                inMemoryStore.nft->IO.InMemoryStore.Nft.get(id)
              } else {
                Logging.warn(
                  `The loader for a "Nft" of entity with id "${id}" was not used please add it to your default loader function (ie. place 'context.nft.load("${id}")' inside your loader) to avoid unexpected behaviour. This is a runtime validation check.`,
                )

                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                inMemoryStore.nft->IO.InMemoryStore.Nft.get(id)

                // TODO: add a further step to synchronously try fetch this from the DB if it isn't in the in-memory store - similar to this PR: https://github.com/Float-Capital/indexer/pull/759
              }
            },
            getCollection: nft => {
              let optCollection =
                inMemoryStore.collection->IO.InMemoryStore.Collection.get(nft.collection_id)
              switch optCollection {
              | Some(collection) => collection
              | None =>
                Logging.error(
                  `Linked entity field 'collection' not found  for 'Nft' entity.
Please ensure this field 'collection' is loaded in the 'Nft' entity loader for this entity with id ${nft.id}.

It is also possible that you have saved an ID for an entity that doesn't exist in the code. Please validate in the Database that an entity of type 'Collection' with ID ${nft.collection_id} exists. If it doesn't you need to examine the code that is meant to create and save that entity initially.`,
                )

                raise(
                  LinkedEntityNotAvailableInSyncHandler(
                    "The required linked entity collection was not defined in the loader for entity Nft",
                  ),
                )
              }
            },
            getOwner: nft => {
              let optOwner = inMemoryStore.account->IO.InMemoryStore.Account.get(nft.owner_id)
              switch optOwner {
              | Some(owner) => owner
              | None =>
                Logging.error(
                  `Linked entity field 'owner' not found  for 'Nft' entity.
Please ensure this field 'owner' is loaded in the 'Nft' entity loader for this entity with id ${nft.id}.

It is also possible that you have saved an ID for an entity that doesn't exist in the code. Please validate in the Database that an entity of type 'Account' with ID ${nft.owner_id} exists. If it doesn't you need to examine the code that is meant to create and save that entity initially.`,
                )

                raise(
                  LinkedEntityNotAvailableInSyncHandler(
                    "The required linked entity owner was not defined in the loader for entity Nft",
                  ),
                )
              }
            },
          },
          sokosERC721_Transfer: {
            set: entity => {
              inMemoryStore.sokosERC721_Transfer->IO.InMemoryStore.SokosERC721_Transfer.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.sokosERC721_Transfer->IO.InMemoryStore.SokosERC721_Transfer.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: (id: Types.id) => {
              if optSetOfIds_sokosERC721_Transfer->Set.has(id) {
                inMemoryStore.sokosERC721_Transfer->IO.InMemoryStore.SokosERC721_Transfer.get(id)
              } else {
                Logging.warn(
                  `The loader for a "SokosERC721_Transfer" of entity with id "${id}" was not used please add it to your default loader function (ie. place 'context.sokosERC721_Transfer.load("${id}")' inside your loader) to avoid unexpected behaviour. This is a runtime validation check.`,
                )

                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                inMemoryStore.sokosERC721_Transfer->IO.InMemoryStore.SokosERC721_Transfer.get(id)

                // TODO: add a further step to synchronously try fetch this from the DB if it isn't in the in-memory store - similar to this PR: https://github.com/Float-Capital/indexer/pull/759
              }
            },
          },
        }
      }

      let getHandlerContextAsync = (): handlerContextAsync => {
        {
          log: contextLogger,
          account: {
            set: entity => {
              inMemoryStore.account->IO.InMemoryStore.Account.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.account->IO.InMemoryStore.Account.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: async (id: Types.id) => {
              if optSetOfIds_account->Set.has(id) {
                inMemoryStore.account->IO.InMemoryStore.Account.get(id)
              } else {
                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                switch inMemoryStore.account->IO.InMemoryStore.Account.get(id) {
                | Some(entity) => Some(entity)
                | None =>
                  let entities = await asyncGetters.getAccount(id)

                  let optEntity = entities->Belt.Array.get(0)

                  IO.InMemoryStore.Account.initValue(
                    inMemoryStore.account,
                    ~key=id,
                    ~entity=optEntity,
                  )

                  optEntity
                }
              }
            },
          },
          collection: {
            set: entity => {
              inMemoryStore.collection->IO.InMemoryStore.Collection.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.collection->IO.InMemoryStore.Collection.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: async (id: Types.id) => {
              if optSetOfIds_collection->Set.has(id) {
                inMemoryStore.collection->IO.InMemoryStore.Collection.get(id)
              } else {
                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                switch inMemoryStore.collection->IO.InMemoryStore.Collection.get(id) {
                | Some(entity) => Some(entity)
                | None =>
                  let entities = await asyncGetters.getCollection(id)

                  let optEntity = entities->Belt.Array.get(0)

                  IO.InMemoryStore.Collection.initValue(
                    inMemoryStore.collection,
                    ~key=id,
                    ~entity=optEntity,
                  )

                  optEntity
                }
              }
            },
            getOwner: async collection => {
              let owner_field = collection.owner_id
              let optOwner = inMemoryStore.account->IO.InMemoryStore.Account.get(owner_field)
              switch optOwner {
              | Some(owner) => owner
              | None =>
                let entities = await asyncGetters.getAccount(owner_field)

                switch entities->Belt.Array.get(0) {
                | Some(entity) =>
                  // TODO: make this work with the test framework too.
                  IO.InMemoryStore.Account.initValue(
                    inMemoryStore.account,
                    ~key=entity.id,
                    ~entity=Some(entity),
                  )
                  entity
                | None =>
                  Logging.error(`Collection owner data not found. Loading associated account from database.
This is likely due to a database corruption. Please reach out to the team on discord.
`)

                  raise(
                    UnableToLoadNonNullableLinkedEntity(
                      "The required linked entity owner of Collection is undefined.",
                    ),
                  )
                }
              }
            },
          },
          factory_CollectionDeployed: {
            set: entity => {
              inMemoryStore.factory_CollectionDeployed->IO.InMemoryStore.Factory_CollectionDeployed.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.factory_CollectionDeployed->IO.InMemoryStore.Factory_CollectionDeployed.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: async (id: Types.id) => {
              if optSetOfIds_factory_CollectionDeployed->Set.has(id) {
                inMemoryStore.factory_CollectionDeployed->IO.InMemoryStore.Factory_CollectionDeployed.get(
                  id,
                )
              } else {
                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                switch inMemoryStore.factory_CollectionDeployed->IO.InMemoryStore.Factory_CollectionDeployed.get(
                  id,
                ) {
                | Some(entity) => Some(entity)
                | None =>
                  let entities = await asyncGetters.getFactory_CollectionDeployed(id)

                  let optEntity = entities->Belt.Array.get(0)

                  IO.InMemoryStore.Factory_CollectionDeployed.initValue(
                    inMemoryStore.factory_CollectionDeployed,
                    ~key=id,
                    ~entity=optEntity,
                  )

                  optEntity
                }
              }
            },
          },
          nft: {
            set: entity => {
              inMemoryStore.nft->IO.InMemoryStore.Nft.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.nft->IO.InMemoryStore.Nft.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: async (id: Types.id) => {
              if optSetOfIds_nft->Set.has(id) {
                inMemoryStore.nft->IO.InMemoryStore.Nft.get(id)
              } else {
                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                switch inMemoryStore.nft->IO.InMemoryStore.Nft.get(id) {
                | Some(entity) => Some(entity)
                | None =>
                  let entities = await asyncGetters.getNft(id)

                  let optEntity = entities->Belt.Array.get(0)

                  IO.InMemoryStore.Nft.initValue(inMemoryStore.nft, ~key=id, ~entity=optEntity)

                  optEntity
                }
              }
            },
            getCollection: async nft => {
              let collection_field = nft.collection_id
              let optCollection =
                inMemoryStore.collection->IO.InMemoryStore.Collection.get(collection_field)
              switch optCollection {
              | Some(collection) => collection
              | None =>
                let entities = await asyncGetters.getCollection(collection_field)

                switch entities->Belt.Array.get(0) {
                | Some(entity) =>
                  // TODO: make this work with the test framework too.
                  IO.InMemoryStore.Collection.initValue(
                    inMemoryStore.collection,
                    ~key=entity.id,
                    ~entity=Some(entity),
                  )
                  entity
                | None =>
                  Logging.error(`Nft collection data not found. Loading associated collection from database.
This is likely due to a database corruption. Please reach out to the team on discord.
`)

                  raise(
                    UnableToLoadNonNullableLinkedEntity(
                      "The required linked entity collection of Nft is undefined.",
                    ),
                  )
                }
              }
            },
            getOwner: async nft => {
              let owner_field = nft.owner_id
              let optOwner = inMemoryStore.account->IO.InMemoryStore.Account.get(owner_field)
              switch optOwner {
              | Some(owner) => owner
              | None =>
                let entities = await asyncGetters.getAccount(owner_field)

                switch entities->Belt.Array.get(0) {
                | Some(entity) =>
                  // TODO: make this work with the test framework too.
                  IO.InMemoryStore.Account.initValue(
                    inMemoryStore.account,
                    ~key=entity.id,
                    ~entity=Some(entity),
                  )
                  entity
                | None =>
                  Logging.error(`Nft owner data not found. Loading associated account from database.
This is likely due to a database corruption. Please reach out to the team on discord.
`)

                  raise(
                    UnableToLoadNonNullableLinkedEntity(
                      "The required linked entity owner of Nft is undefined.",
                    ),
                  )
                }
              }
            },
          },
          sokosERC721_Transfer: {
            set: entity => {
              inMemoryStore.sokosERC721_Transfer->IO.InMemoryStore.SokosERC721_Transfer.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.sokosERC721_Transfer->IO.InMemoryStore.SokosERC721_Transfer.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: async (id: Types.id) => {
              if optSetOfIds_sokosERC721_Transfer->Set.has(id) {
                inMemoryStore.sokosERC721_Transfer->IO.InMemoryStore.SokosERC721_Transfer.get(id)
              } else {
                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                switch inMemoryStore.sokosERC721_Transfer->IO.InMemoryStore.SokosERC721_Transfer.get(
                  id,
                ) {
                | Some(entity) => Some(entity)
                | None =>
                  let entities = await asyncGetters.getSokosERC721_Transfer(id)

                  let optEntity = entities->Belt.Array.get(0)

                  IO.InMemoryStore.SokosERC721_Transfer.initValue(
                    inMemoryStore.sokosERC721_Transfer,
                    ~key=id,
                    ~entity=optEntity,
                  )

                  optEntity
                }
              }
            },
          },
        }
      }

      {
        logger,
        log: contextLogger,
        getEntitiesToLoad: () => entitiesToLoad,
        getAddedDynamicContractRegistrations: () => addedDynamicContractRegistrations,
        getLoaderContext: () => loaderContext,
        getHandlerContextSync,
        getHandlerContextAsync,
      }
    }
  }
}

module SokosERC721Contract = {
  module TransferEvent = {
    type loaderContext = Types.SokosERC721Contract.TransferEvent.loaderContext
    type handlerContext = Types.SokosERC721Contract.TransferEvent.handlerContext
    type handlerContextAsync = Types.SokosERC721Contract.TransferEvent.handlerContextAsync
    type context = genericContextCreatorFunctions<
      loaderContext,
      handlerContext,
      handlerContextAsync,
    >

    let contextCreator: contextCreator<
      Types.SokosERC721Contract.TransferEvent.eventArgs,
      loaderContext,
      handlerContext,
      handlerContextAsync,
    > = (~inMemoryStore, ~chainId, ~event, ~logger, ~asyncGetters) => {
      let eventIdentifier = event->getEventIdentifier(~chainId)
      // NOTE: we could optimise this code to onle create a logger if there was a log called.
      let logger = logger->Logging.createChildFrom(
        ~logger=_,
        ~params={
          "context": "SokosERC721.Transfer",
          "chainId": chainId,
          "block": event.blockNumber,
          "logIndex": event.logIndex,
          "txHash": event.transactionHash,
        },
      )

      let contextLogger: Logs.userLogger = {
        info: (message: string) => logger->Logging.uinfo(message),
        debug: (message: string) => logger->Logging.udebug(message),
        warn: (message: string) => logger->Logging.uwarn(message),
        error: (message: string) => logger->Logging.uerror(message),
        errorWithExn: (exn: option<Js.Exn.t>, message: string) =>
          logger->Logging.uerrorWithExn(exn, message),
      }

      let optSetOfIds_account: Set.t<Types.id> = Set.make()
      let optSetOfIds_collection: Set.t<Types.id> = Set.make()
      let optSetOfIds_factory_CollectionDeployed: Set.t<Types.id> = Set.make()
      let optSetOfIds_nft: Set.t<Types.id> = Set.make()
      let optSetOfIds_sokosERC721_Transfer: Set.t<Types.id> = Set.make()

      let entitiesToLoad: array<Types.entityRead> = []

      let addedDynamicContractRegistrations: array<Types.dynamicContractRegistryEntity> = []

      //Loader context can be defined as a value and the getter can return that value

      @warning("-16")
      let loaderContext: loaderContext = {
        log: contextLogger,
        contractRegistration: {
          //TODO only add contracts we've registered for the event in the config
          addFactory: (contractAddress: Ethers.ethAddress) => {
            let eventId = EventUtils.packEventIndex(
              ~blockNumber=event.blockNumber,
              ~logIndex=event.logIndex,
            )
            let dynamicContractRegistration: Types.dynamicContractRegistryEntity = {
              chainId,
              eventId,
              blockTimestamp: event.blockTimestamp,
              contractAddress,
              contractType: "Factory",
            }

            addedDynamicContractRegistrations->Js.Array2.push(dynamicContractRegistration)->ignore

            inMemoryStore.dynamicContractRegistry->IO.InMemoryStore.DynamicContractRegistry.set(
              ~key={chainId, contractAddress},
              ~entity=dynamicContractRegistration,
            )
          },
          //TODO only add contracts we've registered for the event in the config
          addSokosERC721: (contractAddress: Ethers.ethAddress) => {
            let eventId = EventUtils.packEventIndex(
              ~blockNumber=event.blockNumber,
              ~logIndex=event.logIndex,
            )
            let dynamicContractRegistration: Types.dynamicContractRegistryEntity = {
              chainId,
              eventId,
              blockTimestamp: event.blockTimestamp,
              contractAddress,
              contractType: "SokosERC721",
            }

            addedDynamicContractRegistrations->Js.Array2.push(dynamicContractRegistration)->ignore

            inMemoryStore.dynamicContractRegistry->IO.InMemoryStore.DynamicContractRegistry.set(
              ~key={chainId, contractAddress},
              ~entity=dynamicContractRegistration,
            )
          },
        },
        account: {
          load: (id: Types.id) => {
            let _ = optSetOfIds_account->Set.add(id)
            let _ = Js.Array2.push(entitiesToLoad, Types.AccountRead(id))
          },
        },
        collection: {
          load: (id: Types.id, ~loaders={}) => {
            let _ = optSetOfIds_collection->Set.add(id)
            let _ = Js.Array2.push(entitiesToLoad, Types.CollectionRead(id, loaders))
          },
        },
        factory_CollectionDeployed: {
          load: (id: Types.id) => {
            let _ = optSetOfIds_factory_CollectionDeployed->Set.add(id)
            let _ = Js.Array2.push(entitiesToLoad, Types.Factory_CollectionDeployedRead(id))
          },
        },
        nft: {
          load: (id: Types.id, ~loaders={}) => {
            let _ = optSetOfIds_nft->Set.add(id)
            let _ = Js.Array2.push(entitiesToLoad, Types.NftRead(id, loaders))
          },
        },
        sokosERC721_Transfer: {
          load: (id: Types.id) => {
            let _ = optSetOfIds_sokosERC721_Transfer->Set.add(id)
            let _ = Js.Array2.push(entitiesToLoad, Types.SokosERC721_TransferRead(id))
          },
        },
      }

      //handler context must be defined as a getter function so that it can construct the context
      //without stale values whenever it is used
      let getHandlerContextSync: unit => handlerContext = () => {
        {
          log: contextLogger,
          account: {
            set: entity => {
              inMemoryStore.account->IO.InMemoryStore.Account.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.account->IO.InMemoryStore.Account.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: (id: Types.id) => {
              if optSetOfIds_account->Set.has(id) {
                inMemoryStore.account->IO.InMemoryStore.Account.get(id)
              } else {
                Logging.warn(
                  `The loader for a "Account" of entity with id "${id}" was not used please add it to your default loader function (ie. place 'context.account.load("${id}")' inside your loader) to avoid unexpected behaviour. This is a runtime validation check.`,
                )

                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                inMemoryStore.account->IO.InMemoryStore.Account.get(id)

                // TODO: add a further step to synchronously try fetch this from the DB if it isn't in the in-memory store - similar to this PR: https://github.com/Float-Capital/indexer/pull/759
              }
            },
          },
          collection: {
            set: entity => {
              inMemoryStore.collection->IO.InMemoryStore.Collection.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.collection->IO.InMemoryStore.Collection.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: (id: Types.id) => {
              if optSetOfIds_collection->Set.has(id) {
                inMemoryStore.collection->IO.InMemoryStore.Collection.get(id)
              } else {
                Logging.warn(
                  `The loader for a "Collection" of entity with id "${id}" was not used please add it to your default loader function (ie. place 'context.collection.load("${id}")' inside your loader) to avoid unexpected behaviour. This is a runtime validation check.`,
                )

                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                inMemoryStore.collection->IO.InMemoryStore.Collection.get(id)

                // TODO: add a further step to synchronously try fetch this from the DB if it isn't in the in-memory store - similar to this PR: https://github.com/Float-Capital/indexer/pull/759
              }
            },
            getOwner: collection => {
              let optOwner =
                inMemoryStore.account->IO.InMemoryStore.Account.get(collection.owner_id)
              switch optOwner {
              | Some(owner) => owner
              | None =>
                Logging.error(
                  `Linked entity field 'owner' not found  for 'Collection' entity.
Please ensure this field 'owner' is loaded in the 'Collection' entity loader for this entity with id ${collection.id}.

It is also possible that you have saved an ID for an entity that doesn't exist in the code. Please validate in the Database that an entity of type 'Account' with ID ${collection.owner_id} exists. If it doesn't you need to examine the code that is meant to create and save that entity initially.`,
                )

                raise(
                  LinkedEntityNotAvailableInSyncHandler(
                    "The required linked entity owner was not defined in the loader for entity Collection",
                  ),
                )
              }
            },
          },
          factory_CollectionDeployed: {
            set: entity => {
              inMemoryStore.factory_CollectionDeployed->IO.InMemoryStore.Factory_CollectionDeployed.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.factory_CollectionDeployed->IO.InMemoryStore.Factory_CollectionDeployed.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: (id: Types.id) => {
              if optSetOfIds_factory_CollectionDeployed->Set.has(id) {
                inMemoryStore.factory_CollectionDeployed->IO.InMemoryStore.Factory_CollectionDeployed.get(
                  id,
                )
              } else {
                Logging.warn(
                  `The loader for a "Factory_CollectionDeployed" of entity with id "${id}" was not used please add it to your default loader function (ie. place 'context.factory_CollectionDeployed.load("${id}")' inside your loader) to avoid unexpected behaviour. This is a runtime validation check.`,
                )

                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                inMemoryStore.factory_CollectionDeployed->IO.InMemoryStore.Factory_CollectionDeployed.get(
                  id,
                )

                // TODO: add a further step to synchronously try fetch this from the DB if it isn't in the in-memory store - similar to this PR: https://github.com/Float-Capital/indexer/pull/759
              }
            },
          },
          nft: {
            set: entity => {
              inMemoryStore.nft->IO.InMemoryStore.Nft.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.nft->IO.InMemoryStore.Nft.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: (id: Types.id) => {
              if optSetOfIds_nft->Set.has(id) {
                inMemoryStore.nft->IO.InMemoryStore.Nft.get(id)
              } else {
                Logging.warn(
                  `The loader for a "Nft" of entity with id "${id}" was not used please add it to your default loader function (ie. place 'context.nft.load("${id}")' inside your loader) to avoid unexpected behaviour. This is a runtime validation check.`,
                )

                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                inMemoryStore.nft->IO.InMemoryStore.Nft.get(id)

                // TODO: add a further step to synchronously try fetch this from the DB if it isn't in the in-memory store - similar to this PR: https://github.com/Float-Capital/indexer/pull/759
              }
            },
            getCollection: nft => {
              let optCollection =
                inMemoryStore.collection->IO.InMemoryStore.Collection.get(nft.collection_id)
              switch optCollection {
              | Some(collection) => collection
              | None =>
                Logging.error(
                  `Linked entity field 'collection' not found  for 'Nft' entity.
Please ensure this field 'collection' is loaded in the 'Nft' entity loader for this entity with id ${nft.id}.

It is also possible that you have saved an ID for an entity that doesn't exist in the code. Please validate in the Database that an entity of type 'Collection' with ID ${nft.collection_id} exists. If it doesn't you need to examine the code that is meant to create and save that entity initially.`,
                )

                raise(
                  LinkedEntityNotAvailableInSyncHandler(
                    "The required linked entity collection was not defined in the loader for entity Nft",
                  ),
                )
              }
            },
            getOwner: nft => {
              let optOwner = inMemoryStore.account->IO.InMemoryStore.Account.get(nft.owner_id)
              switch optOwner {
              | Some(owner) => owner
              | None =>
                Logging.error(
                  `Linked entity field 'owner' not found  for 'Nft' entity.
Please ensure this field 'owner' is loaded in the 'Nft' entity loader for this entity with id ${nft.id}.

It is also possible that you have saved an ID for an entity that doesn't exist in the code. Please validate in the Database that an entity of type 'Account' with ID ${nft.owner_id} exists. If it doesn't you need to examine the code that is meant to create and save that entity initially.`,
                )

                raise(
                  LinkedEntityNotAvailableInSyncHandler(
                    "The required linked entity owner was not defined in the loader for entity Nft",
                  ),
                )
              }
            },
          },
          sokosERC721_Transfer: {
            set: entity => {
              inMemoryStore.sokosERC721_Transfer->IO.InMemoryStore.SokosERC721_Transfer.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.sokosERC721_Transfer->IO.InMemoryStore.SokosERC721_Transfer.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: (id: Types.id) => {
              if optSetOfIds_sokosERC721_Transfer->Set.has(id) {
                inMemoryStore.sokosERC721_Transfer->IO.InMemoryStore.SokosERC721_Transfer.get(id)
              } else {
                Logging.warn(
                  `The loader for a "SokosERC721_Transfer" of entity with id "${id}" was not used please add it to your default loader function (ie. place 'context.sokosERC721_Transfer.load("${id}")' inside your loader) to avoid unexpected behaviour. This is a runtime validation check.`,
                )

                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                inMemoryStore.sokosERC721_Transfer->IO.InMemoryStore.SokosERC721_Transfer.get(id)

                // TODO: add a further step to synchronously try fetch this from the DB if it isn't in the in-memory store - similar to this PR: https://github.com/Float-Capital/indexer/pull/759
              }
            },
          },
        }
      }

      let getHandlerContextAsync = (): handlerContextAsync => {
        {
          log: contextLogger,
          account: {
            set: entity => {
              inMemoryStore.account->IO.InMemoryStore.Account.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.account->IO.InMemoryStore.Account.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: async (id: Types.id) => {
              if optSetOfIds_account->Set.has(id) {
                inMemoryStore.account->IO.InMemoryStore.Account.get(id)
              } else {
                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                switch inMemoryStore.account->IO.InMemoryStore.Account.get(id) {
                | Some(entity) => Some(entity)
                | None =>
                  let entities = await asyncGetters.getAccount(id)

                  let optEntity = entities->Belt.Array.get(0)

                  IO.InMemoryStore.Account.initValue(
                    inMemoryStore.account,
                    ~key=id,
                    ~entity=optEntity,
                  )

                  optEntity
                }
              }
            },
          },
          collection: {
            set: entity => {
              inMemoryStore.collection->IO.InMemoryStore.Collection.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.collection->IO.InMemoryStore.Collection.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: async (id: Types.id) => {
              if optSetOfIds_collection->Set.has(id) {
                inMemoryStore.collection->IO.InMemoryStore.Collection.get(id)
              } else {
                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                switch inMemoryStore.collection->IO.InMemoryStore.Collection.get(id) {
                | Some(entity) => Some(entity)
                | None =>
                  let entities = await asyncGetters.getCollection(id)

                  let optEntity = entities->Belt.Array.get(0)

                  IO.InMemoryStore.Collection.initValue(
                    inMemoryStore.collection,
                    ~key=id,
                    ~entity=optEntity,
                  )

                  optEntity
                }
              }
            },
            getOwner: async collection => {
              let owner_field = collection.owner_id
              let optOwner = inMemoryStore.account->IO.InMemoryStore.Account.get(owner_field)
              switch optOwner {
              | Some(owner) => owner
              | None =>
                let entities = await asyncGetters.getAccount(owner_field)

                switch entities->Belt.Array.get(0) {
                | Some(entity) =>
                  // TODO: make this work with the test framework too.
                  IO.InMemoryStore.Account.initValue(
                    inMemoryStore.account,
                    ~key=entity.id,
                    ~entity=Some(entity),
                  )
                  entity
                | None =>
                  Logging.error(`Collection owner data not found. Loading associated account from database.
This is likely due to a database corruption. Please reach out to the team on discord.
`)

                  raise(
                    UnableToLoadNonNullableLinkedEntity(
                      "The required linked entity owner of Collection is undefined.",
                    ),
                  )
                }
              }
            },
          },
          factory_CollectionDeployed: {
            set: entity => {
              inMemoryStore.factory_CollectionDeployed->IO.InMemoryStore.Factory_CollectionDeployed.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.factory_CollectionDeployed->IO.InMemoryStore.Factory_CollectionDeployed.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: async (id: Types.id) => {
              if optSetOfIds_factory_CollectionDeployed->Set.has(id) {
                inMemoryStore.factory_CollectionDeployed->IO.InMemoryStore.Factory_CollectionDeployed.get(
                  id,
                )
              } else {
                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                switch inMemoryStore.factory_CollectionDeployed->IO.InMemoryStore.Factory_CollectionDeployed.get(
                  id,
                ) {
                | Some(entity) => Some(entity)
                | None =>
                  let entities = await asyncGetters.getFactory_CollectionDeployed(id)

                  let optEntity = entities->Belt.Array.get(0)

                  IO.InMemoryStore.Factory_CollectionDeployed.initValue(
                    inMemoryStore.factory_CollectionDeployed,
                    ~key=id,
                    ~entity=optEntity,
                  )

                  optEntity
                }
              }
            },
          },
          nft: {
            set: entity => {
              inMemoryStore.nft->IO.InMemoryStore.Nft.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.nft->IO.InMemoryStore.Nft.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: async (id: Types.id) => {
              if optSetOfIds_nft->Set.has(id) {
                inMemoryStore.nft->IO.InMemoryStore.Nft.get(id)
              } else {
                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                switch inMemoryStore.nft->IO.InMemoryStore.Nft.get(id) {
                | Some(entity) => Some(entity)
                | None =>
                  let entities = await asyncGetters.getNft(id)

                  let optEntity = entities->Belt.Array.get(0)

                  IO.InMemoryStore.Nft.initValue(inMemoryStore.nft, ~key=id, ~entity=optEntity)

                  optEntity
                }
              }
            },
            getCollection: async nft => {
              let collection_field = nft.collection_id
              let optCollection =
                inMemoryStore.collection->IO.InMemoryStore.Collection.get(collection_field)
              switch optCollection {
              | Some(collection) => collection
              | None =>
                let entities = await asyncGetters.getCollection(collection_field)

                switch entities->Belt.Array.get(0) {
                | Some(entity) =>
                  // TODO: make this work with the test framework too.
                  IO.InMemoryStore.Collection.initValue(
                    inMemoryStore.collection,
                    ~key=entity.id,
                    ~entity=Some(entity),
                  )
                  entity
                | None =>
                  Logging.error(`Nft collection data not found. Loading associated collection from database.
This is likely due to a database corruption. Please reach out to the team on discord.
`)

                  raise(
                    UnableToLoadNonNullableLinkedEntity(
                      "The required linked entity collection of Nft is undefined.",
                    ),
                  )
                }
              }
            },
            getOwner: async nft => {
              let owner_field = nft.owner_id
              let optOwner = inMemoryStore.account->IO.InMemoryStore.Account.get(owner_field)
              switch optOwner {
              | Some(owner) => owner
              | None =>
                let entities = await asyncGetters.getAccount(owner_field)

                switch entities->Belt.Array.get(0) {
                | Some(entity) =>
                  // TODO: make this work with the test framework too.
                  IO.InMemoryStore.Account.initValue(
                    inMemoryStore.account,
                    ~key=entity.id,
                    ~entity=Some(entity),
                  )
                  entity
                | None =>
                  Logging.error(`Nft owner data not found. Loading associated account from database.
This is likely due to a database corruption. Please reach out to the team on discord.
`)

                  raise(
                    UnableToLoadNonNullableLinkedEntity(
                      "The required linked entity owner of Nft is undefined.",
                    ),
                  )
                }
              }
            },
          },
          sokosERC721_Transfer: {
            set: entity => {
              inMemoryStore.sokosERC721_Transfer->IO.InMemoryStore.SokosERC721_Transfer.set(
                ~key=entity.id,
                ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            deleteUnsafe: id => {
              inMemoryStore.sokosERC721_Transfer->IO.InMemoryStore.SokosERC721_Transfer.set(
                ~key=id,
                ~entity=Delete(id)->Types.mkEntityUpdate(~eventIdentifier),
              )
            },
            get: async (id: Types.id) => {
              if optSetOfIds_sokosERC721_Transfer->Set.has(id) {
                inMemoryStore.sokosERC721_Transfer->IO.InMemoryStore.SokosERC721_Transfer.get(id)
              } else {
                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                switch inMemoryStore.sokosERC721_Transfer->IO.InMemoryStore.SokosERC721_Transfer.get(
                  id,
                ) {
                | Some(entity) => Some(entity)
                | None =>
                  let entities = await asyncGetters.getSokosERC721_Transfer(id)

                  let optEntity = entities->Belt.Array.get(0)

                  IO.InMemoryStore.SokosERC721_Transfer.initValue(
                    inMemoryStore.sokosERC721_Transfer,
                    ~key=id,
                    ~entity=optEntity,
                  )

                  optEntity
                }
              }
            },
          },
        }
      }

      {
        logger,
        log: contextLogger,
        getEntitiesToLoad: () => entitiesToLoad,
        getAddedDynamicContractRegistrations: () => addedDynamicContractRegistrations,
        getLoaderContext: () => loaderContext,
        getHandlerContextSync,
        getHandlerContextAsync,
      }
    }
  }
}

type eventAndContext =
  | FactoryContract_CollectionDeployedWithContext(
      Types.eventLog<Types.FactoryContract.CollectionDeployedEvent.eventArgs>,
      FactoryContract.CollectionDeployedEvent.context,
    )
  | SokosERC721Contract_TransferWithContext(
      Types.eventLog<Types.SokosERC721Contract.TransferEvent.eventArgs>,
      SokosERC721Contract.TransferEvent.context,
    )

type eventRouterEventAndContext = {
  chainId: int,
  event: eventAndContext,
}
