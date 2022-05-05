#if !UTILS
#define UTILS

#include "types.mligo"


let get_val (type a) (map : (T.symbol, a) map) (key : T.symbol) =
    match Map.find_opt key map with
    | None -> failwith ("Unknown key: " ^ key)
    | Some value -> value


let to_nat (value : int) : nat =
    match is_nat value with
    | Some value -> value
    | None -> failwith "Not a nat"


let rec concat (type a) (xs, ys : a list * a list) : a list =
    match xs with
    | x :: xs -> concat (xs, x :: ys)
    | [] -> ys


let query_balance (token, owner : T.token * address) =
    match token with
    | Fa12 addr -> 
        let callback = Option.unopt
            (Tezos.get_entrypoint_opt "%fa12_get_balance_callback" Tezos.self_address : nat contract option) in 
        let contract = Option.unopt
            (Tezos.get_entrypoint_opt "%getBalance" addr : T.fa12_get_balance_param contract option) in
        Tezos.transaction { owner = owner ; callback = callback } 0mutez contract
    | Fa2 (addr, token_id) ->
        let callback = Option.unopt
            (Tezos.get_entrypoint_opt "%fa2_balance_of_callback" Tezos.self_address : T.fa2_balance_of_response list contract option) in 
        let contract = Option.unopt
            (Tezos.get_entrypoint_opt "%balance_of" addr : T.fa2_balance_of_param contract option) in
        Tezos.transaction { requests = [{ owner = owner ; token_id = token_id }] ; callback = callback } 0mutez contract


let add_operator (token_addr, token_id, owner, operator : address * nat * address * address) =
    let contract = Option.unopt
        (Tezos.get_entrypoint_opt "%update_operators" token_addr : T.fa2_update_operators_params contract option) in
    Tezos.transaction [Add_operator { owner = owner ; operator = operator ; token_id = token_id }] 0mutez contract


let remove_operator (token_addr, token_id, owner, operator : address * nat * address * address) =
    let contract = Option.unopt
        (Tezos.get_entrypoint_opt "%update_operators" token_addr : T.fa2_update_operators_params contract option) in
    Tezos.transaction [Remove_operator { owner = owner ; operator = operator ; token_id = token_id }] 0mutez contract


let approve (token_addr, spender, value : address * address * nat) =
    let contract = Option.unopt
        (Tezos.get_entrypoint_opt "%approve" token_addr : T.fa12_approve_params contract option) in
    Tezos.transaction { spender = spender ; value = value } 0mutez contract


let transfer_tz (amt, to : tez * address) =
    let to_contract : unit contract =
        match (Tezos.get_contract_opt to : unit contract option) with
	    | None -> (failwith "Invalid contract" : unit contract)
	    | Some c -> c in
    Tezos.transaction () amt to_contract


#endif
