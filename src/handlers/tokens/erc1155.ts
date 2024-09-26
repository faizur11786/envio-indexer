import { SokosERC1155, } from "generated";
import { processTokenMetadata } from "../../utils/ipfs";
import { ZeroAddress } from "ethers";





SokosERC1155.TransferSingle.handlerWithLoader({
    loader: async ({ event: { params, srcAddress }, context: { Accounts, Nfts } }) => {
        const sender = await Accounts.get(params.from.toString());
        const receiver = await Accounts.get(params.to.toString());
        const nft = await Nfts.get(`${srcAddress}-${params.id.toString()}`)
        return { sender, receiver, nft }
    },
    handler: async ({
        event: { params, block, chainId, srcAddress, },
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

        if (nft) {
            Nfts.set({
                ...nft,
                owner_id: params.to,
                supply: params.value.toString()
            });
        } else if (params.from === ZeroAddress) {
            //mint
            log.info(`Id ${params.id}, value ${params.value}, to ${params.to}, from ${params.from}, operator ${params.operator}`)

            const metadata = await processTokenMetadata(
                "ERC1155",
                chainId,
                srcAddress.toLowerCase(),
                params.id,
                log
            );

            Nfts.set({
                id: `${srcAddress}-${params.id.toString()}`,
                tokenId: params.id,
                owner_id: params.to,
                collection_id: srcAddress,
                ...metadata,
                description: JSON.stringify(metadata.description),
                attributes: JSON.stringify(metadata.attributes),
                isPhygital: Boolean(metadata.isPhygital),
                chainId: chainId,
                categories: metadata?.categories,
                standard: "ERC1155",
                supply: params.value.toString(),
            });
        }
    }
})