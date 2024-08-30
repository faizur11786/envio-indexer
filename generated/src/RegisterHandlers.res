@val external require: string => unit = "require"

let registerContractHandlers = (
  ~contractName,
  ~handlerPathRelativeToRoot,
  ~handlerPathRelativeToConfig,
) => {
  try {
    require("handlers/" ++ handlerPathRelativeToRoot)
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
}
