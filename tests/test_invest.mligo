#import "../invest/main.mligo" "INVEST"
#include "../invest/types.mligo"


let compare_maps (type a) (first, second : (a, nat) map * (a, nat) map) : bool =
    let compare_key (map : (a, nat) map) (res, (k, v) : bool * (a * nat)) =
        res && Option.unopt (Map.find_opt k map) = v in
    Map.fold (compare_key second) first true
    && Map.fold (compare_key first) second true


let initial_storage : T.storage = {
    admin = ("tz1LQjdKgiAsHkYMzBH2HFDcynf7QSd5Z4Eg" : address);
    pending_admin = (None : address option);
    portfolios = (Big_map.empty : (address, T.portfolio) big_map);
    balances = (Map.empty : T.balances); 
    is_paused = false;
    withdrawal_address = (None : address option);
    pending_requests = (Map.empty : (T.token, T.symbol) map);
    pools = (Map.empty : T.pools);
}


let test_create_portfolio =
    let (taddr, _, _) = Test.originate INVEST.main initial_storage 0tez in
    let contr = Test.to_contract taddr in

    let weights = Map.literal [("RCT", 25n); ("FA12", 10n); ("TS", 65n)] in
    let tokens = Map.literal [
        ("TS", Fa2 (("KT1CaWSNEnU6RR9ZMSSgD5tQtQDqdpw4sG83" : address), 0n));
	("RCT", Fa2 (("KT1QGgr6k1CDf4Svd18MtKNQukboz8JzRPd5" : address), 0n));
	("FA12", Fa12 ("KT1Dr8Qf9at75uEvwN4QnGTNFfPMAr8KL4kK": address));
    ] in

    let param = Invest (Create_portfolio { weights = weights ; tokens = tokens }) in
    let account = Test.nth_bootstrap_account 1 in
    let ok_case = Test.transfer_to_contract_exn contr param 0mutez in
    let storage = Test.get_storage taddr in
    let portfolio = Option.unopt (Big_map.find_opt account storage.portfolios) in

    let () = assert (compare_maps (portfolio.weights, weights) : bool) in

    let expected_assets = Map.map (fun (symbo, _ : T.symbol * nat) -> 0n) weights in
    let () = assert (compare_maps (portfolio.assets, expected_assets) : bool) in
    ()
