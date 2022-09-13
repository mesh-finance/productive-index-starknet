%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from lib.index_storage import MAX_FELT
from src.openzeppelin.access.ownable import Ownable
from starkware.cairo.common.math import assert_not_equal

//
// Storage
//

@storage_var
func indices(index: felt) -> (index_address: felt) {
}

@storage_var
func indices_len() -> (len: felt) {
}

//
// Constructor
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_owner: felt) {
    // Owner should be Index Factory
    Ownable.initializer(_owner);
    return ();
}

//
// View
//

@view
func get_index{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _index_id: felt
) -> (index_address: felt) {
    let (index_address) = indices.read(_index_id);
    return (index_address,);
}

@view
func get_next_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    index_id: felt
) {
    let (index_id) = indices_len.read();
    return (index_id,);
}

//
// Admin
//

@external
func add_index{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _index_address: felt
) -> (id: felt) {
    Ownable.assert_only_owner();

    let (len: felt) = indices_len.read();

    indices.write(len, _index_address);
    indices_len.write(len + 1);

    return (len,);
}
