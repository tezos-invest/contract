#if !INVEST
#define INVEST

#include "types.mligo"
#import "utils.mligo" "UTILS"
#import "quipuswap.mligo" "QUIPU"


let validate_weights (weights : T.weights) : bool =
    let total = Map.fold
	(fun (acc, (_, v) : nat * (T.symbol * nat)) -> acc + v)
	weights
	0n in
    total = 100n


let get_assets_value (assets, prices : T.assets * T.prices) : nat =
    let get_price = UTILS.get_val prices in
    Map.fold
	(fun (acc, (symbol, amt) : nat * (T.symbol * nat)) ->
	    acc + (get_price symbol) * amt)
	assets
	0n


let allocate (weights, total : T.weights * nat) : T.assets =
    let allocate_one ((remainder, assets), (symbol, fraction) : (nat * T.assets) * (T.symbol * nat)) =
	let is_last = int (Map.size assets) = (int (Map.size weights) - 1) in
	let amt = if is_last then remainder else (fraction * total) / 100n in
	let remainder = match is_nat (remainder - amt) with
	| None -> failwith ("Invalid amount: " ^ symbol)
	| Some value -> value in
	remainder, (Map.add symbol amt assets) in

    let assets = (Map.empty : T.assets) in
    let (remainder, assets) = Map.fold allocate_one weights (total, assets) in
    let () = assert (remainder = 0n) in
    assets


let create_portfolio(weights, storage : T.weights * T.storage) =
    let () = assert_with_error (not Big_map.mem Tezos.sender storage.portfolios) "Portfolio already exists" in
    let () = assert_with_error (validate_weights weights) "Invalid weights" in

    let assets = Map.map (fun (_ : T.symbol * nat) -> 0n) weights in
    let portfolio = { weights = weights; assets = assets } in
    let portfolios = Map.add Tezos.sender portfolio storage.portfolios in
    ([] : operation list), { storage with portfolios = portfolios }


let calculate_trades (old_assets, new_assets : T.assets * T.assets) =
    let add_symbol = fun (symbols, (s, _) : T.symbol set * (T.symbol * nat)) -> Set.add s symbols in
    let symbols = Map.fold add_symbol old_assets (Set.empty : T.symbol set) in
    let symbols = Map.fold add_symbol new_assets symbols in

    let sells, buys = (([], []) : T.trades * T.trades) in

    let add_trade ((sells, buys), symbol : (T.trades * T.trades) * T.symbol) =
	match (Map.find_opt symbol old_assets, Map.find_opt symbol new_assets) with
	| (Some old_value, None) -> (symbol, old_value) :: sells, buys
	| (None, Some new_value) -> sells, (symbol, new_value) :: buys
	| (Some old_value, Some new_value) ->
	    if new_value > old_value
	    then sells, (symbol, UTILS.to_nat (new_value - old_value)) :: buys
	    else if old_value > new_value
	    then (symbol, UTILS.to_nat (old_value - new_value)) :: sells, buys
	    else sells, buys
	| (None, None) -> failwith "Unexpected error" in

    Set.fold add_trade symbols (sells, buys)


let slippage = 5n (* 0.5% *)

let make_sell_swaps (sells, prices, pools : T.trades * T.prices * T.pools) : T.swap list =
    let make_swap (symbol, amt : T.symbol * nat) =
	let price = UTILS.get_val prices symbol in
	let pool_addr = UTILS.get_val pools symbol in
	let min_out = UTILS.to_nat ((amt * price) * (1000n - slippage) / 1000n) in
	{ symbol = symbol; pool = pool_addr; side = Sell; amt = amt; min_out = min_out } in

    List.map make_swap sells


let make_buy_swaps (buys, tz_limit, prices, pools : T.trades * nat * T.prices * T.pools) : T.swap list =
    let make_swap ((tz_limit, swaps), (symbol, amt) : (nat * T.swap list) * (T.symbol * nat)) =
	let price = UTILS.get_val prices symbol in
	let pool_addr = UTILS.get_val pools symbol in
	let min_out = UTILS.to_nat (amt * (1000n - slippage) / 1000n) in
	let tz_amt = 
	    if amt * price < tz_limit
	    then amt * price
	    else tz_limit in
	let swap = { symbol = symbol; pool = pool_addr; side = Buy; amt = tz_amt; min_out = min_out } in
	(UTILS.to_nat (tz_limit - tz_amt), swap :: swaps) in

    let _, swaps = List.fold make_swap buys (tz_limit, ([] : T.swap list)) in
    swaps


let do_swaps (swaps : T.swap list) : operation list =
    List.map
	(fun (swap : T.swap) ->
	    let fn = match swap.side with
	    | Sell -> QUIPU.token_to_tez
	    | Buy -> QUIPU.tez_to_token in
	    fn (swap.pool, swap.amt, swap.min_out, Tezos.self_address))
	swaps


let update_balances (swaps, balances : T.swap list * T.balances) =
    List.fold
	(fun (balances, swap : T.balances * T.swap) ->
	    let old_amt = match Map.find_opt swap.symbol balances with
	    | Some value -> value
	    | None -> 0n in
	    let new_amt = match swap.side with
	    | Buy -> old_amt + swap.min_out
	    | Sell -> UTILS.to_nat (old_amt - swap.min_out) in
	    Map.add swap.symbol new_amt balances)
	swaps
	balances


let rebalance(prices, storage : T.prices * T.storage) =
    let portfolio = match Map.find_opt Tezos.sender storage.portfolios with
    | None -> failwith "Portfolio not found"
    | Some value -> value in
    let value = get_assets_value (portfolio.assets, prices) in
    let desired_assets = allocate (portfolio.weights, value + (Tezos.amount / 1mutez)) in
    let sells, buys = calculate_trades (portfolio.assets, desired_assets) in
    let sell_swaps = make_sell_swaps (sells, prices, storage.pools) in
    let min_tz_out = List.fold (fun (acc, el : nat * T.swap) -> acc + el.min_out) sell_swaps 0n in
    let tz_limit = Tezos.amount / 1mutez + min_tz_out in
    let buy_swaps = make_buy_swaps (buys, tz_limit, prices, storage.pools) in
    let all_swaps = UTILS.concat (sell_swaps, buy_swaps) in
    let balances = update_balances (all_swaps, storage.balances) in
    let assets = update_balances (all_swaps, portfolio.assets) in
    let ops = do_swaps all_swaps in
    ops, storage


let main(param, storage : T.invest_entrypoints * T.storage) =
    match param with
    | Create_portfolio weights -> create_portfolio (weights, storage)
    | Rebalance prices -> rebalance (prices, storage)


#endif
