import { NftEntity, SokosERC721Contract } from "generated";
import { processTokenMetadata, sleep } from "../lib";
import { tryFetchIpfsFile } from "../utils/ipfs";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

SokosERC721Contract.Transfer.loader(({ event, context }) => {
  context.Nft.load(
    `${event.srcAddress}-${event.params.tokenId.toString()}`,
    undefined
  );
  context.Account.load(event.params.to);
  context.Account.load(event.params.from);
});

SokosERC721Contract.Transfer.handler(async ({ event, context }) => {
  let senderAccount = await context.Account.get(event.params.from.toString());
  let receiverAccount = await context.Account.get(event.params.to.toString());

  if (!senderAccount && event.params.from != ZERO_ADDRESS) {
    context.Account.set({ id: event.params.from });
  }

  if (!receiverAccount && event.params.to != ZERO_ADDRESS) {
    context.Account.set({ id: event.params.to });
  }

  if (event.params.from === ZERO_ADDRESS) {
    // mint
    let metadata = await tryFetchIpfsFile(
      event.params.tokenId.toString(),
      context
    );

    const nft: NftEntity = {
      id: event.params.tokenId.toString(),
      owner_id: event.params.to,
      image: metadata.image,
      attributes: JSON.stringify(metadata.attributes),
      collection_id: event.srcAddress,
      metadata: JSON.stringify(metadata),
      tokenId: event.params.tokenId,
    };
    context.Nft.set(nft);
  } else {
    // transfer
    let nft = await context.Nft.get(event.params.tokenId.toString());
    if (!nft) {
      throw new Error("Can't transfer non-existing NFT");
    }
    nft = { ...nft, owner_id: event.params.to };
    context.Nft.set(nft);
  }

  // const existingToken = await context.Nft.get(
  //   `${event.srcAddress}-${event.params.tokenId.toString()}`
  // );

  // if (existingToken) {
  //   context.Nft.set({
  //     ...existingToken,
  //     owner_id: event.params.to,
  //   });
  // } else {
  //   await sleep(1000);
  //   const { data }: { data?: any } = await processTokenMetadata(
  //     event.srcAddress.toLowerCase(),
  //     event.params.tokenId
  //   );

  //   // context.log.info(JSON.stringify(data.metadata));

  //   context.Nft.set({
  //     id: `${event.srcAddress}-${event.params.tokenId.toString()}`,
  //     tokenId: event.params.tokenId,
  //     owner_id: event.params.to,
  //     collection_id: event.srcAddress,
  //     metadata: JSON.stringify({
  //       title: data?.metadata?.title || "NA",
  //       description: data?.metadata?.description || "NA",
  //       image: data?.metadata?.image?.url || "NA",
  //     }),
  //   });
  // }
});
