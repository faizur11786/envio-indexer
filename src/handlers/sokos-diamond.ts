require("dotenv").config();

import { Collections, Markets, SokosDiamond } from "generated";
import { ERC1155Addresses } from "../utils/types";

export const LOG_LEVEL = "trace";

SokosDiamond.CollectionDeployed.contractRegister(({ event, context }) => {
  if (event.params.isERC1155) {
    context.addSokosERC1155(event.params.tokenAddress);
  } else {
    context.addSokosERC721(event.params.tokenAddress);
  }

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


SokosDiamond.ListingAdd.handlerWithLoader({
  loader: async ({ event, context }) => {
    const { tokenAddress, tokenId, } = event.params
    const nft = await context.Nfts.get(
      `${tokenAddress}-${tokenId.toString()}`
    );
    return { nft }
  },
  handler: async ({ event, context, loaderReturn }) => {
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
    context.Markets.set(entity);
    const { nft } = loaderReturn
    if (nft) context.Nfts.set({ ...nft })
  }
})



// SokosDiamond.BuyWithFiat.handlerWithLoader({
//   loader: async ({ event, context }) => {

//   },
//   handler: async ({ event, context }) => {
//     const { params } = event


//   }
// })