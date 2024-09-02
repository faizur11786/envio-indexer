require("dotenv").config();

import { Collection, Factory } from "generated";

export const LOG_LEVEL = "trace";

Factory.CollectionDeployed.contractRegister(({ event, context }) => {
  context.addSokosERC721(event.params.tokenAddress);
});

Factory.CollectionDeployed.handler(async ({ event, context }) => {
  const entity: Collection = {
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
