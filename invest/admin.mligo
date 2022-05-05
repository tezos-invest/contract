#if !ADMIN
#define ADMIN

#include "types.mligo"
#import "utils.mligo" "UTILS"

let confirm_new_admin (storage : T.storage) =
    match storage.pending_admin with
    | None -> (failwith "NO_PENDING_ADMIN" : T.storage)
    | Some pending ->
	  if Tezos.sender = pending
	  then { 
	    storage with
	    pending_admin = (None : address option);
	    admin = Tezos.sender;
	  }
	  else (failwith "NOT_A_PENDING_ADMIN" : T.storage)
  

let is_admin (storage : T.storage) =
    Tezos.sender = storage.admin


let set_admin (new_admin, storage : address * T.storage) =
    let () = assert (is_admin storage) in
    { storage with pending_admin = Some new_admin }
    

let pause (is_paused, storage : bool * T.storage) =
    let () = assert (is_admin storage) in
    { storage with is_paused = is_paused }


let main(param, storage : T.admin_entrypoints * T.storage) =
    match param with
    | Set_admin new_admin ->
	  let storage = set_admin (new_admin, storage) in
	  ([] : operation list), storage

    | Confirm_admin _ ->
	  let storage = confirm_new_admin storage in
	  ([]: operation list), storage

    | Pause is_paused ->
	  let storage = pause (is_paused, storage) in
	  ([]: operation list), storage

    | Set_delegate baker ->
	let () = assert (is_admin storage) in
	[Tezos.set_delegate baker], storage
	
    | Withdraw_rewards addr ->
	let () = assert (is_admin storage) in
	[UTILS.transfer_tz (Tezos.balance, addr)], storage

#endif
