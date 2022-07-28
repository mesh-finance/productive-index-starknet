%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address, library_call
from starkware.cairo.common.math import assert_not_zero, assert_le, assert_not_equal
from starkware.cairo.common.pow import pow
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_check, uint256_eq, uint256_mul, uint256_unsigned_div_rem
)
from starkware.cairo.common.alloc import alloc
from src.interfaces.IERC20 import IERC20
from src.openzeppelin.access.ownable import Ownable
from src.openzeppelin.security.reentrancy_guard import ReentrancyGuard
from src.openzeppelin.token.erc20.library import (ERC20,ERC20_total_supply,ERC20_allowances)
from lib.index_storage import (
    INDEX_num_assets,
    INDEX_asset_addresses,
    INDEX_fee_recipient,
    INDEX_mint_fee,
    INDEX_burn_fee,
    INDEX_module_hash,
    INDEX_is_initialized,
    Asset
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
        initial_owner: felt
    ):
    ERC20.initializer(name,symbol,18)
    Ownable.initializer(initial_owner)
    INDEX_fee_recipient.write(initial_owner)
    #Index_Core.initialize(
    #    assets_len,
    #    assets,
    #    amounts_len, 
    #    amounts,
    #    module_hashes_len, 
    #    module_hashes, 
    #    selectors_len, 
    #    selectors
    #)
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

@view
func get_amounts_to_mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount_out: Uint256) -> (amounts_len: felt, amounts: Uint256*):
    alloc_locals
    let (local amount_len) = INDEX_num_assets.read()
    let (amounts: Uint256*) = Index_Core._get_amounts_to_mint(amount_out)
    return(amount_len,amounts)
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

@external
func initialize{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        assets_len: felt,
        assets: felt*,
        amounts_len: felt, 
        amounts: felt*,
        module_hashes_len: felt, 
        module_hashes: felt*, 
        selectors_len: felt, 
        selectors: felt*
    ):
    Ownable.assert_only_owner()

    let (is_index_initialized) = INDEX_is_initialized.read()
    with_attr error_message("Index is already initialized"):
        assert is_index_initialized = FALSE
    end

    #Initital Mint
    Index_Core._initial_mint(assets_len, assets, amounts_len, amounts)
    #Enable Modules
    Index_Core._set_modules(module_hashes_len,module_hashes,selectors_len,selectors)

    INDEX_is_initialized.write(TRUE)
    return()
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


#
# Externals ERC20
#

@external
func transfer{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256) -> (success: felt):
    ERC20.transfer(recipient, amount)
    return (TRUE)
end

@external
func transferFrom{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        sender: felt,
        recipient: felt,
        amount: Uint256
    ) -> (success: felt):
    ERC20.transfer_from(sender, recipient, amount)
    return (TRUE)
end

@external
func approve{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, amount: Uint256) -> (success: felt):
    ERC20.approve(spender, amount)
    return (TRUE)
end

@external
func increaseAllowance{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, added_value: Uint256) -> (success: felt):
    ERC20.increase_allowance(spender, added_value)
    return (TRUE)
end

@external
func decreaseAllowance{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, subtracted_value: Uint256) -> (success: felt):
    ERC20.decrease_allowance(spender, subtracted_value)
    return (TRUE)
end

#
# Getters ERC20
#

@view
func name{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (name: felt):
    let (name) = ERC20.name()
    return (name)
end

@view
func symbol{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (symbol: felt):
    let (symbol) = ERC20.symbol()
    return (symbol)
end

@view
func totalSupply{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (totalSupply: Uint256):
    let (totalSupply: Uint256) = ERC20.total_supply()
    return (totalSupply)
end

@view
func decimals{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (decimals: felt):
    let (decimals) = ERC20.decimals()
    return (decimals)
end

@view
func balanceOf{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt) -> (balance: Uint256):
    let (balance: Uint256) = ERC20.balance_of(account)
    return (balance)
end

@view
func allowance{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt, spender: felt) -> (remaining: Uint256):
    let (remaining: Uint256) = ERC20.allowance(owner, spender)
    return (remaining)
end

#
# Ownership Functions (Temporary, Hopefully can be imported together with ERC20 functions)
#

@view
func owner{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (owner: felt):
    let (owner) = Ownable.owner()
    return (owner=owner)
end

@external
func transfer_ownership{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_owner: felt):
    Ownable.transfer_ownership(new_owner)
    return ()
end