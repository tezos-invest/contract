#if !MAIN
#define MAIN

#include "types.mligo"
#import "invest.mligo" "INVEST"

type entrypoints =
  | Invest of T.invest_entrypoints


let main(param, storage : entrypoints * T.storage) : (operation list) * T.storage =
  match param with
    | Invest p -> INVEST.main (p, storage)


#endif
