#if !MAIN
#define MAIN

#include "types.mligo"
#import "invest.mligo" "INVEST"
#import "admin.mligo" "ADMIN"


type entrypoints =
  | Invest of T.invest_entrypoints
  | Callback of T.callback_entrypoints
  | Admin of T.admin_entrypoints


let main(param, storage : entrypoints * T.storage) : (operation list) * T.storage =
  match param with
    | Invest p -> INVEST.main (p, storage)
    | Callback p -> INVEST.callback (p, storage)
    | Admin p -> ADMIN.main (p, storage)


#endif
