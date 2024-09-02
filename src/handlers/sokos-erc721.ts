import { SokosERC721 } from "generated";
import { processTokenMetadata } from "../utils/ipfs";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

// SokosERC721Contract.Transfer.loader(({ event, context }) => {
//   context.Nft.load(
//     `${event.srcAddress}-${event.params.tokenId.toString()}`,
//     undefined
//   );
//   context.Account.load(event.params.to);
//   context.Account.load(event.params.from);
// });

SokosERC721.Transfer.handler(async ({ event, context }) => {
  let senderAccount = await context.Account.get(event.params.from.toString());
  let receiverAccount = await context.Account.get(event.params.to.toString());

  if (!senderAccount && event.params.from != ZERO_ADDRESS) {
    context.Account.set({ id: event.params.from });
  }

  if (!receiverAccount && event.params.to != ZERO_ADDRESS) {
    context.Account.set({ id: event.params.to });
  }

  if (event.params.from === ZERO_ADDRESS) {
    //mint
    const metadata = await processTokenMetadata(
      event.srcAddress.toLowerCase(),
      event.params.tokenId,
      context.log
    );

    context.Nft.set({
      id: `${event.srcAddress}-${event.params.tokenId.toString()}`,
      tokenId: event.params.tokenId,
      owner_id: event.params.to,
      collection_id: event.srcAddress,
      ...metadata,
      description: JSON.stringify(metadata.description),
      attributes: JSON.stringify(metadata.attributes),
      isPhygital: Boolean(metadata.isPhygital),
    });
  } else {
    // transfer
    const nft = await context.Nft.get(
      `${event.srcAddress}-${event.params.tokenId.toString()}`
    );
    if (!nft) {
      throw new Error("Can't transfer non-existing NFT");
    }
    context.Nft.set({ ...nft, owner_id: event.params.to });
  }
});
