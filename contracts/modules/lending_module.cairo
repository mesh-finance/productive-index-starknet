%lang starknet

from starkware.cairo.common.uint256 import (Uint256)
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address
from lib.index_storage import LENDING_lending_registry,INDEX_num_assets,INDEX_asset_addresses,INDEX_num_assets
from lib.index_core import Index_Core

from contracts.interfaces.ILending_registry import ILending_registry
#Import owner
#import Reentrancy protection

const min_amount = 1000000 # 1e6

namespace Lending: 

    @external
    func lend{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(_amount : Uint256, _asset: felt, _protocol: felt)->(wrapped_amount: Uint256):
        alloc_locals
        #assert token is part of index
        let (local num_assets) = INDEX_num_assets.read()
        let (is_asset) = Index_Core._is_asset(_asset, 0, num_assets)
        
        #assert min amount of tokens
        let (this_address) = get_contract_address()
        let (local index_asset_balance) = IERC20.balanceOf(_asset,this_address)
        let (is_balance_sufficient) = uint256_le(_amount,index_asset_balance) 
        assert is_balance_sufficient = 1

        #assert that amount left is 0 or larger then min_amount
        #ToDo use uint256 that checks for underflow
        let (remaining_amount: Uint256) = uint256_sub(index_asset_balance,_amount)
        let (condition_1) = uint256_le(min_amount,remaining_amount)   
        let (local condition_2) = uint256_eq(Uint256(0,0),remaining_amount)
        let (is_remaining_amount_valid) = is_le_felt(1,condition_1+condition_2)
        assert is_remaining_amount_valid = 1

        #Get logic from registry
        let (lending_registry_address) = LENDING_lending_registry.read()
        let (call_data_len: felt, call_data : felt*, call_target: felt) = ILending_registry.get_lending_logic(lending_registry_address,_asset,_amount,_protocol)

        #Execute logic

        if condition_2 == 1:
            #Remove underlying token from index
            #Add wrapped token to index

            #Get underlying token index
            let (underlying_asset_num) = INDEX_num_assets.read(_asset)
            
            #loop through assets and find underlying assets

            #Overwrite underlying asset with wrapped token
            INDEX_asset_addresses.write(underlying_asset_num,wrapped_asset)
        else:
            #Add wrapped token to index
        end

        return(Uint256(0,0))
    end

    @external
    func unlend{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(_amount : Uint256, _asset: felt, _protocol: felt)->(underlying_amount: Uint256):
        
        return(Uint256(0,0))
    end

    @external
    func set_lending_registry{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(_new_registry: felt):
        #Only admin
        LENDING_lending_registry.write(_new_registry)
        return()
    end

end

