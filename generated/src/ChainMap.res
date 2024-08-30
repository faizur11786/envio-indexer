open Belt

module Chain = {
  type t = Chain_137

  let all = [Chain_137]

  let toChainId = chain =>
    switch chain {
    | Chain_137 => 137
    }

  let toString = chain => chain->toChainId->Int.toString

  exception UndefinedChain(int)

  let fromChainId = chainId =>
    switch chainId {
    | 137 => Ok(Chain_137)
    | c => Error(UndefinedChain(c))
    }

  module ChainIdCmp = Belt.Id.MakeComparable({
    type t = t
    let cmp = (a, b) => Pervasives.compare(a->toChainId, b->toChainId)
  })
}

type t<'a> = Belt.Map.t<Chain.ChainIdCmp.t, 'a, Chain.ChainIdCmp.identity>

let make = (fn: Chain.t => 'a): t<'a> => {
  Chain.all
  ->Array.map(chainId => (chainId, chainId->fn))
  ->Map.fromArray(~id=module(Chain.ChainIdCmp))
}

exception NotAllChainsDefined
let fromArray: array<(Chain.t, 'a)> => result<t<'a>, exn> = arr => {
  let map = arr->Map.fromArray(~id=module(Chain.ChainIdCmp))
  let hasAllChains = Chain.all->Array.reduce(true, (accum, chain) => {
    accum && map->Map.has(chain)
  })
  if hasAllChains {
    Ok(map)
  } else {
    Error(NotAllChainsDefined)
  }
}

exception UnexpectedChainDoesNoteExist(int)
let get: (t<'a>, Chain.t) => 'a = (self, chain) =>
  //Can safely get exn since all chains must be set
  switch Map.get(self, chain) {
  | Some(v) => v
  | None => UnexpectedChainDoesNoteExist(chain->Chain.toChainId)->raise
  }

let set: (t<'a>, Chain.t, 'a) => t<'a> = Map.set
let values: t<'a> => array<'a> = Map.valuesToArray
let keys: t<'a> => array<Chain.t> = Map.keysToArray
let entries: t<'a> => array<(Chain.t, 'a)> = Map.toArray
let map: (t<'a>, 'a => 'b) => t<'b> = Map.map
let mapWithKey: (t<'a>, (Chain.t, 'a) => 'b) => t<'b> = Map.mapWithKey
let reduce: (t<'a>, 'b, (Chain.t, 'a, 'b) => 'b) => 'b = Map.reduce
let size: t<'a> => int = Map.size
let update: (t<'a>, Chain.t, 'a => 'a) => t<'a> = (map, chain, updateFn) =>
  Map.update(map, chain, opt => opt->Option.map(updateFn))
