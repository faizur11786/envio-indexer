export type NftMetadata = {
  image: string;
  attributes: Array<any>;
  name: string;
  tokenUrl: string;
  description: string | Array<any>;
  isPhygital: boolean | string;
  standard: string;
  supply: string;
  categories: string;
};
export const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";


export const ERC1155Addresses = [
  "0xb93128f9d96220CfdDa87e3f93849172eEcd9565",
  "0x2b1Cb9e1Aa602FB40b36478d121258b667572350", "0x57623a911471456c016109da1d7e43eaf647363b", "0x98d1249e21c9adC70726AD705e177612c900953f"
]