%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address, library_call
from starkware.cairo.common.math import assert_not_zero, assert_le, assert_not_equal
from starkware.cairo.common.pow import pow
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_check, uint256_eq, uint256_mul, uint256_unsigned_div_rem
)
from starkware.cairo.common.alloc import alloc
from contracts.interfaces.IERC20 import IERC20
from lib.ownable import Ownable
from lib.reentrancy_guard import ReentrancyGuard
from lib.ERC20 import (ERC20,ERC20_total_supply,ERC20_allowances)
from lib.index_storage import (
    INDEX_num_assets,INDEX_asset_addresses,INDEX_fee_recipient,INDEX_mint_fee,INDEX_burn_fee,INDEX_module_hash,Asset
)
from lib.index_core import (Index_Core, MAX_ASSETS, MAX_BPS, MAX_MINT_FEE, MAX_BURN_FEE, MIN_ASSET_AMOUNT)

#
# Constructor
#

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        name: felt,
        symbol: felt,
        initial_owner: felt,
        assets_len: felt,
        assets: felt*,
        amounts_len: felt, 
        amounts: felt*,
        module_hashes_len: felt, 
        module_hashes: felt*, 
        selectors_len: felt, 
        selectors: felt*
    ):
    # get_caller_address() returns '0' in the constructor;
    # therefore, recipient parameter is included
    ERC20.initializer(name,symbol,18)
    Ownable.initializer(initial_owner)
    INDEX_fee_recipient.write(initial_owner)
    Index_Core.initialize(
        assets_len,
        assets,
        amounts_len, 
        amounts,
        module_hashes_len, 
        module_hashes, 
        selectors_len, 
        selectors
    )
    return ()
end

#
# Getters Index
#

@view
func num_assets{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (num: felt):
    let (num) = INDEX_num_assets.read()
    return (num)
end

@view
func assets{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(index: felt) -> (asset: Asset):
    let (asset_address) = INDEX_asset_addresses.read(index)
    let (self_address) = get_contract_address()
    let (asset_balance: Uint256) = IERC20.balanceOf(contract_address=asset_address, account=self_address)
    let asset = Asset(address = asset_address, balance = asset_balance)
    return (asset)
end

@view
func fee_recipient{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (address: felt):
    let (address) = INDEX_fee_recipient.read()
    return (address)
end

@view
func mint_fee{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (fee: felt):
    let (fee) = INDEX_mint_fee.read()
    return (fee)
end

@view
func burn_fee{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (fee: felt):
    let (fee) = INDEX_burn_fee.read()
    return (fee)
end

@external
func get_amount_to_mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(index: felt, amount_out: Uint256) -> (amount: Uint256):
    let (amounts: Uint256*) = Index_Core._get_amounts_to_mint(amount_out)
    return (amounts[index])
end


#
# Externals Index
#

@external
func mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount_out: Uint256):
    alloc_locals
    uint256_check(amount_out)
    let (local msg_sender) = get_caller_address()
    let (local fee_recipient) = INDEX_fee_recipient.read()
    let (local mint_fee) = INDEX_mint_fee.read()
    let (local _total_supply: Uint256) = ERC20_total_supply.read()
    let (is_greater_than_zero) = uint256_lt(Uint256(0, 0), _total_supply)
    assert is_greater_than_zero = 1

    let (local assets_len) = INDEX_num_assets.read()

    let (local amounts_to_transfer: Uint256*) = Index_Core._get_amounts_to_mint(amount_out)
    Index_Core._transfer_assets_from_sender(msg_sender, 0, assets_len, amounts_to_transfer)

    let (mul_low: Uint256, mul_high: Uint256) = uint256_mul(amount_out, Uint256(mint_fee, 0))
    let (is_equal_to_zero) =  uint256_eq(mul_high, Uint256(0, 0))
    assert is_equal_to_zero = 1

    let (fee: Uint256, _) = uint256_unsigned_div_rem(mul_low, Uint256(MAX_BPS, 0))
    ERC20._mint(fee_recipient, fee)
    let (final_amount_out: Uint256) = uint256_sub(amount_out, fee)
    ERC20._mint(msg_sender, final_amount_out)
    return ()
end

@external
func burn{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: Uint256):
    alloc_locals
    uint256_check(amount)
    let (local msg_sender) = get_caller_address()
    let (local fee_recipient) = INDEX_fee_recipient.read()
    let (local burn_fee) = INDEX_burn_fee.read()
    let (local _total_supply: Uint256) = ERC20_total_supply.read()
    let (is_greater_than_zero) = uint256_lt(Uint256(0, 0), _total_supply)
    assert is_greater_than_zero = 1

    let (local assets_len) = INDEX_num_assets.read()

    let (enough_burn_amount) = uint256_le(Uint256(MIN_ASSET_AMOUNT, 0), amount)
    assert_not_zero(enough_burn_amount)

    local amount_to_burn: Uint256
    
    if burn_fee == 1:
        let (mul_low: Uint256, mul_high: Uint256) = uint256_mul(amount, Uint256(burn_fee, 0))
        let (is_equal_to_zero) =  uint256_eq(mul_high, Uint256(0, 0))
        assert is_equal_to_zero = 1
        let (fee: Uint256, _) = uint256_unsigned_div_rem(mul_low, Uint256(MAX_BPS, 0))
        let (local amount_to_burn_local: Uint256) = uint256_sub(amount, fee)
        assert amount_to_burn = amount_to_burn_local
        ERC20._transfer(msg_sender, fee_recipient, fee)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        assert amount_to_burn = amount
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    
    ERC20._burn(msg_sender, amount_to_burn)

    Index_Core._transfer_assets_to_sender(msg_sender, 0, assets_len, amount_to_burn, _total_supply)
    
    return ()
end

@external
func update_fee_recipient{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_fee_recipient: felt):
    Ownable.assert_only_owner()
    assert_not_equal(new_fee_recipient, 0)
    INDEX_fee_recipient.write(new_fee_recipient)
    return ()
end

@external
func update_mint_fee{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_fee: felt):
    Ownable.assert_only_owner()
    assert_le(new_fee, MAX_MINT_FEE)
    INDEX_mint_fee.write(new_fee)
    return ()
end

@external
func update_burn_fee{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_fee: felt):
    Ownable.assert_only_owner()
    assert_le(new_fee, MAX_BURN_FEE)
    INDEX_burn_fee.write(new_fee)
    return ()
end

@external
func sweep{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(token: felt, recipient: felt):
    alloc_locals
    Ownable.assert_only_owner()
    assert_not_equal(token, 0)
    assert_not_equal(recipient, 0)
    let (local num_assets) = INDEX_num_assets.read()
    let (is_asset) = Index_Core._is_asset(token, 0, num_assets)
    assert_not_equal(is_asset, 1)
    let (self_address) = get_contract_address()
    let (token_balance: Uint256) = IERC20.balanceOf(contract_address=token, account=self_address)
    IERC20.transfer(contract_address=token, recipient=recipient, amount=token_balance)
    return ()
end


#
# Default Entry Point
#

@external
@raw_input
@raw_output
func __default__{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}(selector : felt, calldata_size : felt, calldata : felt*) -> (
    retdata_size : felt, retdata : felt*
):
    ReentrancyGuard._start()

    let (class_hash) = INDEX_module_hash.read(selector)

    let (retdata_size : felt, retdata : felt*) = library_call(
        class_hash=class_hash,
        function_selector=selector,
        calldata_size=calldata_size,
        calldata=calldata,
    )

    ReentrancyGuard._end()
    
    return (retdata_size=retdata_size, retdata=retdata)
end