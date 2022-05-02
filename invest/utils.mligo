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



#endif
