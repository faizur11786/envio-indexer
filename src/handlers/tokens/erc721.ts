import { SokosERC721 } from "generated";
import { processTokenMetadata } from "../../utils/ipfs";
import { ZeroAddress } from "ethers";



SokosERC721.Transfer.handlerWithLoader({
    loader: async ({ event: { params, srcAddress }, context: { Accounts, Nfts } }) => {
        const sender = await Accounts.get(params.from.toString());
        const receiver = await Accounts.get(params.to.toString());
        const nft = await Nfts.get(`${srcAddress}-${params.tokenId.toString()}`)

        return { sender, receiver, nft }
    },
    handler: async ({
        event: { params, block, chainId, srcAddress, transaction },
        context: { Accounts, log, Nfts },
        loaderReturn
    }) => {
        const { sender, receiver, nft } = loaderReturn

        if (!sender) {
            Accounts.set({ id: params.from.toString() })
        }

        if (!receiver) {
            Accounts.set({ id: params.to.toString() })
        }
        if (params.from === ZeroAddress) {
            //mint
            const metadata = await processTokenMetadata(
                "ERC721",
                chainId,
                srcAddress.toLowerCase(),
                params.tokenId,
                log
            );

            Nfts.set({
                id: `${srcAddress}-${params.tokenId.toString()}`,
                tokenId: params.tokenId,
                owner_id: params.to,
                collection_id: srcAddress,
                ...metadata,
                description: JSON.stringify(metadata.description),
                attributes: JSON.stringify(metadata.attributes),
                isPhygital: Boolean(metadata.isPhygital),
                chainId: chainId,
                categories: metadata?.categories,
                standard: "ERC721",
                supply: "1",
            });
        } else {
            // transfer
            if (!nft) {
                throw new Error("Can't transfer non-existing NFT");
            }
            Nfts.set({ ...nft, owner_id: params.to });
        }

    }
})