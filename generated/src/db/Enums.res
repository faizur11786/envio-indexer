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
  type t
  let enum: enumType<t>
}

module ContractType = {
  @genType
  type t = 
    | @as("Factory") Factory
    | @as("SokosERC721") SokosERC721

  let schema = 
    S.union([
      S.literal(Factory), 
      S.literal(SokosERC721), 
    ])

  let name = "CONTRACT_TYPE"
  let variants = [
    Factory,
    SokosERC721,
  ]
  let enum = mkEnum(~name, ~variants)
}

module EntityType = {
  @genType
  type t = 
    | @as("Account") Account
    | @as("Collection") Collection
    | @as("Factory_CollectionDeployed") Factory_CollectionDeployed
    | @as("Nft") Nft
    | @as("SokosERC721_Transfer") SokosERC721_Transfer

  let schema = S.union([
    S.literal(Account), 
    S.literal(Collection), 
    S.literal(Factory_CollectionDeployed), 
    S.literal(Nft), 
    S.literal(SokosERC721_Transfer), 
  ])

  let name = "ENTITY_TYPE"
  let variants = [
    Account,
    Collection,
    Factory_CollectionDeployed,
    Nft,
    SokosERC721_Transfer,
  ]

  let enum = mkEnum(~name, ~variants)
}


let allEnums: array<module(Enum)> = [
  module(ContractType), 
  module(EntityType),
]
