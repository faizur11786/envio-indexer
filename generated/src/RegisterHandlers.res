@val external require: string => unit = "require"

let registerContractHandlers = (
  ~contractName,
  ~handlerPathRelativeToRoot,
  ~handlerPathRelativeToConfig,
) => {
  try {
    require("root/" ++ handlerPathRelativeToRoot)
  } catch {
  | exn =>
    let params = {
      "Contract Name": contractName,
      "Expected Handler Path": handlerPathRelativeToConfig,
      "Code": "EE500",
    }
    let logger = Logging.createChild(~params)

    let errHandler = exn->ErrorHandling.make(~msg="Failed to import handler file", ~logger)
    errHandler->ErrorHandling.log
    errHandler->ErrorHandling.raiseExn
  }
}

// TODO: Start using only config returned by registerAllHandlers instead of Config.getGenerated and Config.setGenerated
%%private(
  let chains = [
    {
      let contracts = [
        {
          Config.name: "Factory",
          abi: Abis.factoryAbi->Ethers.makeAbi,
          addresses: [
            "0xE1eB832df4FE2e15df1ac8777fAfC897866caB21"->Address.Evm.fromStringOrThrow
,
          ],
          events: [
            module(Types.Factory.CollectionDeployed),
          ],
        },
        {
          Config.name: "SokosERC721",
          abi: Abis.sokosERC721Abi->Ethers.makeAbi,
          addresses: [
          ],
          events: [
            module(Types.SokosERC721.Transfer),
          ],
        },
      ]
      let chain = ChainMap.Chain.makeUnsafe(~chainId=137)
      {
        Config.confirmedBlockThreshold: 200,
        syncSource: 
          HyperSync({endpointUrl: "https://polygon.hypersync.xyz"})
,
        startBlock: 0,
        endBlock:  None ,
        chain,
        contracts,
        chainWorker:
          module(HyperSyncWorker.Make({
            let chain = chain
            let contracts = contracts
            let endpointUrl = "https://polygon.hypersync.xyz"
            let allEventSignatures = Abis.EventSignatures.all
            /*
              Determines whether to use HypersyncClient Decoder or Viem for parsing events
              Default is hypersync client decoder, configurable in config with:
              ```yaml
              event_decoder: "viem" || "hypersync-client"
              ```
            */
            let shouldUseHypersyncClientDecoder = Env.Configurable.shouldUseHypersyncClientDecoder->Belt.Option.getWithDefault(
              true,
            )
          }))
      }
    },
  ]

  let config = Config.make(
    ~shouldRollbackOnReorg=true,
    ~shouldSaveFullHistory=false,
    ~isUnorderedMultichainMode=false,
    ~chains,
    ~enableRawEvents=false,
    ~entities=[
      module(Entities.Account),
      module(Entities.Collection),
      module(Entities.Factory_CollectionDeployed),
      module(Entities.Nft),
      module(Entities.SokosERC721_Transfer),
    ],
  )
  Config.setGenerated(config)
)

let registerAllHandlers = () => {
  registerContractHandlers(
    ~contractName="Factory",
    ~handlerPathRelativeToRoot="src/handlers/factory.ts",
    ~handlerPathRelativeToConfig="src/handlers/factory.ts",
  )
  registerContractHandlers(
    ~contractName="SokosERC721",
    ~handlerPathRelativeToRoot="src/handlers/sokos-erc721.ts",
    ~handlerPathRelativeToConfig="src/handlers/sokos-erc721.ts",
  )
  config
}
