exception UndefinedEvent(string)
let eventStringToEvent = (eventName: string, contractName: string): Types.eventName => {
  switch (eventName, contractName) {
  | ("CollectionDeployed", "Factory") => Factory_CollectionDeployed
  | ("Transfer", "SokosERC721") => SokosERC721_Transfer
  | _ => UndefinedEvent(eventName)->raise
  }
}

module Factory = {
  let convertCollectionDeployedViemDecodedEvent: Viem.decodedEvent<'a> => Viem.decodedEvent<
    Types.FactoryContract.CollectionDeployedEvent.eventArgs,
  > = Obj.magic

  let convertCollectionDeployedLogDescription = (
    log: Ethers.logDescription<'a>,
  ): Ethers.logDescription<Types.FactoryContract.CollectionDeployedEvent.eventArgs> => {
    //Convert from the ethersLog type with indexs as keys to named key value object
    let ethersLog: Ethers.logDescription<
      Types.FactoryContract.CollectionDeployedEvent.ethersEventArgs,
    > =
      log->Obj.magic
    let {args, name, signature, topic} = ethersLog

    {
      name,
      signature,
      topic,
      args: {
        tokenAddress: args.tokenAddress,
        owner: args.owner,
        isERC1155: args.isERC1155,
        name: args.name,
        symbol: args.symbol,
        uri: args.uri,
      },
    }
  }

  let convertCollectionDeployedLog = (
    logDescription: Ethers.logDescription<Types.FactoryContract.CollectionDeployedEvent.eventArgs>,
    ~log: Ethers.log,
    ~blockTimestamp: int,
    ~chainId: int,
    ~txOrigin: option<Ethers.ethAddress>,
    ~txTo: option<Ethers.ethAddress>,
  ) => {
    let params: Types.FactoryContract.CollectionDeployedEvent.eventArgs = {
      tokenAddress: logDescription.args.tokenAddress,
      owner: logDescription.args.owner,
      isERC1155: logDescription.args.isERC1155,
      name: logDescription.args.name,
      symbol: logDescription.args.symbol,
      uri: logDescription.args.uri,
    }

    let collectionDeployedLog: Types.eventLog<
      Types.FactoryContract.CollectionDeployedEvent.eventArgs,
    > = {
      params,
      chainId,
      txOrigin,
      txTo,
      blockNumber: log.blockNumber,
      blockTimestamp,
      blockHash: log.blockHash,
      srcAddress: log.address,
      transactionHash: log.transactionHash,
      transactionIndex: log.transactionIndex,
      logIndex: log.logIndex,
    }

    Types.FactoryContract_CollectionDeployed(collectionDeployedLog)
  }
  let convertCollectionDeployedLogViem = (
    decodedEvent: Viem.decodedEvent<Types.FactoryContract.CollectionDeployedEvent.eventArgs>,
    ~log: Ethers.log,
    ~blockTimestamp: int,
    ~chainId: int,
    ~txOrigin: option<Ethers.ethAddress>,
    ~txTo: option<Ethers.ethAddress>,
  ) => {
    let params: Types.FactoryContract.CollectionDeployedEvent.eventArgs = {
      tokenAddress: decodedEvent.args.tokenAddress,
      owner: decodedEvent.args.owner,
      isERC1155: decodedEvent.args.isERC1155,
      name: decodedEvent.args.name,
      symbol: decodedEvent.args.symbol,
      uri: decodedEvent.args.uri,
    }

    let collectionDeployedLog: Types.eventLog<
      Types.FactoryContract.CollectionDeployedEvent.eventArgs,
    > = {
      params,
      chainId,
      txOrigin,
      txTo,
      blockNumber: log.blockNumber,
      blockTimestamp,
      blockHash: log.blockHash,
      srcAddress: log.address,
      transactionHash: log.transactionHash,
      transactionIndex: log.transactionIndex,
      logIndex: log.logIndex,
    }

    Types.FactoryContract_CollectionDeployed(collectionDeployedLog)
  }

  let convertCollectionDeployedDecodedEventParams = (
    decodedEvent: HyperSyncClient.Decoder.decodedEvent,
  ): Types.FactoryContract.CollectionDeployedEvent.eventArgs => {
    open Belt
    let fields = ["tokenAddress", "owner", "isERC1155", "name", "symbol", "uri"]
    let values =
      Array.concat(decodedEvent.indexed, decodedEvent.body)->Array.map(
        HyperSyncClient.Decoder.toUnderlying,
      )
    Array.zip(fields, values)->Js.Dict.fromArray->Obj.magic
  }
}

module SokosERC721 = {
  let convertTransferViemDecodedEvent: Viem.decodedEvent<'a> => Viem.decodedEvent<
    Types.SokosERC721Contract.TransferEvent.eventArgs,
  > = Obj.magic

  let convertTransferLogDescription = (log: Ethers.logDescription<'a>): Ethers.logDescription<
    Types.SokosERC721Contract.TransferEvent.eventArgs,
  > => {
    //Convert from the ethersLog type with indexs as keys to named key value object
    let ethersLog: Ethers.logDescription<Types.SokosERC721Contract.TransferEvent.ethersEventArgs> =
      log->Obj.magic
    let {args, name, signature, topic} = ethersLog

    {
      name,
      signature,
      topic,
      args: {
        from: args.from,
        to: args.to,
        tokenId: args.tokenId,
      },
    }
  }

  let convertTransferLog = (
    logDescription: Ethers.logDescription<Types.SokosERC721Contract.TransferEvent.eventArgs>,
    ~log: Ethers.log,
    ~blockTimestamp: int,
    ~chainId: int,
    ~txOrigin: option<Ethers.ethAddress>,
    ~txTo: option<Ethers.ethAddress>,
  ) => {
    let params: Types.SokosERC721Contract.TransferEvent.eventArgs = {
      from: logDescription.args.from,
      to: logDescription.args.to,
      tokenId: logDescription.args.tokenId,
    }

    let transferLog: Types.eventLog<Types.SokosERC721Contract.TransferEvent.eventArgs> = {
      params,
      chainId,
      txOrigin,
      txTo,
      blockNumber: log.blockNumber,
      blockTimestamp,
      blockHash: log.blockHash,
      srcAddress: log.address,
      transactionHash: log.transactionHash,
      transactionIndex: log.transactionIndex,
      logIndex: log.logIndex,
    }

    Types.SokosERC721Contract_Transfer(transferLog)
  }
  let convertTransferLogViem = (
    decodedEvent: Viem.decodedEvent<Types.SokosERC721Contract.TransferEvent.eventArgs>,
    ~log: Ethers.log,
    ~blockTimestamp: int,
    ~chainId: int,
    ~txOrigin: option<Ethers.ethAddress>,
    ~txTo: option<Ethers.ethAddress>,
  ) => {
    let params: Types.SokosERC721Contract.TransferEvent.eventArgs = {
      from: decodedEvent.args.from,
      to: decodedEvent.args.to,
      tokenId: decodedEvent.args.tokenId,
    }

    let transferLog: Types.eventLog<Types.SokosERC721Contract.TransferEvent.eventArgs> = {
      params,
      chainId,
      txOrigin,
      txTo,
      blockNumber: log.blockNumber,
      blockTimestamp,
      blockHash: log.blockHash,
      srcAddress: log.address,
      transactionHash: log.transactionHash,
      transactionIndex: log.transactionIndex,
      logIndex: log.logIndex,
    }

    Types.SokosERC721Contract_Transfer(transferLog)
  }

  let convertTransferDecodedEventParams = (
    decodedEvent: HyperSyncClient.Decoder.decodedEvent,
  ): Types.SokosERC721Contract.TransferEvent.eventArgs => {
    open Belt
    let fields = ["from", "to", "tokenId"]
    let values =
      Array.concat(decodedEvent.indexed, decodedEvent.body)->Array.map(
        HyperSyncClient.Decoder.toUnderlying,
      )
    Array.zip(fields, values)->Js.Dict.fromArray->Obj.magic
  }
}

exception ParseError(Ethers.Interface.parseLogError)
exception UnregisteredContract(Ethers.ethAddress)

let parseEventEthers = (
  ~log,
  ~blockTimestamp,
  ~contractInterfaceManager,
  ~chainId,
  ~txOrigin,
  ~txTo,
): Belt.Result.t<Types.event, _> => {
  let logDescriptionResult = contractInterfaceManager->ContractInterfaceManager.parseLogEthers(~log)
  switch logDescriptionResult {
  | Error(e) =>
    switch e {
    | ParseError(parseError) => ParseError(parseError)
    | UndefinedInterface(contractAddress) => UnregisteredContract(contractAddress)
    }->Error

  | Ok(logDescription) =>
    switch contractInterfaceManager->ContractInterfaceManager.getContractNameFromAddress(
      ~contractAddress=log.address,
    ) {
    | None => Error(UnregisteredContract(log.address))
    | Some(contractName) =>
      let event = switch eventStringToEvent(logDescription.name, contractName) {
      | Factory_CollectionDeployed =>
        logDescription
        ->Factory.convertCollectionDeployedLogDescription
        ->Factory.convertCollectionDeployedLog(~log, ~blockTimestamp, ~chainId, ~txOrigin, ~txTo)
      | SokosERC721_Transfer =>
        logDescription
        ->SokosERC721.convertTransferLogDescription
        ->SokosERC721.convertTransferLog(~log, ~blockTimestamp, ~chainId, ~txOrigin, ~txTo)
      }

      Ok(event)
    }
  }
}

let makeEventLog = (
  params: 'args,
  ~log: Ethers.log,
  ~blockTimestamp: int,
  ~chainId: int,
  ~txOrigin: option<Ethers.ethAddress>,
  ~txTo: option<Ethers.ethAddress>,
): Types.eventLog<'args> => {
  chainId,
  params,
  txOrigin,
  txTo,
  blockNumber: log.blockNumber,
  blockTimestamp,
  blockHash: log.blockHash,
  srcAddress: log.address,
  transactionHash: log.transactionHash,
  transactionIndex: log.transactionIndex,
  logIndex: log.logIndex,
}

let convertDecodedEvent = (
  event: HyperSyncClient.Decoder.decodedEvent,
  ~contractInterfaceManager,
  ~log: Ethers.log,
  ~blockTimestamp,
  ~chainId,
  ~txOrigin: option<Ethers.ethAddress>,
  ~txTo: option<Ethers.ethAddress>,
): result<Types.event, _> => {
  switch contractInterfaceManager->ContractInterfaceManager.getContractNameFromAddress(
    ~contractAddress=log.address,
  ) {
  | None => Error(UnregisteredContract(log.address))
  | Some(contractName) =>
    let event = switch Types.eventTopicToEventName(contractName, log.topics[0]) {
    | Factory_CollectionDeployed =>
      event
      ->Factory.convertCollectionDeployedDecodedEventParams
      ->makeEventLog(~log, ~blockTimestamp, ~chainId, ~txOrigin, ~txTo)
      ->Types.FactoryContract_CollectionDeployed
    | SokosERC721_Transfer =>
      event
      ->SokosERC721.convertTransferDecodedEventParams
      ->makeEventLog(~log, ~blockTimestamp, ~chainId, ~txOrigin, ~txTo)
      ->Types.SokosERC721Contract_Transfer
    }
    Ok(event)
  }
}

let parseEvent = (
  ~log,
  ~blockTimestamp,
  ~contractInterfaceManager,
  ~chainId,
  ~txOrigin,
  ~txTo,
): Belt.Result.t<Types.event, _> => {
  let decodedEventResult = contractInterfaceManager->ContractInterfaceManager.parseLogViem(~log)
  switch decodedEventResult {
  | Error(e) =>
    switch e {
    | ParseError(parseError) => ParseError(parseError)
    | UndefinedInterface(contractAddress) => UnregisteredContract(contractAddress)
    }->Error

  | Ok(decodedEvent) =>
    switch contractInterfaceManager->ContractInterfaceManager.getContractNameFromAddress(
      ~contractAddress=log.address,
    ) {
    | None => Error(UnregisteredContract(log.address))
    | Some(contractName) =>
      let event = switch eventStringToEvent(decodedEvent.eventName, contractName) {
      | Factory_CollectionDeployed =>
        decodedEvent
        ->Factory.convertCollectionDeployedViemDecodedEvent
        ->Factory.convertCollectionDeployedLogViem(
          ~log,
          ~blockTimestamp,
          ~chainId,
          ~txOrigin,
          ~txTo,
        )
      | SokosERC721_Transfer =>
        decodedEvent
        ->SokosERC721.convertTransferViemDecodedEvent
        ->SokosERC721.convertTransferLogViem(~log, ~blockTimestamp, ~chainId, ~txOrigin, ~txTo)
      }

      Ok(event)
    }
  }
}

let decodeRawEventWith = (
  rawEvent: Types.rawEventsEntity,
  ~schema: S.t<'a>,
  ~variantAccessor: Types.eventLog<'a> => Types.event,
  ~chain,
  ~txOrigin: option<Ethers.ethAddress>,
  ~txTo: option<Ethers.ethAddress>,
): result<Types.eventBatchQueueItem, S.error> => {
  rawEvent.params
  ->S.parseJsonStringWith(schema)
  ->Belt.Result.map(params => {
    let event = {
      chainId: rawEvent.chainId,
      txOrigin,
      txTo,
      blockNumber: rawEvent.blockNumber,
      blockTimestamp: rawEvent.blockTimestamp,
      blockHash: rawEvent.blockHash,
      srcAddress: rawEvent.srcAddress,
      transactionHash: rawEvent.transactionHash,
      transactionIndex: rawEvent.transactionIndex,
      logIndex: rawEvent.logIndex,
      params,
    }->variantAccessor

    let queueItem: Types.eventBatchQueueItem = {
      timestamp: rawEvent.blockTimestamp,
      chain,
      blockNumber: rawEvent.blockNumber,
      logIndex: rawEvent.logIndex,
      event,
    }

    queueItem
  })
}

let parseRawEvent = (
  rawEvent: Types.rawEventsEntity,
  ~chain,
  ~txOrigin: option<Ethers.ethAddress>,
  ~txTo: option<Ethers.ethAddress>,
): result<Types.eventBatchQueueItem, S.error> => {
  rawEvent.eventType
  ->S.parseWith(Types.eventNameSchema)
  ->Belt.Result.flatMap(eventName => {
    switch eventName {
    | Factory_CollectionDeployed =>
      rawEvent->decodeRawEventWith(
        ~schema=Types.FactoryContract.CollectionDeployedEvent.eventArgsSchema,
        ~variantAccessor=event => Types.FactoryContract_CollectionDeployed(event),
        ~chain,
        ~txOrigin,
        ~txTo,
      )
    | SokosERC721_Transfer =>
      rawEvent->decodeRawEventWith(
        ~schema=Types.SokosERC721Contract.TransferEvent.eventArgsSchema,
        ~variantAccessor=event => Types.SokosERC721Contract_Transfer(event),
        ~chain,
        ~txOrigin,
        ~txTo,
      )
    }
  })
}
