type functionRegister = Loader | Handler

let mapFunctionRegisterName = (functionRegister: functionRegister) => {
  switch functionRegister {
  | Loader => "Loader"
  | Handler => "Handler"
  }
}

// This set makes sure that the warning doesn't print for every event of a type, but rather only prints the first time.
let hasPrintedWarning = Set.make()

@genType
type handlerArgs<'event, 'context> = {
  event: Types.eventLog<'event>,
  context: 'context,
}

@genType
type handlerFunction<'eventArgs, 'context, 'returned> = handlerArgs<
  'eventArgs,
  'context,
> => 'returned

@genType
type handlerWithContextGetter<
  'eventArgs,
  'context,
  'returned,
  'loaderContext,
  'handlerContextSync,
  'handlerContextAsync,
> = {
  handler: handlerFunction<'eventArgs, 'context, 'returned>,
  contextGetter: Context.genericContextCreatorFunctions<
    'loaderContext,
    'handlerContextSync,
    'handlerContextAsync,
  > => 'context,
}

@genType
type handlerWithContextGetterSyncAsync<
  'eventArgs,
  'loaderContext,
  'handlerContextSync,
  'handlerContextAsync,
> = SyncAsync.t<
  handlerWithContextGetter<
    'eventArgs,
    'handlerContextSync,
    unit,
    'loaderContext,
    'handlerContextSync,
    'handlerContextAsync,
  >,
  handlerWithContextGetter<
    'eventArgs,
    'handlerContextAsync,
    promise<unit>,
    'loaderContext,
    'handlerContextSync,
    'handlerContextAsync,
  >,
>

@genType
type loader<'eventArgs, 'loaderContext> = handlerArgs<'eventArgs, 'loaderContext> => unit

let getDefaultLoaderHandler: (
  ~functionRegister: functionRegister,
  ~eventName: string,
  handlerArgs<'eventArgs, 'loaderContext>,
) => unit = (~functionRegister, ~eventName, _loaderArgs) => {
  let functionName = mapFunctionRegisterName(functionRegister)

  // Here we use this key to prevent flooding the users terminal with
  let repeatKey = `${eventName}-${functionName}`
  if !(hasPrintedWarning->Set.has(repeatKey)) {
    // Here are docs on the 'terminal hyperlink' formatting that I use to link to the docs: https://gist.github.com/egmontkob/eb114294efbcd5adb1944c9f3cb5feda
    Logging.warn(
      `Skipped ${eventName} in the ${functionName}, as there is no ${functionName} registered. You need to implement a ${eventName}${functionName} method in your handler file or ignore this warning if you don't intend to implement it. Here are our docs on this topic: \n\n https://docs.envio.dev/docs/event-handlers`,
    )
    let _ = hasPrintedWarning->Set.add(repeatKey)
  }
}

let getDefaultLoaderHandlerWithContextGetter = (~functionRegister, ~eventName) => SyncAsync.Sync({
  handler: getDefaultLoaderHandler(~functionRegister, ~eventName),
  contextGetter: ctx => ctx.getHandlerContextSync(),
})

module FactoryContract = {
  module CollectionDeployed = {
    open Types.FactoryContract.CollectionDeployedEvent

    type handlerWithContextGetter = handlerWithContextGetterSyncAsync<
      eventArgs,
      loaderContext,
      handlerContext,
      handlerContextAsync,
    >

    %%private(
      let collectionDeployedLoader: ref<option<loader<eventArgs, loaderContext>>> = ref(None)
      let collectionDeployedHandler: ref<option<handlerWithContextGetter>> = ref(None)
    )

    @genType
    let loader = loader => {
      collectionDeployedLoader := Some(loader)
    }

    @genType
    let handler = handler => {
      collectionDeployedHandler :=
        Some(Sync({handler, contextGetter: ctx => ctx.getHandlerContextSync()}))
    }

    // Silence the "this statement never returns (or has an unsound type.)" warning in the case that the user hasn't specified `isAsync` in their config file yet.
    @warning("-21") @genType
    let handlerAsync = handler => {
      Js.Exn.raiseError("Please add 'isAsync: true' to your config.yaml file to enable Async Mode.")

      collectionDeployedHandler :=
        Some(Async({handler, contextGetter: ctx => ctx.getHandlerContextAsync()}))
    }

    let getLoader = () =>
      collectionDeployedLoader.contents->Belt.Option.getWithDefault(
        getDefaultLoaderHandler(~eventName="CollectionDeployed", ~functionRegister=Loader),
      )

    let getHandler = () =>
      switch collectionDeployedHandler.contents {
      | Some(handler) => handler
      | None =>
        getDefaultLoaderHandlerWithContextGetter(
          ~eventName="CollectionDeployed",
          ~functionRegister=Handler,
        )
      }

    let handlerIsAsync = () => getHandler()->SyncAsync.isAsync
  }
}

module SokosERC721Contract = {
  module Transfer = {
    open Types.SokosERC721Contract.TransferEvent

    type handlerWithContextGetter = handlerWithContextGetterSyncAsync<
      eventArgs,
      loaderContext,
      handlerContext,
      handlerContextAsync,
    >

    %%private(
      let transferLoader: ref<option<loader<eventArgs, loaderContext>>> = ref(None)
      let transferHandler: ref<option<handlerWithContextGetter>> = ref(None)
    )

    @genType
    let loader = loader => {
      transferLoader := Some(loader)
    }

    @genType
    let handler = handler => {
      transferHandler := Some(Sync({handler, contextGetter: ctx => ctx.getHandlerContextSync()}))
    }

    // Silence the "this statement never returns (or has an unsound type.)" warning in the case that the user hasn't specified `isAsync` in their config file yet.
    @warning("-21") @genType
    let handlerAsync = handler => {
      transferHandler := Some(Async({handler, contextGetter: ctx => ctx.getHandlerContextAsync()}))
    }

    let getLoader = () =>
      transferLoader.contents->Belt.Option.getWithDefault(
        getDefaultLoaderHandler(~eventName="Transfer", ~functionRegister=Loader),
      )

    let getHandler = () =>
      switch transferHandler.contents {
      | Some(handler) => handler
      | None =>
        getDefaultLoaderHandlerWithContextGetter(~eventName="Transfer", ~functionRegister=Handler)
      }

    let handlerIsAsync = () => getHandler()->SyncAsync.isAsync
  }
}
