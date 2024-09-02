
@genType
type rawEventsKey = {
  chainId: int,
  eventId: string,
}

let hashRawEventsKey = (key: rawEventsKey) =>
  EventUtils.getEventIdKeyString(~chainId=key.chainId, ~eventId=key.eventId)

@genType
type dynamicContractRegistryKey = {
  chainId: int,
  contractAddress: Address.t,
}

let hashDynamicContractRegistryKey = ({chainId, contractAddress}) =>
  EventUtils.getContractAddressKeyString(~chainId, ~contractAddress)

type t = {
  eventSyncState: InMemoryTable.t<int, TablesStatic.EventSyncState.t>,
  rawEvents: InMemoryTable.t<rawEventsKey, TablesStatic.RawEvents.t>,
  dynamicContractRegistry: InMemoryTable.t<
    dynamicContractRegistryKey,
    TablesStatic.DynamicContractRegistry.t,
  >,
  @as("Account") 
  account: InMemoryTable.Entity.t<Entities.Account.t>,
  @as("Collection") 
  collection: InMemoryTable.Entity.t<Entities.Collection.t>,
  @as("Factory_CollectionDeployed") 
  factory_CollectionDeployed: InMemoryTable.Entity.t<Entities.Factory_CollectionDeployed.t>,
  @as("Nft") 
  nft: InMemoryTable.Entity.t<Entities.Nft.t>,
  @as("SokosERC721_Transfer") 
  sokosERC721_Transfer: InMemoryTable.Entity.t<Entities.SokosERC721_Transfer.t>,
  rollBackEventIdentifier: option<Types.eventIdentifier>,
}

let makeWithRollBackEventIdentifier = (rollBackEventIdentifier): t => {
  eventSyncState: InMemoryTable.make(~hash=v => v->Belt.Int.toString),
  rawEvents: InMemoryTable.make(~hash=hashRawEventsKey),
  dynamicContractRegistry: InMemoryTable.make(~hash=hashDynamicContractRegistryKey),
  account: InMemoryTable.Entity.make(),
  collection: InMemoryTable.Entity.make(),
  factory_CollectionDeployed: InMemoryTable.Entity.make(),
  nft: InMemoryTable.Entity.make(),
  sokosERC721_Transfer: InMemoryTable.Entity.make(),
  rollBackEventIdentifier,
}

let make = () => makeWithRollBackEventIdentifier(None)

let clone = (self: t) => {
  eventSyncState: self.eventSyncState->InMemoryTable.clone,
  rawEvents: self.rawEvents->InMemoryTable.clone,
  dynamicContractRegistry: self.dynamicContractRegistry->InMemoryTable.clone,
  account: self.account->InMemoryTable.Entity.clone,
  collection: self.collection->InMemoryTable.Entity.clone,
  factory_CollectionDeployed: self.factory_CollectionDeployed->InMemoryTable.Entity.clone,
  nft: self.nft->InMemoryTable.Entity.clone,
  sokosERC721_Transfer: self.sokosERC721_Transfer->InMemoryTable.Entity.clone,
  rollBackEventIdentifier: self.rollBackEventIdentifier->InMemoryTable.structuredClone,
}


let getInMemTable = (
  type entity,
  inMemoryStore: t,
  ~entityMod: module(Entities.Entity with type t = entity),
): InMemoryTable.Entity.t<entity> => {
  let module(Entity) = entityMod->Entities.entityModToInternal
  inMemoryStore->Utils.magic->Js.Dict.unsafeGet(Entity.key)
}
