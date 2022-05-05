module T = struct

    type token_id = nat

    type token = 
      | Fa12 of address
      | Fa2 of (address * token_id)

    type symbol = string
    type weights = (symbol, nat) map
    type assets = (symbol, nat) map
    type prices = (symbol, nat) map
    type trades = (symbol * nat) list
    type pools = (symbol, address) map
    type balances = (symbol, nat) map
    type tokens = (symbol, token) map

    type side =
	| Buy
	| Sell

    type swap =
    [@layout:comb]
    {
	symbol : symbol;
	token : token;
	pool : address;
	side : side;
	amt : nat;
	min_out : nat;
	receiver : address;
    }

    type portfolio =
    [@layout:comb]
    {
	weights : weights;
	assets : assets;
	tokens : tokens;
    }

    type fa12_get_balance_param =
    [@layout:comb]
    {
	owner : address;
	callback : nat contract;
    }

    type fa2_balance_of_request =
    [@layout:comb]
    {
      owner : address;
      token_id : token_id;
    }

    type fa2_balance_of_response =
    [@layout:comb]
    {
      request : fa2_balance_of_request;
      balance : nat;
    }

    type fa2_balance_of_param =
    [@layout:comb]
    {
      requests : fa2_balance_of_request list;
      callback : (fa2_balance_of_response list) contract;
    }

    type operator_param =
    [@layout:comb]
    {
	owner : address;
	operator : address;
	token_id : nat;
    }

    type fa2_update_operators_param =
    | Add_operator of operator_param
    | Remove_operator of operator_param

    type fa2_update_operators_params = fa2_update_operators_param list

    type fa12_approve_params = 
    {
	spender : address;
	value : nat;
    }

    type create_portfolio_params =
    {
	weights : weights;
	tokens : tokens;
    }

    type rebalance_params =
    [@layout:comb]
    {
	prices : prices;
	pools : pools;
	slippage : nat;
    }

    type invest_entrypoints =
	| Create_portfolio of create_portfolio_params
	| Rebalance of rebalance_params
	| Withdraw of pools

    type callback_entrypoints =
	| Fa12_get_balance_callback of nat
	| Fa2_balance_of_callback of fa2_balance_of_response list

    type storage = {
	portfolios : (address, portfolio) big_map;
	balances : balances; 
	is_paused : bool; 
	pending_requests : (token, symbol) map; 
	withdrawal_address : address option; 
	pools : pools;
    }

end
