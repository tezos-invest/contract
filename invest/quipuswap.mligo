#if !QUIPUSWAP
#define QUIPUSWAP

type tez_to_token_param =
{
    min_out : nat;
    receiver: address;
}

type token_to_tez_param =
{
    amount: nat;
    min_out : nat;
    receiver: address;
}

let tez_to_token (pool_addr, amt, min_out, receiver : address * nat * nat * address) =
    let contract = match (Tezos.get_entrypoint_opt "%tezToTokenPayment" pool_addr : tez_to_token_param contract option) with
    | Some contract -> contract
    | None -> (failwith "The entrypoint does not exist" : tez_to_token_param contract) in
    Tezos.transaction { min_out = min_out; receiver = receiver } (amt * 1mutez) contract


let token_to_tez (pool_addr, amt, min_out, receiver : address * nat * nat * address) =
    let contract = match (Tezos.get_entrypoint_opt "%tokenToTezPayment" pool_addr : token_to_tez_param contract option) with
    | Some contract -> contract
    | None -> (failwith "The entrypoint does not exist" : token_to_tez_param contract) in
    Tezos.transaction { amount = amt; min_out = min_out; receiver = receiver } 0mutez contract

#endif
