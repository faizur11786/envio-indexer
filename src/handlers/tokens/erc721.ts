import { SokosERC721 } from "generated";
import { processTokenMetadata } from "../../utils/ipfs";
import { ZeroAddress } from "ethers";



SokosERC721.Transfer.handlerWithLoader({
    loader: async ({ event: { params }, context: { Accounts, } }) => {
        const sender = await Accounts.get(params.from.toString());
        const receiver = await Accounts.get(params.to.toString());
        return { sender, receiver }
    },
    handler: async ({
        event: { params: { from, to, tokenId }, block, chainId, srcAddress },
        context: { Accounts, log, Nfts, Balances },
        loaderReturn
    }) => {
        const { sender, receiver } = loaderReturn

        if (!sender) {
            Accounts.set({ id: from.toString() })
        }

        if (!receiver) {
            Accounts.set({ id: to.toString() })
        }
        if (from === ZeroAddress) {
            //mint
            const metadata = await processTokenMetadata(
                "ERC721",
                chainId,
                srcAddress.toLowerCase(),
                tokenId,
                log
            );

            Nfts.set({
                id: `${srcAddress}-${tokenId.toString()}`,
                tokenId: tokenId,
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

        }

        Balances.set({
            id: `${to}-${from}-${srcAddress}-${tokenId.toString()}-${1}`,
            collection_id: srcAddress,
            nft_id: `${srcAddress}-${tokenId.toString()}`,
            quantity: BigInt(1),
            chainId: chainId,
            account_id: to,
            from_id: from,
            timestamp: BigInt(block.timestamp),
        })

    }
})