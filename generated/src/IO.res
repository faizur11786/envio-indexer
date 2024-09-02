let executeSet = (
  sql: Postgres.sql,
  ~items: array<'a>,
  ~dbFunction: (Postgres.sql, array<'a>) => promise<unit>,
) => {
  if items->Array.length > 0 {
    sql->dbFunction(items)
  } else {
    Promise.resolve()
  }
}

let getEntityHistoryItems = (entityUpdates, ~entitySchema, ~entityType) => {
  let (_, entityHistoryItems) = entityUpdates->Belt.Array.reduce((None, []), (
    prev: (option<Types.eventIdentifier>, array<DbFunctions.entityHistoryItem>),
    entityUpdate: Types.entityUpdate<'a>,
  ) => {
    let (optPreviousEventIdentifier, entityHistoryItems) = prev

    let {eventIdentifier, shouldSaveHistory, entityUpdateAction, entityId} = entityUpdate
    let entityHistoryItems = if shouldSaveHistory {
      let mapPrev = Belt.Option.map(optPreviousEventIdentifier)
      let params = switch entityUpdateAction {
      | Set(entity) => Some(entity->S.serializeOrRaiseWith(entitySchema))

      | Delete => None
      }
      let historyItem: DbFunctions.entityHistoryItem = {
        chain_id: eventIdentifier.chainId,
        block_number: eventIdentifier.blockNumber,
        block_timestamp: eventIdentifier.blockTimestamp,
        log_index: eventIdentifier.logIndex,
        previous_chain_id: mapPrev(prev => prev.chainId),
        previous_block_timestamp: mapPrev(prev => prev.blockTimestamp),
        previous_block_number: mapPrev(prev => prev.blockNumber),
        previous_log_index: mapPrev(prev => prev.logIndex),
        entity_type: entityType,
        entity_id: entityId,
        params,
      }
      entityHistoryItems->Belt.Array.concat([historyItem])
    } else {
      entityHistoryItems
    }

    (Some(eventIdentifier), entityHistoryItems)
  })

  entityHistoryItems
}

let executeSetEntityWithHistory = (
  type entity,
  sql: Postgres.sql,
  ~rows: array<Types.inMemoryStoreRowEntity<entity>>,
  ~entityMod: module(Entities.Entity with type t = entity),
): promise<unit> => {
  let module(EntityMod) = entityMod
  let {schema, table} = module(EntityMod)
  let (entitiesToSet, idsToDelete, entityHistoryItemsToSet) = rows->Belt.Array.reduce(
    ([], [], []),
    ((entitiesToSet, idsToDelete, entityHistoryItemsToSet), row) => {
      switch row {
      | Updated({latest, history}) =>
        let entityHistoryItems =
          history
          ->Belt.Array.concat([latest])
          ->getEntityHistoryItems(~entitySchema=schema, ~entityType=table.tableName)

        switch latest.entityUpdateAction {
        | Set(entity) => (
            entitiesToSet->Belt.Array.concat([entity]),
            idsToDelete,
            entityHistoryItemsToSet->Belt.Array.concat([entityHistoryItems]),
          )
        | Delete => (
            entitiesToSet,
            idsToDelete->Belt.Array.concat([latest.entityId]),
            entityHistoryItemsToSet->Belt.Array.concat([entityHistoryItems]),
          )
        }
      | _ => (entitiesToSet, idsToDelete, entityHistoryItemsToSet)
      }
    },
  )

  [
    sql->DbFunctions.EntityHistory.batchSet(
      ~entityHistoriesToSet=Belt.Array.concatMany(entityHistoryItemsToSet),
    ),
    if entitiesToSet->Array.length > 0 {
      sql->DbFunctionsEntities.batchSet(~entityMod)(entitiesToSet)
    } else {
      Promise.resolve()
    },
    if idsToDelete->Array.length > 0 {
      sql->DbFunctionsEntities.batchDelete(~entityMod)(idsToDelete)
    } else {
      Promise.resolve()
    },
  ]
  ->Promise.all
  ->Promise.thenResolve(_ => ())
}

let executeDbFunctionsEntity = (
  type entity,
  sql: Postgres.sql,
  ~rows: array<Types.inMemoryStoreRowEntity<entity>>,
  ~entityMod: module(Entities.Entity with type t = entity),
): promise<unit> => {
  let (entitiesToSet, idsToDelete) = rows->Belt.Array.reduce(([], []), (
    (accumulatedSets, accumulatedDeletes),
    row,
  ) =>
    switch row {
    | Updated({latest: {entityUpdateAction: Set(entity)}}) => (
        Belt.Array.concat(accumulatedSets, [entity]),
        accumulatedDeletes,
      )
    | Updated({latest: {entityUpdateAction: Delete, entityId}}) => (
        accumulatedSets,
        Belt.Array.concat(accumulatedDeletes, [entityId]),
      )
    | _ => (accumulatedSets, accumulatedDeletes)
    }
  )

  let promises =
    (
      entitiesToSet->Array.length > 0 ? [sql->DbFunctionsEntities.batchSet(~entityMod)(entitiesToSet)] : []
    )->Belt.Array.concat(
      idsToDelete->Array.length > 0 ? [sql->DbFunctionsEntities.batchDelete(~entityMod)(idsToDelete)] : [],
    )

  promises->Promise.all->Promise.thenResolve(_ => ())
}

let executeBatch = async (sql, ~inMemoryStore: InMemoryStore.t) => {
  let entityDbExecutionComposer = Config.getGenerated()->Config.shouldRollbackOnReorg
    ? executeSetEntityWithHistory
    : executeDbFunctionsEntity

  let setEventSyncState = executeSet(
    _,
    ~dbFunction=DbFunctions.EventSyncState.batchSet,
    ~items=inMemoryStore.eventSyncState->InMemoryTable.values,
  )

  let setRawEvents = executeSet(
    _,
    ~dbFunction=DbFunctions.RawEvents.batchSet,
    ~items=inMemoryStore.rawEvents->InMemoryTable.values,
  )

  let setDynamicContracts = executeSet(
    _,
    ~dbFunction=DbFunctions.DynamicContractRegistry.batchSet,
    ~items=inMemoryStore.dynamicContractRegistry->InMemoryTable.values,
  )

  let setAccounts = entityDbExecutionComposer(
    _,
    ~entityMod=module(Entities.Account),
    ~rows=inMemoryStore.account->InMemoryTable.Entity.rows,
  )

  let setCollections = entityDbExecutionComposer(
    _,
    ~entityMod=module(Entities.Collection),
    ~rows=inMemoryStore.collection->InMemoryTable.Entity.rows,
  )

  let setFactory_CollectionDeployeds = entityDbExecutionComposer(
    _,
    ~entityMod=module(Entities.Factory_CollectionDeployed),
    ~rows=inMemoryStore.factory_CollectionDeployed->InMemoryTable.Entity.rows,
  )

  let setNfts = entityDbExecutionComposer(
    _,
    ~entityMod=module(Entities.Nft),
    ~rows=inMemoryStore.nft->InMemoryTable.Entity.rows,
  )

  let setSokosERC721_Transfers = entityDbExecutionComposer(
    _,
    ~entityMod=module(Entities.SokosERC721_Transfer),
    ~rows=inMemoryStore.sokosERC721_Transfer->InMemoryTable.Entity.rows,
  )

  //In the event of a rollback, rollback all meta tables based on the given
  //valid event identifier, where all rows created after this eventIdentifier should
  //be deleted
  let rollbackTables = switch inMemoryStore.rollBackEventIdentifier {
  | Some(eventIdentifier) =>
    [
      DbFunctions.EntityHistory.deleteAllEntityHistoryAfterEventIdentifier,
      DbFunctions.RawEvents.deleteAllRawEventsAfterEventIdentifier,
      DbFunctions.DynamicContractRegistry.deleteAllDynamicContractRegistrationsAfterEventIdentifier,
    ]->Belt.Array.map(fn => fn(_, ~eventIdentifier))
  | None => []
  }

  let res = await sql->Postgres.beginSql(sql => {
    Belt.Array.concat(
      //Rollback tables need to happen first in the traction
      rollbackTables,
      [
        setEventSyncState,
        setRawEvents,
        setDynamicContracts,
        setAccounts,
        setCollections,
        setFactory_CollectionDeployeds,
        setNfts,
        setSokosERC721_Transfers,
      ],
    )->Belt.Array.map(dbFunc => sql->dbFunc)
  })

  res
}

module RollBack = {
  exception DecodeError(S.error)
  let rollBack = async (~chainId, ~blockTimestamp, ~blockNumber, ~logIndex) => {
    let reorgData = switch await DbFunctions.sql->DbFunctions.EntityHistory.getRollbackDiff(
      ~chainId,
      ~blockTimestamp,
      ~blockNumber,
    ) {
    | Ok(v) => v
    | Error(exn) =>
      exn
      ->DecodeError
      ->ErrorHandling.mkLogAndRaise(~msg="Failed to get rollback diff from entity history")
    }

    let rollBackEventIdentifier: Types.eventIdentifier = {
      chainId,
      blockTimestamp,
      blockNumber,
      logIndex,
    }

    let inMemStore = InMemoryStore.makeWithRollBackEventIdentifier(Some(rollBackEventIdentifier))

    reorgData->Belt.Array.forEach(e => {
      switch e {
      //Where previousEntity is Some, 
      //set the value with the eventIdentifier that set that value initially
      | {previousEntity: Some({entity: Account(entity), eventIdentifier}), entityId} =>
        inMemStore.account->InMemoryTable.Entity.set(
          Set(entity)->Types.mkEntityUpdate(~eventIdentifier, ~entityId, ~shouldSaveHistory=false),
        )
      | {previousEntity: Some({entity: Collection(entity), eventIdentifier}), entityId} =>
        inMemStore.collection->InMemoryTable.Entity.set(
          Set(entity)->Types.mkEntityUpdate(~eventIdentifier, ~entityId, ~shouldSaveHistory=false),
        )
      | {previousEntity: Some({entity: Factory_CollectionDeployed(entity), eventIdentifier}), entityId} =>
        inMemStore.factory_CollectionDeployed->InMemoryTable.Entity.set(
          Set(entity)->Types.mkEntityUpdate(~eventIdentifier, ~entityId, ~shouldSaveHistory=false),
        )
      | {previousEntity: Some({entity: Nft(entity), eventIdentifier}), entityId} =>
        inMemStore.nft->InMemoryTable.Entity.set(
          Set(entity)->Types.mkEntityUpdate(~eventIdentifier, ~entityId, ~shouldSaveHistory=false),
        )
      | {previousEntity: Some({entity: SokosERC721_Transfer(entity), eventIdentifier}), entityId} =>
        inMemStore.sokosERC721_Transfer->InMemoryTable.Entity.set(
          Set(entity)->Types.mkEntityUpdate(~eventIdentifier, ~entityId, ~shouldSaveHistory=false),
        )
      //Where previousEntity is None, 
      //delete it with the eventIdentifier of the rollback event
      | {previousEntity: None, entityType: Account, entityId} =>
        inMemStore.account->InMemoryTable.Entity.set(
          Delete->Types.mkEntityUpdate(~eventIdentifier=rollBackEventIdentifier, ~entityId, ~shouldSaveHistory=false),
        )
      | {previousEntity: None, entityType: Collection, entityId} =>
        inMemStore.collection->InMemoryTable.Entity.set(
          Delete->Types.mkEntityUpdate(~eventIdentifier=rollBackEventIdentifier, ~entityId, ~shouldSaveHistory=false),
        )
      | {previousEntity: None, entityType: Factory_CollectionDeployed, entityId} =>
        inMemStore.factory_CollectionDeployed->InMemoryTable.Entity.set(
          Delete->Types.mkEntityUpdate(~eventIdentifier=rollBackEventIdentifier, ~entityId, ~shouldSaveHistory=false),
        )
      | {previousEntity: None, entityType: Nft, entityId} =>
        inMemStore.nft->InMemoryTable.Entity.set(
          Delete->Types.mkEntityUpdate(~eventIdentifier=rollBackEventIdentifier, ~entityId, ~shouldSaveHistory=false),
        )
      | {previousEntity: None, entityType: SokosERC721_Transfer, entityId} =>
        inMemStore.sokosERC721_Transfer->InMemoryTable.Entity.set(
          Delete->Types.mkEntityUpdate(~eventIdentifier=rollBackEventIdentifier, ~entityId, ~shouldSaveHistory=false),
        )
      }
    })

    inMemStore
  }
}
