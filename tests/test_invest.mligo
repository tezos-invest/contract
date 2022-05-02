#import "../options/main.mligo" "OPTIONS"
#include "../options/types.mligo"


let initial_storage : T.storage = {}


let assert_error_msg (res : test_exec_result) (expected : string) : unit =
    let expected = Test.eval expected in
    match res with
        | Fail (Rejected (actual, _)) -> 
            let cond = (Test.michelson_equal actual expected) in
            assert_with_error cond "Wrong error message"
        | Fail (Other) -> failwith "Contract failed for an unknown reason"
        | Success _ -> failwith "No error message"


let test_one = ()
