import { CollectionEntity, FactoryContract } from "generated";

export const LOG_LEVEL = "trace";

FactoryContract.CollectionDeployed.loader(({ event, context }) => {
  context.contractRegistration.addSokosERC721(event.params.tokenAddress);
});

FactoryContract.CollectionDeployed.handler(({ event, context }) => {
  const entity: CollectionEntity = {
    id: event.params.tokenAddress,
    contractAddress: event.params.tokenAddress,
    isERC1155: event.params.isERC1155,
    name: event.params.name,
    symbol: event.params.symbol,
    uri: event.params.uri,
    owner_id: event.params.owner,
  };
  context.Collection.set(entity);
});
