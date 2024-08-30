// Graphql Enum Type Variants
type enumType<'a> = {
  name: string,
  variants: array<'a>,
}

let mkEnum = (~name, ~variants) => {
  name,
  variants,
}

module type Enum = {
  type variants
  let enum: enumType<variants>
}

module EventType = {
  type variants =
    | @as("Factory_CollectionDeployed") Factory_CollectionDeployed

    | @as("SokosERC721_Transfer") SokosERC721_Transfer

  let name = "EVENT_TYPE"
  let variants = [Factory_CollectionDeployed, SokosERC721_Transfer]
  let enum = mkEnum(~name, ~variants)
}

module ContractType = {
  type variants =
    | @as("Factory") Factory
    | @as("SokosERC721") SokosERC721
  let name = "CONTRACT_TYPE"
  let variants = [Factory, SokosERC721]
  let enum = mkEnum(~name, ~variants)
}

module EntityType = {
  type variants =
    | @as("Account") Account
    | @as("Collection") Collection
    | @as("Factory_CollectionDeployed") Factory_CollectionDeployed
    | @as("Nft") Nft
    | @as("SokosERC721_Transfer") SokosERC721_Transfer
  let name = "ENTITY_TYPE"
  let variants = [Account, Collection, Factory_CollectionDeployed, Nft, SokosERC721_Transfer]
  let enum = mkEnum(~name, ~variants)
}

let allEnums: array<module(Enum)> = [module(EventType), module(ContractType), module(EntityType)]
//todo move logic into above modules
// Graphql Enum Type Variants
