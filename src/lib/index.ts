import qs from "qs";

export const processTokenMetadata = async (
  tokenAddress: string,
  tokenId: BigInt
) => {
  const url = new URL("/api/nfts", "https://console.sokos.io");

  const query = {
    and: [
      {
        tokenId: { equals: tokenId.toString() },
        and: [{ "token.address": { equals: tokenAddress } }],
      },
    ],
  };

  const stringifiedQuery = qs.stringify(
    { where: query },
    { addQueryPrefix: true }
  );

  try {
    const res = await fetch(`${url.toString()}${stringifiedQuery}`);
    const data = (await res.json()) as any;
    return { data: data.docs[0] };
  } catch (error) {
    console.log(error);
    return { error };
  }
};

export const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
