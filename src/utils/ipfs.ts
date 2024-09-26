import { NftMetadata } from "./types";
import { NftCache } from "./cache";
import { userLogger } from "generated/src/Logs.gen";
import QueryString from "qs";
import { Contract, JsonRpcProvider } from "ethers";


import ERC721ABI from "../abis/sokos-erc721.json"
import ERC1155ABI from "../abis/sokos-erc1155.json"



async function fetchFromEndpoint(
  tokenAddress: string,
  tokenId: BigInt,
  chainId: number,
  logger: userLogger
): Promise<NftMetadata | null> {
  try {
    const baseUrl = chainId === 137 ? "https://console.sokos.io" : "https://dev-console.sokos.io"

    const url = new URL("/api/nfts", baseUrl);

    const query = {
      and: [
        {
          tokenId: { equals: tokenId.toString() },
          and: [{ "token.address": { equals: tokenAddress } }],
        },
      ],
    };

    const stringifiedQuery = QueryString.stringify(
      { where: query, depth: 5 },
      { addQueryPrefix: true, encodeValuesOnly: true }
    );
    const fullUrl = `${url.toString()}${stringifiedQuery}`;
    const response = await fetch(fullUrl);

    const data = (await response.json()) as any;

    if (!data.totalDocs) throw new Error("no data found for token " + data);

    const fullNft = data.docs[0]


    const categories: string[] = fullNft?.token?.categories?.map((category: { slug: string }) => category.slug) || [];


    const metadata: NftMetadata = {
      image: fullNft.metadata.image.url,
      name: fullNft.metadata.title,
      tokenUrl: fullNft.metadata.uri,
      description: fullNft.metadata.description,
      attributes: fullNft.metadata.attributes,
      isPhygital: fullNft.metadata.isPhygital,
      standard: fullNft.token.standard,
      supply: fullNft.supply,
      categories: categories.join(",")
    };
    return metadata;
  } catch (e) {
    logger.warn(`Unable to fetch metadata of ${tokenAddress}-${tokenId}`);
  }
  return null;
}

export const processTokenMetadata = async (
  standard: "ERC721" | "ERC1155",
  chainId: number,
  tokenAddress: string,
  tokenId: BigInt,
  logger: userLogger
): Promise<NftMetadata> => {

  const cache = await NftCache.init();

  if (process.env.NODE_ENV !== "development") {
    const _metadata = await cache.read(`${tokenAddress}-${tokenId.toString()}`);
    if (_metadata) {
      return { ..._metadata };
    }
  }

  const metadata = await fetchFromEndpoint(
    tokenAddress,
    tokenId,
    chainId,
    logger
  );



  if (metadata) {
    if (process.env.NODE_ENV !== "development") {
      await cache.add(`${tokenAddress}-${tokenId.toString()}`, metadata);
    }
    return metadata;
  }


  const tokenMetadata = await fetchFromIpfs(standard, tokenId, tokenAddress, chainId, logger)

  return {
    image: tokenMetadata?.image || "unknown",
    name: tokenMetadata?.name || "unknown",
    tokenUrl: "unknown",
    description: tokenMetadata?.description || "unknown",
    attributes: ["unknown"],
    isPhygital: "unknown",
    standard: "unknown",
    supply: "unknown",
    categories: "unknown",
  };
};


const fetchFromIpfs = async (standard: "ERC721" | "ERC1155", tokenId: BigInt, tokenAddress: string, chainId: number, logger: userLogger) => {


  const endpoints = ["https://copper-rear-hippopotamus-746.mypinata.cloud"]

  const rpcURL = chainId === 137 ? "https://polygon.llamarpc.com" : "https://eth-holesky.g.alchemy.com/v2/FBiYlSGgCsGdMw0cF8xoj5R1JJk0Yyb6"


  const provider = new JsonRpcProvider(rpcURL)
  const contract = new Contract(tokenAddress, standard === "ERC721" ? ERC721ABI : ERC1155ABI, provider)

  const func = standard === "ERC721" ? "tokenURI" : "getTokenURI"

  const uri = await contract[func](tokenId);

  for (let i = 0; i < endpoints.length; i++) {
    const endpoint = endpoints[i]
    const url = new URL(`/ipfs/${uri.split("://")[1]}`, endpoint)
    const response = await fetch(url.toString())

    if (!response.ok) continue

    const data = (await response.json()) as any;
    if (!data.name) continue

    type Metadata = {
      image: NftMetadata["image"]
      name: NftMetadata["name"]
      description: NftMetadata["description"]
    }
    const metadata: Metadata = {
      image: `${endpoint}/ipfs/${data.image.split("://")[1]}`,
      name: data.name,
      description: data.description,
    }
    return metadata
  }
  return null
}
