/***** TAKE NOTE ******
This file module is a hack to get genType to work!

In order for genType to produce recursive types, it needs to be at the 
root module of a file. If it's defined in a nested module it does not 
work. So all the MockDb types and internal functions are defined here in TestHelpers_MockDb
and only public functions are recreated and exported from TestHelpers.MockDb module.

the following module:
```rescript
module MyModule = {
  @genType
  type rec a = {fieldB: b}
  @genType and b = {fieldA: a}
}
```

produces the following in ts:
```ts
// tslint:disable-next-line:interface-over-type-literal
export type MyModule_a = { readonly fieldB: b };

// tslint:disable-next-line:interface-over-type-literal
export type MyModule_b = { readonly fieldA: MyModule_a };
```

fieldB references type b which doesn't exist because it's defined
as MyModule_b
*/

open Belt

/**
A raw js binding to allow deleting from a dict. Used in store delete operation
*/
let deleteDictKey: (Js.Dict.t<'a>, string) => unit = %raw(`
    function(dict, key) {
      delete dict[key]
    }
  `)

/**
The mockDb type is simply an InMemoryStore internally. __dbInternal__ holds a reference
to an inMemoryStore and all the the accessor methods point to the reference of that inMemory
store
*/
@genType
type rec t = {
  __dbInternal__: IO.InMemoryStore.t,
  entities: entities,
  rawEvents: storeOperations<IO.InMemoryStore.rawEventsKey, Types.rawEventsEntity>,
  eventSyncState: storeOperations<Types.chainId, DbFunctions.EventSyncState.eventSyncState>,
  dynamicContractRegistry: storeOperations<
    IO.InMemoryStore.dynamicContractRegistryKey,
    Types.dynamicContractRegistryEntity,
  >,
}

// Each user defined entity will be in this record with all the store or "mockdb" operators
@genType
and entities = {
  @as("Account") account: entityStoreOperations<Entities.Account.t>,
  @as("Collection") collection: entityStoreOperations<Entities.Collection.t>,
  @as("Factory_CollectionDeployed")
  factory_CollectionDeployed: entityStoreOperations<Entities.Factory_CollectionDeployed.t>,
  @as("Nft") nft: entityStoreOperations<Entities.Nft.t>,
  @as("SokosERC721_Transfer")
  sokosERC721_Transfer: entityStoreOperations<Entities.SokosERC721_Transfer.t>,
}
// User defined entities always have a string for an id which is used as the
// key for entity stores
@genType and entityStoreOperations<'entity> = storeOperations<string, 'entity>
// all the operator functions a user can access on an entity in the mock db
// stores refer to the the module that MakeStore functor outputs in IO.res
@genType
and storeOperations<'entityKey, 'entity> = {
  getAll: unit => array<'entity>,
  get: 'entityKey => option<'entity>,
  set: 'entity => t,
  delete: 'entityKey => t,
}

module type StoreStateEntity = {
  type value
  type key
  let get: (IO.InMemoryStore.storeStateEntity<value, key>, key) => option<value>
  let values: IO.InMemoryStore.storeStateEntity<value, key> => array<
    Types.inMemoryStoreRowEntity<value>,
  >
  // TODO: add initValue function here too
  let set: (
    IO.InMemoryStore.storeStateEntity<value, key>,
    ~key: key,
    ~entity: Types.entityUpdate<value>,
  ) => unit
}

module type StoreStateMeta = {
  type value
  type key
  let get: (IO.InMemoryStore.storeStateMeta<value, key>, key) => option<value>
  let values: IO.InMemoryStore.storeStateMeta<value, key> => array<
    Types.inMemoryStoreRowMeta<value>,
  >
  let set: (IO.InMemoryStore.storeStateMeta<value, key>, ~key: key, ~entity: value) => unit
}

// /**
// a composable function to make the "storeOperations" record to represent all the mock
// db operations for each entity.
// */
let makeStoreOperatorEntity = (
  type entity key,
  storeStateMod: module(StoreStateEntity with type value = entity and type key = key),
  ~inMemoryStore: IO.InMemoryStore.t,
  ~makeMockDb,
  ~getStore: IO.InMemoryStore.t => IO.InMemoryStore.storeStateEntity<entity, key>,
  ~getKey: entity => key,
): storeOperations<key, entity> => {
  let module(StoreState) = storeStateMod
  let {get, values, set} = module(StoreState)

  let get = inMemoryStore->getStore->get
  let getAll = () =>
    inMemoryStore
    ->getStore
    ->values
    ->Array.keepMap(row =>
      switch row {
      | Updated({latest: {entityUpdateAction: Set(entity)}})
      | InitialReadFromDb(AlreadySet(entity)) =>
        Some(entity)
      | Updated({latest: {entityUpdateAction: Delete(_)}})
      | InitialReadFromDb(NotSet) =>
        None
      }
    )

  let set = entity => {
    let cloned = inMemoryStore->IO.InMemoryStore.clone
    cloned
    ->getStore
    ->set(
      ~key=entity->getKey,
      ~entity=Set(entity)->Types.mkEntityUpdate(
        ~eventIdentifier={chainId: -1, blockNumber: -1, blockTimestamp: 0, logIndex: -1},
      ),
    )
    cloned->makeMockDb
  }

  let delete = key => {
    let cloned = inMemoryStore->IO.InMemoryStore.clone
    let store = cloned->getStore
    store.dict->deleteDictKey(key->store.hasher)
    cloned->makeMockDb
  }

  {
    getAll,
    get,
    set,
    delete,
  }
}

let makeStoreOperatorMeta = (
  type meta key,
  storeStateMod: module(StoreStateMeta with type value = meta and type key = key),
  ~inMemoryStore: IO.InMemoryStore.t,
  ~makeMockDb,
  ~getStore: IO.InMemoryStore.t => IO.InMemoryStore.storeStateMeta<meta, key>,
  ~getKey: meta => key,
): storeOperations<key, meta> => {
  let module(StoreState) = storeStateMod
  let {get, values, set} = module(StoreState)

  let get = inMemoryStore->getStore->get
  // unit => array<StoreState.value>
  let getAll = () => inMemoryStore->getStore->values->Array.map(row => row)

  let set = entity => {
    let cloned = inMemoryStore->IO.InMemoryStore.clone
    cloned->getStore->set(~key=entity->getKey, ~entity)
    cloned->makeMockDb
  }

  // TODO: Remove. Is delete needed for meta data?
  let delete = key => {
    let cloned = inMemoryStore->IO.InMemoryStore.clone
    let store = cloned->getStore
    store.dict->deleteDictKey(key->store.hasher)
    cloned->makeMockDb
  }

  {
    getAll,
    get,
    set,
    delete,
  }
}

/**
The internal make function which can be passed an in memory store and
instantiate a "MockDb". This is useful for cloning or making a MockDb
out of an existing inMemoryStore
*/
let rec makeWithInMemoryStore: IO.InMemoryStore.t => t = (inMemoryStore: IO.InMemoryStore.t) => {
  let rawEvents = module(IO.InMemoryStore.RawEvents)->makeStoreOperatorMeta(
    ~inMemoryStore,
    ~makeMockDb=makeWithInMemoryStore,
    ~getStore=db => db.rawEvents,
    ~getKey=({chainId, eventId}) => {
      chainId,
      eventId,
    },
  )

  let eventSyncState =
    module(IO.InMemoryStore.EventSyncState)->makeStoreOperatorMeta(
      ~inMemoryStore,
      ~makeMockDb=makeWithInMemoryStore,
      ~getStore=db => db.eventSyncState,
      ~getKey=({chainId}) => chainId,
    )

  let dynamicContractRegistry =
    module(IO.InMemoryStore.DynamicContractRegistry)->makeStoreOperatorMeta(
      ~inMemoryStore,
      ~getStore=db => db.dynamicContractRegistry,
      ~makeMockDb=makeWithInMemoryStore,
      ~getKey=({chainId, contractAddress}) => {chainId, contractAddress},
    )

  let entities = {
    account: {
      module(IO.InMemoryStore.Account)->makeStoreOperatorEntity(
        ~inMemoryStore,
        ~makeMockDb=makeWithInMemoryStore,
        ~getStore=db => db.account,
        ~getKey=({id}) => id,
      )
    },
    collection: {
      module(IO.InMemoryStore.Collection)->makeStoreOperatorEntity(
        ~inMemoryStore,
        ~makeMockDb=makeWithInMemoryStore,
        ~getStore=db => db.collection,
        ~getKey=({id}) => id,
      )
    },
    factory_CollectionDeployed: {
      module(IO.InMemoryStore.Factory_CollectionDeployed)->makeStoreOperatorEntity(
        ~inMemoryStore,
        ~makeMockDb=makeWithInMemoryStore,
        ~getStore=db => db.factory_CollectionDeployed,
        ~getKey=({id}) => id,
      )
    },
    nft: {
      module(IO.InMemoryStore.Nft)->makeStoreOperatorEntity(
        ~inMemoryStore,
        ~makeMockDb=makeWithInMemoryStore,
        ~getStore=db => db.nft,
        ~getKey=({id}) => id,
      )
    },
    sokosERC721_Transfer: {
      module(IO.InMemoryStore.SokosERC721_Transfer)->makeStoreOperatorEntity(
        ~inMemoryStore,
        ~makeMockDb=makeWithInMemoryStore,
        ~getStore=db => db.sokosERC721_Transfer,
        ~getKey=({id}) => id,
      )
    },
  }

  {__dbInternal__: inMemoryStore, entities, rawEvents, eventSyncState, dynamicContractRegistry}
}

//Note: It's called createMockDb over "make" to make it more intuitive in JS and TS

/**
The constructor function for a mockDb. Call it and then set up the inital state by calling
any of the set functions it provides access to. A mockDb will be passed into a processEvent 
helper. Note, process event helpers will not mutate the mockDb but return a new mockDb with
new state so you can compare states before and after.
*/
@genType
let createMockDb = () => makeWithInMemoryStore(IO.InMemoryStore.make())

/**
Accessor function for getting the internal inMemoryStore in the mockDb
*/
let getInternalDb = (self: t) => self.__dbInternal__

/**
Deep copies the in memory store data and returns a new mockDb with the same
state and no references to data from the passed in mockDb
*/
let cloneMockDb = (self: t) => {
  let clonedInternalDb = self->getInternalDb->IO.InMemoryStore.clone
  clonedInternalDb->makeWithInMemoryStore
}

/**
Specifically create an executor for the mockDb
*/
let makeMockDbEntityExecuter = (~idsToLoad, ~dbReadFn, ~inMemStoreInitFn, ~store, ~getEntiyId) => {
  let dbReadFn = idsArr => idsArr->Belt.Array.keepMap(id => id->dbReadFn)
  IO.makeEntityExecuterComposer(
    ~idsToLoad,
    ~dbReadFn,
    ~inMemStoreInitFn,
    ~store,
    ~getEntiyId,
    ~unit=(),
    ~then=(res, fn) => res->fn,
  )
}

/**
Executes a single load layer using the mockDb functions
*/
let executeMockDbLoadLayer = (
  mockDb: t,
  ~loadLayer: IO.LoadLayer.t,
  ~inMemoryStore: IO.InMemoryStore.t,
) => {
  let entityExecutors = [
    makeMockDbEntityExecuter(
      ~idsToLoad=loadLayer.accountIdsToLoad,
      ~dbReadFn=mockDb.entities.account.get,
      ~inMemStoreInitFn=IO.InMemoryStore.Account.initValue,
      ~store=inMemoryStore.account,
      ~getEntiyId=entity => entity.id,
    ),
    makeMockDbEntityExecuter(
      ~idsToLoad=loadLayer.collectionIdsToLoad,
      ~dbReadFn=mockDb.entities.collection.get,
      ~inMemStoreInitFn=IO.InMemoryStore.Collection.initValue,
      ~store=inMemoryStore.collection,
      ~getEntiyId=entity => entity.id,
    ),
    makeMockDbEntityExecuter(
      ~idsToLoad=loadLayer.factory_CollectionDeployedIdsToLoad,
      ~dbReadFn=mockDb.entities.factory_CollectionDeployed.get,
      ~inMemStoreInitFn=IO.InMemoryStore.Factory_CollectionDeployed.initValue,
      ~store=inMemoryStore.factory_CollectionDeployed,
      ~getEntiyId=entity => entity.id,
    ),
    makeMockDbEntityExecuter(
      ~idsToLoad=loadLayer.nftIdsToLoad,
      ~dbReadFn=mockDb.entities.nft.get,
      ~inMemStoreInitFn=IO.InMemoryStore.Nft.initValue,
      ~store=inMemoryStore.nft,
      ~getEntiyId=entity => entity.id,
    ),
    makeMockDbEntityExecuter(
      ~idsToLoad=loadLayer.sokosERC721_TransferIdsToLoad,
      ~dbReadFn=mockDb.entities.sokosERC721_Transfer.get,
      ~inMemStoreInitFn=IO.InMemoryStore.SokosERC721_Transfer.initValue,
      ~store=inMemoryStore.sokosERC721_Transfer,
      ~getEntiyId=entity => entity.id,
    ),
  ]
  let handleResponses = _ => {
    IO.getNextLayer(~loadLayer)
  }

  IO.executeLoadLayerComposer(~entityExecutors, ~handleResponses)
}

/**
Given an isolated inMemoryStore and an array of read entities. This function loads the 
requested data from the mockDb into the inMemory store. Simulating how loading happens
from and external db into the inMemoryStore for a batch during event processing
*/
let loadEntitiesToInMemStore = (mockDb, ~entityBatch, ~inMemoryStore) => {
  let executeLoadLayerFn = mockDb->executeMockDbLoadLayer
  //In an async handler this would be a Promise.then... in this case
  //just need to return the value and pass it into the callback
  let then = (res, fn) => res->fn
  IO.loadEntitiesToInMemStoreComposer(
    ~inMemoryStore,
    ~entityBatch,
    ~executeLoadLayerFn,
    ~then,
    ~unit=(),
  )
}

/**
A function composer for simulating the writing of an inMemoryStore to the external db with a mockDb.
Runs all set and delete operations currently cached in an inMemory store against the mockDb
*/
let executeRowsEntity = (
  mockDb: t,
  ~inMemoryStore: IO.InMemoryStore.t,
  ~getStore: IO.InMemoryStore.t => IO.InMemoryStore.storeStateEntity<'entity, 'key>,
  ~getRows: IO.InMemoryStore.storeStateEntity<'entity, 'key> => array<
    Types.inMemoryStoreRowEntity<'entity>,
  >,
  ~getKey: 'entity => 'key,
  ~setFunction: (
    ~allowOverWriteEntity: bool=?,
    ~key: 'key,
    ~entity: option<'entity>,
    IO.InMemoryStore.storeStateEntity<'entity, 'key>,
  ) => unit,
) => {
  inMemoryStore
  ->getStore
  ->getRows
  ->Array.forEach(row => {
    let store = mockDb->getInternalDb->getStore
    switch row {
    | Updated({latest: {entityUpdateAction: Set(entity)}})
    | InitialReadFromDb(AlreadySet(entity)) =>
      store->setFunction(~allowOverWriteEntity=true, ~key=getKey(entity), ~entity=Some(entity))
    | Updated({latest: {entityUpdateAction: Delete(entityId)}}) =>
      store.dict->deleteDictKey(entityId)
    | InitialReadFromDb(NotSet) => ()
    }
  })
}

let executeRowsMeta = (
  mockDb: t,
  ~inMemoryStore: IO.InMemoryStore.t,
  ~getStore: IO.InMemoryStore.t => IO.InMemoryStore.storeStateMeta<'entity, 'key>,
  ~getRows: IO.InMemoryStore.storeStateMeta<'entity, 'key> => array<
    Types.inMemoryStoreRowMeta<'entity>,
  >,
  ~getKey: 'entity => 'key,
  ~setFunction: (
    IO.InMemoryStore.storeStateMeta<'entity, 'key>,
    ~key: 'key,
    ~entity: 'entity,
  ) => unit,
) => {
  inMemoryStore
  ->getStore
  ->getRows
  ->Array.forEach(row => {
    mockDb->getInternalDb->getStore->setFunction(~key=getKey(row), ~entity=row)
  })
}

/**
Simulates the writing of processed data in the inMemoryStore to a mockDb. This function
executes all the rows on each "store" (or pg table) in the inMemoryStore
*/
let writeFromMemoryStore = (mockDb: t, ~inMemoryStore: IO.InMemoryStore.t) => {
  open IO
  //INTERNAL STORES/TABLES EXECUTION
  mockDb->executeRowsMeta(
    ~inMemoryStore,
    ~getRows=InMemoryStore.RawEvents.values,
    ~getStore=inMemStore => {inMemStore.rawEvents},
    ~setFunction=InMemoryStore.RawEvents.set,
    ~getKey=(entity): IO.InMemoryStore.rawEventsKey => {
      chainId: entity.chainId,
      eventId: entity.eventId,
    },
  )

  mockDb->executeRowsMeta(
    ~inMemoryStore,
    ~getStore=inMemStore => {inMemStore.eventSyncState},
    ~getRows=InMemoryStore.EventSyncState.values,
    ~setFunction=InMemoryStore.EventSyncState.set,
    ~getKey=entity => entity.chainId,
  )

  mockDb->executeRowsMeta(
    ~inMemoryStore,
    ~getRows=InMemoryStore.DynamicContractRegistry.values,
    ~getStore=inMemStore => {inMemStore.dynamicContractRegistry},
    ~setFunction=InMemoryStore.DynamicContractRegistry.set,
    ~getKey=(entity): IO.InMemoryStore.dynamicContractRegistryKey => {
      chainId: entity.chainId,
      contractAddress: entity.contractAddress,
    },
  )

  //ENTITY EXECUTION
  mockDb->executeRowsEntity(
    ~inMemoryStore,
    ~getStore=self => {self.account},
    ~getRows=IO.InMemoryStore.Account.values,
    ~setFunction=IO.InMemoryStore.Account.initValue,
    ~getKey=entity => entity.id,
  )
  mockDb->executeRowsEntity(
    ~inMemoryStore,
    ~getStore=self => {self.collection},
    ~getRows=IO.InMemoryStore.Collection.values,
    ~setFunction=IO.InMemoryStore.Collection.initValue,
    ~getKey=entity => entity.id,
  )
  mockDb->executeRowsEntity(
    ~inMemoryStore,
    ~getStore=self => {self.factory_CollectionDeployed},
    ~getRows=IO.InMemoryStore.Factory_CollectionDeployed.values,
    ~setFunction=IO.InMemoryStore.Factory_CollectionDeployed.initValue,
    ~getKey=entity => entity.id,
  )
  mockDb->executeRowsEntity(
    ~inMemoryStore,
    ~getStore=self => {self.nft},
    ~getRows=IO.InMemoryStore.Nft.values,
    ~setFunction=IO.InMemoryStore.Nft.initValue,
    ~getKey=entity => entity.id,
  )
  mockDb->executeRowsEntity(
    ~inMemoryStore,
    ~getStore=self => {self.sokosERC721_Transfer},
    ~getRows=IO.InMemoryStore.SokosERC721_Transfer.values,
    ~setFunction=IO.InMemoryStore.SokosERC721_Transfer.initValue,
    ~getKey=entity => entity.id,
  )
}
