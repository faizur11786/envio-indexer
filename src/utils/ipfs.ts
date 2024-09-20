import { NftMetadata } from "./types";
import { NftCache } from "./cache";
import { userLogger } from "generated/src/Logs.gen";
import QueryString from "qs";

async function fetchFromEndpoint(
  tokenAddress: string,
  tokenId: string,
  logger: userLogger
): Promise<NftMetadata | null> {
  try {
    const url = new URL("/api/nfts", process.env.SOKOS_CONSOLE_URL);

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
      { addQueryPrefix: true }
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
  tokenAddress: string,
  tokenId: BigInt,
  logger: userLogger
): Promise<NftMetadata> => {
  const cache = await NftCache.init();
  const _metadata = await cache.read(`${tokenAddress}-${tokenId.toString()}`);
  if (_metadata) {
    return { ..._metadata };
  }

  const metadata = await fetchFromEndpoint(
    tokenAddress,
    tokenId.toString(),
    logger
  );

  if (metadata) {
    await cache.add(`${tokenAddress}-${tokenId.toString()}`, metadata);
    return metadata;
  }

  return {
    image: "unknown",
    name: "unknown",
    tokenUrl: "unknown",
    description: "unknown",
    attributes: ["unknown"],
    isPhygital: "unknown",
    standard: "unknown",
    supply: "unknown",
    categories: "unknown",
  };
};
