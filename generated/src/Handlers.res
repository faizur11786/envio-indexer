  @genType
module Factory = {
  module CollectionDeployed = RegisteredEvents.MakeRegister(Types.Factory.CollectionDeployed)
}

  @genType
module SokosERC721 = {
  module Transfer = RegisteredEvents.MakeRegister(Types.SokosERC721.Transfer)
}

