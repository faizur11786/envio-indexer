export type NftMetadata = {
  image: string;
  attributes: Array<any>;
  name: string;
  tokenUrl: string;
  description: string | Array<any>;
  isPhygital: boolean | string;
  standard: string;
  supply: string;
  categories: string[];
};
