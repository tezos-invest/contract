module T = struct

    type symbol = string
    type weights = (symbol, nat) map
    type assets = (symbol, nat) map
    type prices = (symbol, nat) map
    type trades = (symbol * nat) list
    type pools = (symbol, address) map
    type balances = (symbol, nat) map

    type side =
	| Buy
	| Sell

    type swap =
    [@layout:comb]
    {
	symbol : symbol;
	pool : address;
	side : side;
	amt : nat;
	min_out : nat;
    }

    type portfolio =
    [@layout:comb]
    {
	weights : weights;
	assets : assets;
    }

    type rebalance_params =
    [@layout:comb]
    {
	prices : prices;
	pools : pools;
	slippage : nat;
    }

    type invest_entrypoints =
	| Create_portfolio of weights
	| Rebalance of rebalance_params

    type storage = {
	portfolios : (address, portfolio) big_map;
	balances : balances; 
    }

end
