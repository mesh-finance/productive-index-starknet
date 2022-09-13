%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.openzeppelin.access.ownable import Ownable

// MANDATORY MODULES
// 1 ERC20

// OPTIONAL MODULES
// 1 Strategies
// 2 Re-balancing
// 3 Index re-allocation

@storage_var
func index_to_module_hash(index: felt) -> (hash: felt) {
}

//
// Views
//

@view
func get_module_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _index: felt
) -> (strategy_hash: felt) {
    let (hash: felt) = index_to_module_hash.read(_index);
    return (hash,);
}

//
// Admin
//

@external
func set_module_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _index: felt, _hash: felt
) -> () {
    Ownable.assert_only_owner();
    index_to_module_hash.write(_index, _hash);
    return ();
}
