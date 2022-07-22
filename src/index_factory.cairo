%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, deploy
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from lib.ownable import Ownable

@storage_var
func salt() -> (value : felt):
end

@storage_var
func index_hash() -> (hash : felt):
end

#
# Constructor
#

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (owner) = get_caller_address()
    Ownable.initializer(owner)
    return ()
end

#
# Externals
#


@external
func create_index{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        _name: felt,
        _symbol: felt,
        _assets_len: felt,
        _assets: felt*,
        _amounts_len: felt, 
        _amounts: felt*,
        _module_hashes_len: felt, 
        _module_hashes: felt*, 
        _selectors_len: felt, 
        _selectors: felt*
    ) -> (new_index_address: felt):
    alloc_locals

    #Get Caller Address
    let (caller_address) = get_caller_address()

    let(class_hash) = index_hash.read()
    let (current_salt) = salt.read()

    let (calldata: felt*) = alloc()

    #Packing all calldata information into 1 felt pointer
    assert calldata[0] = _name
    assert calldata[1] = _symbol
    assert calldata[2] = caller_address
    assert calldata[3] = _assets_len
    memcpy(calldata, _assets, _assets_len)
    memcpy(calldata, _amounts, _amounts_len)
    memcpy(calldata, _module_hashes, _module_hashes_len)
    memcpy(calldata, _selectors, _selectors_len)

    #Deploy Index
    let (new_index_address) = deploy(
        class_hash=class_hash,
        contract_address_salt=current_salt,
        constructor_calldata_size=4+_assets_len+_amounts_len+_module_hashes_len+_selectors_len,
        constructor_calldata=calldata,
    )

    #increment salt
    salt.write(current_salt + 1)

    return(new_index_address) 
end

#
# Admin
#

@external
func set_index_hash{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_index_hash: felt):
    Ownable.assert_only_owner()
    index_hash.write(_index_hash)
    return()
end