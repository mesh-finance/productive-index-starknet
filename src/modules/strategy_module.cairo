%lang starknet

from starkware.cairo.common.uint256 import (Uint256, uint256_le, uint256_sub, uint256_eq)
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE
from starkware.starknet.common.syscalls import get_contract_address, library_call
from lib.index_storage import INDEX_num_assets,INDEX_asset_addresses
from lib.index_core import Index_Core, MIN_ASSET_AMOUNT
from lib.safemath import SafeUint256
from lib.ownable import Ownable

from src.interfaces.IStrategy_registry import IStrategy_registry
from src.interfaces.IERC20 import IERC20

#ToDo: generate selectors
const stake_selector = 23764872364238
const unstake_selector = 23764872364238
const MAX_FELT = 637587436573436976973597949534

@storage_var
func strategy_registry() -> (address: felt):
end

@external
func stake{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(_amount : Uint256, _asset: felt, _protocol: felt)->(wrapped_amount: Uint256):
    alloc_locals
    #assert token is part of index
    let (local num_assets) = INDEX_num_assets.read()
    let (is_asset) = Index_Core._is_asset(_asset, 0, num_assets)
    
    let (this_address) = get_contract_address()
    let (index_asset_balance) =  IERC20.balanceOf(_asset,this_address)

    let (is_max_value) = uint256_eq(_amount,Uint256(MAX_FELT,MAX_FELT))

    #determine staking amount
    if is_max_value == 1 :
        local trade_amount: Uint256 = index_asset_balance
    else:
        local trade_amount: Uint256 = _amount
    end

    #assert that amount left is 0 or larger then MIN_ASSET_AMOUNT
    #ToDo use uint256 that checks for underflow
    let (remaining_amount: Uint256) = SafeUint256.sub_le(index_asset_balance,_amount)
    let (is_remaining_amount_sufficient) = uint256_le(Uint256(MIN_ASSET_AMOUNT,0),remaining_amount)   
    let (local is_total_amount_staked) = uint256_eq(Uint256(0,0),remaining_amount)
    let (is_remaining_amount_valid) = is_le_felt(1,is_remaining_amount_sufficient+is_total_amount_staked)
    assert is_remaining_amount_valid = TRUE

    #Get logic from registry
    let (strategy_registry_address) = strategy_registry.read()
    let (strategy_class_hash) = IStrategy_registry.get_strategy_hash(strategy_registry_address,_asset,_protocol)

    ##Execute Strategy Logic
    let (call_data: felt*) = alloc()
    call_data[0] = _amount.low
    call_data[1] = _amount.high 
    call_data[2] = _asset
    let (retdata_size : felt, retdata : felt*) = library_call(
        strategy_class_hash,
        stake_selector,
        3,
        call_data
    )

    let (local wrapped: felt) = IStrategy_registry.get_wrapped_token(strategy_registry_address, _asset, _protocol)

    #Add/Remove assets from index
    if is_total_amount_staked == TRUE:
        #Remove underlying token from index
        Index_Core._remove_asset(_asset)

        #Add wrapped token to index
        Index_Core._add_asset(wrapped)
        
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        #Add wrapped token to index
        Index_Core._add_asset(wrapped)

        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    let (wrapped_amount: Uint256) = IERC20.balanceOf(wrapped, this_address)

    return(wrapped_amount)
end

@external
func unstake{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_amount : Uint256, _wrapped_asset: felt, _protocol: felt)->(underlying_amount: Uint256):
    alloc_locals

    #check that token is part of index
    let (local num_assets) = INDEX_num_assets.read()
    let (is_asset) = Index_Core._is_asset(_wrapped_asset, 0, num_assets)

    let (this_address) = get_contract_address()
    let (wrapped_asset_balance) =  IERC20.balanceOf(_wrapped_asset,this_address)
    
    let (is_max_value) = uint256_eq(_amount,Uint256(MAX_FELT,MAX_FELT))

    #determine unstaking amount
    if is_max_value == 1 :
        local trade_amount: Uint256 = wrapped_asset_balance
    else:
        local trade_amount: Uint256 = _amount
    end

    #assert that amount left is 0 or larger then MIN_ASSET_AMOUNT
    #ToDo use uint256 that checks for underflow
    let (remaining_amount: Uint256) = SafeUint256.sub_le(wrapped_asset_balance,_amount)
    let (is_remaining_amount_sufficient) = uint256_le(Uint256(MIN_ASSET_AMOUNT,0),remaining_amount)   
    let (local is_total_amount_unstaked) = uint256_eq(Uint256(0,0),remaining_amount)
    let (is_remaining_amount_valid) = is_le_felt(1,is_remaining_amount_sufficient+is_total_amount_unstaked)
    assert is_remaining_amount_valid = TRUE

    #Get logic from registry
    let (strategy_registry_address) = strategy_registry.read()
    let (strategy_class_hash) = IStrategy_registry.get_strategy_hash(strategy_registry_address,_wrapped_asset,_protocol)

    ##Execute Strategy Logic
    let (call_data: felt*) = alloc()
    call_data[0] = _amount.low
    call_data[1] = _amount.high 
    call_data[2] = _wrapped_asset
    let (retdata_size : felt, retdata : felt*) = library_call(
        strategy_class_hash,
        unstake_selector,
        3,
        call_data
    )

    let (local underlying: felt) = IStrategy_registry.get_underlying_token(strategy_registry_address, _wrapped_asset, _protocol)

    #Add/Remove assets from index
    if is_total_amount_unstaked == TRUE:
        #Remove wrapped token from index
        Index_Core._remove_asset(_wrapped_asset)

        #Add underlying token to index
        Index_Core._add_asset(underlying)
        
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        #Add underlying token to index
        Index_Core._add_asset(underlying)

        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    let (underlying_amount: Uint256) = IERC20.balanceOf(underlying, this_address)

    return(underlying_amount)
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