#import "../invest/main.mligo" "INVEST"
#include "../invest/types.mligo"




let initial_storage : T.storage = {
    portfolios = (Big_map.empty : (address, T.portfolio) big_map);
    balances = (Map.empty : T.balances); 
}


let compare_maps (type a) (first, second : (a, nat) map * (a, nat) map) : bool =
    let compare_key (map : (a, nat) map) (res, (k, v) : bool * (a * nat)) =
	res && Option.unopt (Map.find_opt k map) = v in
    Map.fold (compare_key second) first true
    && Map.fold (compare_key first) second true


let test_one =
    let (taddr, _, _) = Test.originate INVEST.main initial_storage 0tez in
    let contr = Test.to_contract taddr in

    let weights = Map.literal [("BTC", 34n); ("ETH", 33n); ("XTZ", 33n)] in
    let param = Invest (Create_portfolio weights) in
    let account = Test.nth_bootstrap_account 1 in
    let ok_case = Test.transfer_to_contract_exn contr param 0mutez in
    let storage = Test.get_storage taddr in
    let portfolio = Option.unopt (Big_map.find_opt account storage.portfolios) in
    let () = assert (compare_maps (portfolio.weights, weights) : bool) in
    ()
