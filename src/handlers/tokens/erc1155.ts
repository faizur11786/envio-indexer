import { SokosERC1155, } from "generated";
import { processTokenMetadata } from "../../utils/ipfs";
import { ZeroAddress } from "ethers";





SokosERC1155.TransferSingle.handlerWithLoader({
    loader: async ({ event: { params: { from, to, } }, context: { Accounts } }) => {
        const sender = await Accounts.get(from.toString());
        const receiver = await Accounts.get(to.toString());
        return { sender, receiver }
    },
    handler: async ({
        event: { params: { from, to, id, operator, value }, block, chainId, srcAddress, },
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
                "ERC1155",
                chainId,
                srcAddress.toLowerCase(),
                id,
                log
            );

            Nfts.set({
                id: `${srcAddress}-${id.toString()}`,
                tokenId: id,
                collection_id: srcAddress,
                ...metadata,
                description: JSON.stringify(metadata.description),
                attributes: JSON.stringify(metadata.attributes),
                isPhygital: Boolean(metadata.isPhygital),
                chainId: chainId,
                categories: metadata?.categories,
                standard: "ERC1155",
                supply: value.toString(),
            });
        }

        Balances.set({
            id: `${to}-${from}-${srcAddress}-${id.toString()}-${value.toString()}`,
            collection_id: srcAddress,
            nft_id: `${srcAddress}-${id.toString()}`,
            quantity: value,
            chainId: chainId,
            account_id: to,
            from_id: from,
            timestamp: BigInt(block.timestamp),
        })

    }
})