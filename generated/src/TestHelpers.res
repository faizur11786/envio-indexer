/***** TAKE NOTE ******
This is a hack to get genType to work!

In order for genType to produce recursive types, it needs to be at the 
root module of a file. If it's defined in a nested module it does not 
work. So all the MockDb types and internal functions are defined in TestHelpers_MockDb
and only public functions are recreated and exported from this module.

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

module MockDb = {
  @genType
  let createMockDb = TestHelpers_MockDb.createMockDb
}

@genType
module Addresses = {
  include TestHelpers_MockAddresses
}


module EventFunctions = {
  /**
  The arguements that get passed to a "processEvent" helper function
  */
  //Note these are made into a record to make operate in the same way
  //for Res, JS and TS.
  @genType
  type eventProcessorArgs<'eventArgs> = {
    event: Types.eventLog<'eventArgs>,
    mockDb: TestHelpers_MockDb.t,
    chainId?: int,
  }

  /**
  A function composer to help create individual processEvent functions
  */
  let makeEventProcessor = (
    ~eventMod: module(Types.Event with type eventArgs = 'eventArgs),
  ) => {
    async (args) => {
      let eventMod = eventMod->Types.eventModToInternal
      let {event, mockDb, ?chainId} = args->(Utils.magic: eventProcessorArgs<'eventArgs> => eventProcessorArgs<Types.internalEventArgs>)
      let module(Event) = eventMod
      let config = RegisterHandlers.registerAllHandlers()

      // The user can specify a chainId of an event or leave it off
      // and it will default to the first chain in the config
      let chain = switch chainId {
        | Some(chainId) => {
          config->Config.getChain(~chainId)
        }
        | None => switch config.defaultChain {
          | Some(chainConfig) => chainConfig.chain
          | None => Js.Exn.raiseError("No default chain Id found, please add at least 1 chain to your config.yaml")
        }
      }

      //Create an individual logging context for traceability
      let logger = Logging.createChild(
        ~params={
          "Context": `Test Processor for "${Event.name}" event on contract "${Event.contractName}"`,
          "Chain ID": chain->ChainMap.Chain.toChainId,
          "event": event,
        },
      )

      //Deep copy the data in mockDb, mutate the clone and return the clone
      //So no side effects occur here and state can be compared between process
      //steps
      let mockDbClone = mockDb->TestHelpers_MockDb.cloneMockDb

      let registeredEvent = switch RegisteredEvents.global->RegisteredEvents.get(eventMod) {
      | Some(l) => l
      | None =>
        Not_found->ErrorHandling.mkLogAndRaise(
          ~logger,
          ~msg=`No registered handler found for "${Event.name}" on contract "${Event.contractName}"`,
        )
      }
      //Construct a new instance of an in memory store to run for the given event
      let inMemoryStore = InMemoryStore.make()
      let loadLayer = LoadLayer.make(
        ~loadEntitiesByIds=TestHelpers_MockDb.makeLoadEntitiesByIds(mockDbClone),
        ~makeLoadEntitiesByField=(~entityMod) => TestHelpers_MockDb.makeLoadEntitiesByField(mockDbClone, ~entityMod),
      )

      //No need to check contract is registered or return anything.
      //The only purpose is to test the registerContract function and to
      //add the entity to the in memory store for asserting registrations

      switch registeredEvent.contractRegister {
      | Some(contractRegister) =>
        switch contractRegister->EventProcessing.runEventContractRegister(
          ~logger,
          ~event,
          ~eventBatchQueueItem={
            event,
            eventMod,
            chain,
            logIndex: event.logIndex,
            timestamp: event.block.timestamp,
            blockNumber: event.block.number,
          },
          ~checkContractIsRegistered=(~chain as _, ~contractAddress as _, ~contractName as _) =>
            false,
          ~dynamicContractRegistrations=None,
          ~inMemoryStore,
        ) {
        | Ok(_) => ()
        | Error(e) => e->ErrorHandling.logAndRaise
        }
      | None => () //No need to run contract registration
      }

      let latestProcessedBlocks = EventProcessing.EventsProcessed.makeEmpty(~config)

      switch registeredEvent.loaderHandler {
      | Some(handler) =>
        switch await event->EventProcessing.runEventHandler(
          ~inMemoryStore,
          ~loadLayer,
          ~handler,
          ~eventMod,
          ~chain,
          ~logger,
          ~latestProcessedBlocks,
          ~config,
        ) {
        | Ok(_) => ()
        | Error(e) => e->ErrorHandling.logAndRaise
        }
      | None => ()//No need to run loaders or handlers
      }

      //In mem store can still contatin raw events and dynamic contracts for the
      //testing framework in cases where either contract register or loaderHandler
      //is None
      mockDbClone->TestHelpers_MockDb.writeFromMemoryStore(~inMemoryStore)
      mockDbClone
    }
  }

  module MockBlock = {
    open Belt
    type t = {
      number?: int,
      timestamp?: int,
      hash?: string,
    }

    let toBlock = (mock: t): Types.Block.t => {
      number: mock.number->Option.getWithDefault(0),
      timestamp: mock.timestamp->Option.getWithDefault(0),
      hash: mock.hash->Option.getWithDefault("foo"),
    }
  }

  module MockTransaction = {
    type t = {
    }

    let toTransaction = (_mock: t): Types.Transaction.t => {
    }
  }

  @genType
  type mockEventData = {
    chainId?: int,
    srcAddress?: Address.t,
    logIndex?: int,
    block?: MockBlock.t,
    transaction?: MockTransaction.t,
  }

  /**
  Applies optional paramters with defaults for all common eventLog field
  */
  let makeEventMocker = (
    ~params: 'eventParams,
    ~mockEventData: option<mockEventData>,
  ): Types.eventLog<'eventParams> => {
    let {?block, ?transaction, ?srcAddress, ?chainId, ?logIndex} =
      mockEventData->Belt.Option.getWithDefault({})
    let block = block->Belt.Option.getWithDefault({})->MockBlock.toBlock
    let transaction = transaction->Belt.Option.getWithDefault({})->MockTransaction.toTransaction
    {
      params,
      transaction,
      chainId: chainId->Belt.Option.getWithDefault(1),
      block,
      srcAddress: srcAddress->Belt.Option.getWithDefault(Addresses.defaultAddress),
      logIndex: logIndex->Belt.Option.getWithDefault(0),
    }
  }
}


module Factory = {
  module CollectionDeployed = {
    @genType
    let processEvent = EventFunctions.makeEventProcessor(
      ~eventMod=module(Types.Factory.CollectionDeployed),
    )

    @genType
    type createMockArgs = {
      @as("tokenAddress")
      tokenAddress?: Address.t,
      @as("owner")
      owner?: Address.t,
      @as("isERC1155")
      isERC1155?: bool,
      @as("name")
      name?: string,
      @as("symbol")
      symbol?: string,
      @as("uri")
      uri?: string,
      mockEventData?: EventFunctions.mockEventData,
    }

    @genType
    let createMockEvent = args => {
      let {
        ?tokenAddress,
        ?owner,
        ?isERC1155,
        ?name,
        ?symbol,
        ?uri,
        ?mockEventData,
      } = args

      let params: Types.Factory.CollectionDeployed.eventArgs = 
      {
       tokenAddress: tokenAddress->Belt.Option.getWithDefault(TestHelpers_MockAddresses.defaultAddress),
       owner: owner->Belt.Option.getWithDefault(TestHelpers_MockAddresses.defaultAddress),
       isERC1155: isERC1155->Belt.Option.getWithDefault(false),
       name: name->Belt.Option.getWithDefault("foo"),
       symbol: symbol->Belt.Option.getWithDefault("foo"),
       uri: uri->Belt.Option.getWithDefault("foo"),
      }

      EventFunctions.makeEventMocker(~params, ~mockEventData)
    }
  }

}


module SokosERC721 = {
  module Transfer = {
    @genType
    let processEvent = EventFunctions.makeEventProcessor(
      ~eventMod=module(Types.SokosERC721.Transfer),
    )

    @genType
    type createMockArgs = {
      @as("from")
      from?: Address.t,
      @as("to")
      to?: Address.t,
      @as("tokenId")
      tokenId?: bigint,
      mockEventData?: EventFunctions.mockEventData,
    }

    @genType
    let createMockEvent = args => {
      let {
        ?from,
        ?to,
        ?tokenId,
        ?mockEventData,
      } = args

      let params: Types.SokosERC721.Transfer.eventArgs = 
      {
       from: from->Belt.Option.getWithDefault(TestHelpers_MockAddresses.defaultAddress),
       to: to->Belt.Option.getWithDefault(TestHelpers_MockAddresses.defaultAddress),
       tokenId: tokenId->Belt.Option.getWithDefault(0n),
      }

      EventFunctions.makeEventMocker(~params, ~mockEventData)
    }
  }

}

