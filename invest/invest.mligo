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


let create_portfolio(weights, storage : T.weights * T.storage) =
    let () = assert_with_error (not Big_map.mem Tezos.sender storage.portfolios) "Portfolio already exists" in
    let () = assert_with_error (validate_weights weights) "Invalid weights" in

    let assets = Map.map (fun (_ : T.symbol * nat) -> 0n) weights in
    let portfolio = { weights = weights; assets = assets } in
    ([] : operation list), {
	storage with
	portfolios = Big_map.add Tezos.sender portfolio storage.portfolios
    }


let get_assets_value (assets, prices : T.assets * T.prices) : nat =
    let get_price = UTILS.get_val prices in
    Map.fold
	(fun (acc, (symbol, amt) : nat * (T.symbol * nat)) ->
	    acc + (get_price symbol) * amt)
	assets
	0n


let allocate (weights, prices, total : T.weights * T.prices * nat) : T.assets =
    Map.map
	(fun (symbol, weight : T.symbol * nat) ->
	    let price = UTILS.get_val prices symbol in
	    let amt = ((weight * total) / 100n) / price in
	    amt)
	weights


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


let make_sell_swaps (sells, prices, pools, slippage : T.trades * T.prices * T.pools * nat) : T.swap list =
    let make_swap (symbol, amt : T.symbol * nat) =
	let price = UTILS.get_val prices symbol in
	let pool_addr = UTILS.get_val pools symbol in
	let min_out = UTILS.to_nat ((amt * price) * (1000n - slippage) / 1000n) in
	{ symbol = symbol; pool = pool_addr; side = Sell; amt = amt; min_out = min_out } in

    List.map make_swap sells


let make_buy_swaps (buys, tz_limit, prices, pools, slippage : T.trades * nat * T.prices * T.pools * nat) : T.swap list =
    let make_swap ((tz_limit, swaps), (symbol, amt) : (nat * T.swap list) * (T.symbol * nat)) =
	let price = UTILS.get_val prices symbol in
	let pool_addr = UTILS.get_val pools symbol in
	let amt, tz_amt =
	    if amt * price < tz_limit
	    then amt, amt * price
	    else tz_limit / price, tz_limit in
	let min_out = UTILS.to_nat (amt * (1000n - slippage) / 1000n) in
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


let rebalance(prices, pools, slippage, storage : T.prices * T.pools * nat * T.storage) =
    let portfolio = match Big_map.find_opt Tezos.sender storage.portfolios with
    | None -> failwith "Portfolio not found"
    | Some value -> value in
    let assets_value = get_assets_value (portfolio.assets, prices) in
    let desired_assets = allocate (portfolio.weights, prices, assets_value + (Tezos.amount / 1mutez)) in
    let sells, buys = calculate_trades (portfolio.assets, desired_assets) in
    let sell_swaps = make_sell_swaps (sells, prices, pools, slippage) in
    let min_tz_out = List.fold (fun (acc, el : nat * T.swap) -> acc + el.min_out) sell_swaps 0n in
    let tz_limit = Tezos.amount / 1mutez + min_tz_out in
    let buy_swaps = make_buy_swaps (buys, tz_limit, prices, pools, slippage) in
    let all_swaps = UTILS.concat (sell_swaps, buy_swaps) in
    let balances = update_balances (all_swaps, storage.balances) in
    let assets = update_balances (all_swaps, portfolio.assets) in
    let portfolio = { portfolio with assets = assets } in
    let ops = do_swaps all_swaps in
    ops, { 
	storage with
	balances = balances;
	portfolios = Big_map.add Tezos.sender portfolio storage.portfolios
    }


let main(param, storage : T.invest_entrypoints * T.storage) =
    match param with
    | Create_portfolio weights -> create_portfolio (weights, storage)
    | Rebalance { prices; pools; slippage } -> rebalance (prices, pools, slippage, storage)


(*
let assets = Map.literal [("BTC", 1250n); ("ETH", 2700n); ("XTZ", 550n)]
let prices = Map.literal [("BTC", 35000n); ("ETH", 2000n); ("XTZ", 4n)]
let prices2 = Map.literal [("BTC", 25000n); ("ETH", 2500n); ("XTZ", 5n)]
let weights = Map.literal [("BTC", 34n); ("ETH", 33n); ("XTZ", 33n)]
let assets = allocate (weights, prices, 100000000n)
let assets2 = allocate (weights, prices2, 100000000n)
let sells, buys = calculate_trades (assets, assets2)
let pools = Map.literal [
    ("BTC", ("KT1PMQZxQTrFPJn3pEaj9rvGfJA9Hvx7Z1CL" : address));
    ("ETH", ("KT1PMQZxQTrFPJn3pEaj9rvGfJA9Hvx7Z1CL" : address));
    ("XTZ", ("KT1PMQZxQTrFPJn3pEaj9rvGfJA9Hvx7Z1CL" : address));
]
let sell_swaps = make_sell_swaps (sells, prices, pools)
let buy_swaps = make_buy_swaps (buys, 20000000n, prices, pools)
*)


#endif
