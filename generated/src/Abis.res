module EventSignatures = {
let factory = [
    "CollectionDeployed(address indexed tokenAddress, address owner, bool isERC1155, string name, string symbol, string uri)",
  ]

let sokosERC721 = [
    "Transfer(address indexed from, address indexed to, uint256 indexed tokenId)",
  ]

let all = [
   factory,
   sokosERC721,
  ]->Belt.Array.concatMany
}

let
factoryAbi = `
[{"type":"event","name":"CollectionDeployed","inputs":[{"name":"tokenAddress","type":"address","indexed":true},{"name":"owner","type":"address","indexed":false},{"name":"isERC1155","type":"bool","indexed":false},{"name":"name","type":"string","indexed":false},{"name":"symbol","type":"string","indexed":false},{"name":"uri","type":"string","indexed":false}],"anonymous":false}]
`->Js.Json.parseExn
let
sokosERC721Abi = `
[{"type":"event","name":"Transfer","inputs":[{"name":"from","type":"address","indexed":true},{"name":"to","type":"address","indexed":true},{"name":"tokenId","type":"uint256","indexed":true}],"anonymous":false}]
`->Js.Json.parseExn
