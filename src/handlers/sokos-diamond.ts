require("dotenv").config();

import { Collections, Markets, SokosDiamond } from "generated";

export const LOG_LEVEL = "trace";

SokosDiamond.CollectionDeployed.contractRegister(({ event, context }) => {
  context.addSokosERC721(event.params.tokenAddress);
});

SokosDiamond.CollectionDeployed.handler(async ({ event, context }) => {

  const { params } = event

  const entity: Collections = {
    id: params.tokenAddress,
    contractAddress: params.tokenAddress,
    isERC1155: params.isERC1155,
    name: params.name,
    symbol: params.symbol,
    uri: params.uri,
    owner_id: params.owner,
    chainId: event.chainId
  };
  context.Collections.set(entity);
});



SokosDiamond.ListingAdd.handler(async ({ event, context }) => {
  const { listingId, seller, tokenAddress, tokenId, quantity, priceInUsd, timestamp } = event.params






  const entity: Markets = {
    id: listingId.toString(),
    seller_id: seller,
    nft_id: `${tokenAddress}-${tokenId.toString()}`,
    isActive: true,
    priceInUsd: priceInUsd,
    quantity: quantity,
    timestamp: timestamp,
    chainId: event.chainId
  };

  // transfer
  const nft = await context.Nfts.get(
    `${tokenAddress}-${tokenId.toString()}`
  );

  if (!nft) {
    throw new Error("Can't transfer non-existing NFT");
  }

  context.Nfts.set({ ...nft, market_id: entity.id })
  context.Markets.set(entity);

});