%lang starknet

from protostar.asserts import (assert_eq)
from starkware.cairo.common.cairo_builtins import HashBuiltin

@external
func __setup__{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}():
    alloc_locals

    local admin = 111813453203092678575228394645067365508785178229282836578911214210165801044
    local user1 = 222813453203092678575228394645067365508785178229282836578911214210165801044
    local user2 = 333813453203092678575228394645067365508785178229282836578911214210165801044

    #Generate Startegy_Module Hash
    local strategy_hash: felt
    %{
        declared = declare("./contracts/modules/strategy_module.cairo")
        prepared = prepare(declared, [])
        stop_prank_callable = start_prank(ids.admin, target_contract_address=prepared.contract_address)
        deploy(prepared)
        ids.strategy_hash = prepared.contract_address
        stop_prank_callable()
    %}

    return ()
end

@external
func test_factory{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}():
    alloc_locals

    local public_key_0 = 111813453203092678575228394645067365508785178229282836578911214210165801044

    
    %{ print("public_key_0: ",ids.public_key_0) %}

    return()
end