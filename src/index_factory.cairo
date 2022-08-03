%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address, deploy
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import Uint256
from src.openzeppelin.access.ownable import Ownable

from src.interfaces.IIndex import IIndex
from src.interfaces.IERC20 import IERC20

@storage_var
func salt() -> (value : felt):
end

@storage_var
func index_hash() -> (hash : felt):
end

@storage_var
func strategy_registry() -> (address: felt):
end

#
# Constructor
#

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_owner: felt):
    Ownable.initializer(_owner)
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

    let(class_hash) = index_hash.read()
    let (current_salt) = salt.read()

    let (caller) = get_caller_address()
    let (local this_address) = get_contract_address()

    let (calldata: felt*) = alloc()
    assert calldata[0] = _name
    assert calldata[1] = _symbol
    assert calldata[2] = this_address

    #Deploy Index
    let (new_index_address) = deploy(
        class_hash,
        current_salt,
        3,
        calldata,
    )

    #Approve token transfers
    IERC20.approve(_assets[0],new_index_address,Uint256(_amounts[0]*2,0))
    IERC20.approve(_assets[1],new_index_address,Uint256(_amounts[1]*2,0))
    IERC20.approve(_assets[2],new_index_address,Uint256(_amounts[2]*2,0))

    #Initialize Index
    IIndex.initialize(
        new_index_address,
        _assets_len,
        _assets,
        _amounts_len, 
        _amounts,
        _module_hashes_len, 
        _module_hashes, 
        _selectors_len, 
        _selectors
    )

    #Set strategy_registry address for index
    let (strategy_registry_address) = strategy_registry.read()
    IIndex.set_strategy_registry(new_index_address,strategy_registry_address)

    #Transfer ownership to sender
    IIndex.transfer_ownership(new_index_address,caller)

    let (initial_mint_amount: Uint256) = IERC20.balanceOf(new_index_address, this_address)

    #Send initially minted tokens to caller
    IERC20.transfer(new_index_address,caller,initial_mint_amount)

    #increment salt
    salt.write(current_salt + 1)

    #Emit Event: Index Created

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

@external
func set_strategy_registry{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_new_registry: felt):
    Ownable.assert_only_owner()
    strategy_registry.write(_new_registry)
    return()
end