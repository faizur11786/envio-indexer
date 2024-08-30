type contract = {
  name: string,
  abi: Ethers.abi,
  addresses: array<Ethers.ethAddress>,
  events: array<Types.eventName>,
}

type syncConfig = {
  initialBlockInterval: int,
  backoffMultiplicative: float,
  accelerationAdditive: int,
  intervalCeiling: int,
  backoffMillis: int,
  queryTimeoutMillis: int,
}

type serverUrl = string

type rpcConfig = {
  provider: Ethers.JsonRpcProvider.t,
  syncConfig: syncConfig,
}

/**
A generic type where for different values of HyperSync and Rpc.
Where first param 'a represents the value for hypersync and the second
param 'b for rpc
*/
type source<'a, 'b> = HyperSync('a) | Rpc('b)

type syncSource = source<serverUrl, rpcConfig>

type chainConfig = {
  syncSource: syncSource,
  startBlock: int,
  endBlock: option<int>,
  confirmedBlockThreshold: int,
  chain: ChainMap.Chain.t,
  contracts: array<contract>,
}

type chainConfigs = ChainMap.t<chainConfig>

type historyFlag = FullHistory | MinHistory
type rollbackFlag = RollbackOnReorg | NoRollback
type historyConfig = {rollbackFlag: rollbackFlag, historyFlag: historyFlag}

let makeHistoryConfig = (~shouldRollbackOnReorg, ~shouldSaveFullHistory) => {
  rollbackFlag: shouldRollbackOnReorg ? RollbackOnReorg : NoRollback,
  historyFlag: shouldSaveFullHistory ? FullHistory : MinHistory,
}

let historyConfig = makeHistoryConfig(~shouldRollbackOnReorg=false, ~shouldSaveFullHistory=false)

let shouldRollbackOnReorg = switch historyConfig {
| {rollbackFlag: RollbackOnReorg} => true
| _ => false
}

let shouldSaveHistory = switch historyConfig {
| {rollbackFlag: RollbackOnReorg} | {historyFlag: FullHistory} => true
| _ => false
}

let shouldPruneHistory = switch historyConfig {
| {historyFlag: MinHistory} => true
| _ => false
}

/**
Determines whether to use HypersyncClient Decoder or Viem for parsing events
Default is hypersync client decoder, configurable in config with:
```yaml
event_decoder: "viem" || "hypersync-client"
```
*/
let shouldUseHypersyncClientDecoder =
  Env.Configurable.shouldUseHypersyncClientDecoder->Belt.Option.getWithDefault(true)

let isUnorderedMultichainMode =
  Env.Configurable.isUnorderedMultichainMode->Belt.Option.getWithDefault(
    Env.Configurable.unstable__temp_unordered_head_mode->Belt.Option.getWithDefault(false),
  )

let db: Postgres.poolConfig = {
  host: Env.Db.host,
  port: Env.Db.port,
  username: Env.Db.user,
  password: Env.Db.password,
  database: Env.Db.database,
  ssl: Env.Db.ssl,
  // TODO: think how we want to pipe these logs to pino.
  onnotice: ?(Env.userLogLevel == #warn || Env.userLogLevel == #error ? None : Some(_str => ())),
  transform: {undefined: Null},
  max: 2,
}

let getSyncConfig = ({
  initialBlockInterval,
  backoffMultiplicative,
  accelerationAdditive,
  intervalCeiling,
  backoffMillis,
  queryTimeoutMillis,
}) => {
  initialBlockInterval: Env.Configurable.SyncConfig.initialBlockInterval->Belt.Option.getWithDefault(
    initialBlockInterval,
  ),
  // After an RPC error, how much to scale back the number of blocks requested at once
  backoffMultiplicative: Env.Configurable.SyncConfig.backoffMultiplicative->Belt.Option.getWithDefault(
    backoffMultiplicative,
  ),
  // Without RPC errors or timeouts, how much to increase the number of blocks requested by for the next batch
  accelerationAdditive: Env.Configurable.SyncConfig.accelerationAdditive->Belt.Option.getWithDefault(
    accelerationAdditive,
  ),
  // Do not further increase the block interval past this limit
  intervalCeiling: Env.Configurable.SyncConfig.intervalCeiling->Belt.Option.getWithDefault(
    intervalCeiling,
  ),
  // After an error, how long to wait before retrying
  backoffMillis,
  // How long to wait before cancelling an RPC request
  queryTimeoutMillis,
}

let getConfig = (chain: ChainMap.Chain.t) =>
  switch chain {
  | Chain_137 => {
      confirmedBlockThreshold: 200,
      syncSource: HyperSync("https://polygon.hypersync.xyz"),
      startBlock: 0,
      endBlock: None,
      chain: Chain_137,
      contracts: [
        {
          name: "Factory",
          abi: Abis.factoryAbi->Ethers.makeAbi,
          addresses: [
            "0xE1eB832df4FE2e15df1ac8777fAfC897866caB21"->Ethers.getAddressFromStringUnsafe,
          ],
          events: [Factory_CollectionDeployed],
        },
        {
          name: "SokosERC721",
          abi: Abis.sokosERC721Abi->Ethers.makeAbi,
          addresses: [],
          events: [SokosERC721_Transfer],
        },
      ],
    }
  }

let config: chainConfigs = ChainMap.make(getConfig)
