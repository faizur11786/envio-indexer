require("dotenv").config();

import { Collections, Markets, Orders, SokosDiamond } from "generated";
import { ERC1155Addresses } from "../utils/types";
import { register } from "module";

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
  loader: async () => {
    return {}
  },
  handler: async ({ event, context }) => {
    const { listingId, seller, tokenAddress, tokenId, quantity, priceInUsd, timestamp } = event.params

    const entity: Markets = {
      id: listingId.toString(),
      seller_id: seller,
      nft_id: `${tokenAddress}-${tokenId.toString()}`,
      isActive: true,
      priceInUsd: priceInUsd,
      quantity: quantity,
      timestamp: timestamp,
      chainId: event.chainId,
      soldQuantity: BigInt(0)
    };
    context.Markets.set(entity);
  }
})



SokosDiamond.BuyWithFiat.handlerWithLoader({
  loader: async ({ event, context }) => {
    const { params: { listingId } } = event

    const market = await context.Markets.get(listingId.toString())
    return { market }
  },
  handler: async ({ event, context, loaderReturn }) => {
    const { market } = loaderReturn

    const { params, chainId } = event
    const listingId = params.listingId.toString()

    const order: Orders = {
      id: `${params.seller}-${params.buyer}-${listingId}`,
      chainId: chainId,
      to_id: params.buyer,
      from_id: params.seller,
      nft_id: `${params.tokenAddress}-${params.tokenId}`,
      market_id: listingId,
      amount: params.paidAmount,
      currency: params.currency,
      method: "card",
      quantity: params.bugthQuantity,
      timestamp: params.timestamp
    }

    context.Orders.set(order)

    if (!market) return

    const soldQuantity = BigInt(market.soldQuantity) + BigInt(params.bugthQuantity)

    context.Markets.set({
      ...market,
      soldQuantity,
      isActive: soldQuantity < market.quantity
    })
  }
})