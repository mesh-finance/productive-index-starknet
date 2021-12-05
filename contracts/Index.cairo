%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import assert_not_zero, assert_in_range, assert_le, assert_not_equal
from starkware.cairo.common.pow import pow
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_check, uint256_eq, uint256_mul, uint256_unsigned_div_rem
)
from starkware.cairo.common.alloc import alloc


const MAX_ASSETS = 10
const MAX_BPS = 10000     ## 100% in basis points
const MAX_MINT_FEE = 500  ## In BPS, 5%, goes to fee recipient
const MAX_BURN_FEE = 500  ## In BPS, 5%, goes to fee recipient

#
# Interface ERC20
#

@contract_interface
namespace IERC20:
    func balanceOf(account: felt) -> (balance: Uint256):
    end
    
    func transfer(recipient: felt, amount: Uint256) -> (success: felt):
    end

    func transferFrom(
            sender: felt, 
            recipient: felt, 
            amount: Uint256
        ) -> (success: felt):
    end
end

#
# Storage ERC20
#

@storage_var
func _name() -> (res: felt):
end

@storage_var
func _symbol() -> (res: felt):
end

@storage_var
func _decimals() -> (res: felt):
end

@storage_var
func total_supply() -> (res: Uint256):
end

@storage_var
func balances(account: felt) -> (res: Uint256):
end

@storage_var
func allowances(owner: felt, spender: felt) -> (res: Uint256):
end

#
# Storage Ownable
#

@storage_var
func _owner() -> (address: felt):
end

#
# Storage Index
#

struct Asset:
    member address: felt
    member balance: Uint256
end

@storage_var
func _num_assets() -> (num: felt):
end

@storage_var
func _asset_addresses(index: felt) -> (address: felt):
end

@storage_var
func _fee_recipient() -> (address: felt):
end

@storage_var
func _mint_fee() -> (fee: felt):
end

@storage_var
func _burn_fee() -> (fee: felt):
end

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
    # get_caller_address() returns '0' in the constructor;
    # therefore, recipient parameter is included
    _name.write(name)
    _symbol.write(symbol)
    _decimals.write(18)
    _owner.write(initial_owner)
    _fee_recipient.write(initial_owner)
    return ()
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
    let (name) = _name.read()
    return (name)
end

@view
func symbol{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (symbol: felt):
    let (symbol) = _symbol.read()
    return (symbol)
end

@view
func totalSupply{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (totalSupply: Uint256):
    let (totalSupply: Uint256) = total_supply.read()
    return (totalSupply)
end

@view
func decimals{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (decimals: felt):
    let (decimals) = _decimals.read()
    return (decimals)
end

@view
func balanceOf{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt) -> (balance: Uint256):
    let (balance: Uint256) = balances.read(account=account)
    return (balance)
end

@view
func allowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt, spender: felt) -> (remaining: Uint256):
    let (remaining: Uint256) = allowances.read(owner=owner, spender=spender)
    return (remaining)
end

#
# Getters Ownable
#

@view
func owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (address: felt):
    let (address) = _owner.read()
    return (address)
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
    let (num) = _num_assets.read()
    return (num)
end

@view
func assets{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(index: felt) -> (asset: Asset):
    let (asset_address) = _asset_addresses.read(index)
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
    let (address) = _fee_recipient.read()
    return (address)
end

@view
func mint_fee{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (fee: felt):
    let (fee) = _mint_fee.read()
    return (fee)
end

@view
func burn_fee{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (fee: felt):
    let (fee) = _burn_fee.read()
    return (fee)
end

@external
func get_amount_to_mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(index: felt, amount_out: Uint256) -> (amount: Uint256):
    let (amounts: Uint256*) = _get_amounts_to_mint(amount_out)
    return (amounts[index])
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
    let (sender) = get_caller_address()
    _transfer(sender, recipient, amount)

    # Cairo equivalent to 'return (true)'
    return (1)
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
    alloc_locals
    let (local caller) = get_caller_address()
    let (local caller_allowance: Uint256) = allowances.read(owner=sender, spender=caller)

    # validates amount <= caller_allowance and returns 1 if true   
    let (enough_balance) = uint256_le(amount, caller_allowance)
    assert_not_zero(enough_balance)

    _transfer(sender, recipient, amount)

    # subtract allowance
    let (new_allowance: Uint256) = uint256_sub(caller_allowance, amount)
    allowances.write(sender, caller, new_allowance)

    # Cairo equivalent to 'return (true)'
    return (1)
end

@external
func approve{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, amount: Uint256) -> (success: felt):
    let (caller) = get_caller_address()
    _approve(caller, spender, amount)

    # Cairo equivalent to 'return (true)'
    return (1)
end

@external
func increaseAllowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, added_value: Uint256) -> (success: felt):
    alloc_locals
    uint256_check(added_value)
    let (local caller) = get_caller_address()
    let (local current_allowance: Uint256) = allowances.read(caller, spender)

    # add allowance
    let (local new_allowance: Uint256, is_overflow) = uint256_add(current_allowance, added_value)
    assert (is_overflow) = 0

    _approve(caller, spender, new_allowance)

    # Cairo equivalent to 'return (true)'
    return (1)
end

@external
func decreaseAllowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, subtracted_value: Uint256) -> (success: felt):
    alloc_locals
    uint256_check(subtracted_value)
    let (local caller) = get_caller_address()
    let (local current_allowance: Uint256) = allowances.read(owner=caller, spender=spender)
    let (local new_allowance: Uint256) = uint256_sub(current_allowance, subtracted_value)

    # validates new_allowance < current_allowance and returns 1 if true   
    let (enough_allowance) = uint256_lt(new_allowance, current_allowance)
    assert_not_zero(enough_allowance)

    _approve(caller, spender, new_allowance)

    # Cairo equivalent to 'return (true)'
    return (1)
end

#
# Externals Ownable
#

@external
func transfer_ownership{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_owner: felt) -> (new_owner: felt):
    _only_owner()
    _owner.write(new_owner)
    return (new_owner=new_owner)
end

#
# Externals Index
#

@external
func initial_mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(assets_len: felt, assets: felt*, amounts_len: felt, amounts: felt*):
    alloc_locals
    _only_owner()
    let (local _total_supply: Uint256) = total_supply.read()
    let (is_equal_to_zero) =  uint256_eq(_total_supply, Uint256(0, 0))
    assert is_equal_to_zero = 1
    assert assets_len = amounts_len
    assert_in_range(assets_len, 2, MAX_ASSETS + 1)    ## Max 10 assets

    _num_assets.write(assets_len)
    
    let (local owner) = _owner.read()
    _initiate_assets(0, assets_len, assets)
    let (amounts_in_uint256: Uint256*) = alloc()
    let (amounts_in_uint256_end: Uint256*) = _convert_felt_array_to_uint256_array(0, assets_len, amounts, amounts_in_uint256)
    _transfer_assets_from_sender(owner, 0, assets_len, amounts_in_uint256)

    let (local decimals) = _decimals.read()
    let (local unit) = pow(10, decimals)
    uint256_check(Uint256(1 * unit, 0))
    _mint(owner, Uint256(1 * unit, 0))
    return ()
end

@external
func mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount_out: Uint256):
    alloc_locals
    uint256_check(amount_out)
    let (local msg_sender) = get_caller_address()
    let (local fee_recipient) = _fee_recipient.read()
    let (local mint_fee) = _mint_fee.read()
    let (local _total_supply: Uint256) = total_supply.read()
    let (is_greater_than_zero) = uint256_lt(Uint256(0, 0), _total_supply)
    assert is_greater_than_zero = 1

    let (local assets_len) = _num_assets.read()

    let (local amounts_to_transfer: Uint256*) = _get_amounts_to_mint(amount_out)
    _transfer_assets_from_sender(msg_sender, 0, assets_len, amounts_to_transfer)

    let (mul_low: Uint256, mul_high: Uint256) = uint256_mul(amount_out, Uint256(mint_fee, 0))
    let (is_equal_to_zero) =  uint256_eq(mul_high, Uint256(0, 0))
    assert is_equal_to_zero = 1

    let (fee: Uint256, _) = uint256_unsigned_div_rem(mul_low, Uint256(MAX_BPS, 0))
    _mint(fee_recipient, fee)
    let (final_amount_out: Uint256) = uint256_sub(amount_out, fee)
    _mint(msg_sender, final_amount_out)
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
    let (local fee_recipient) = _fee_recipient.read()
    let (local owner) = _owner.read()
    let (local burn_fee) = _burn_fee.read()
    let (local _total_supply: Uint256) = total_supply.read()
    let (is_greater_than_zero) = uint256_lt(Uint256(0, 0), _total_supply)
    assert is_greater_than_zero = 1

    let (local assets_len) = _num_assets.read()

    let (min_burn_amount) = pow(10, 6)
    let (enough_burn_amount) = uint256_le(Uint256(min_burn_amount, 0), amount)
    assert_not_zero(enough_burn_amount)

    local amount_to_burn: Uint256
    local charge_fee
    
    if burn_fee == 0:
        assert charge_fee = 0
    else:
        if msg_sender == fee_recipient:
            assert charge_fee = 0
        else:
            if msg_sender == owner:
                assert charge_fee = 0
            else:
                assert charge_fee = 1
            end
        end
    end

    if charge_fee == 1:
        let (mul_low: Uint256, mul_high: Uint256) = uint256_mul(amount, Uint256(burn_fee, 0))
        let (is_equal_to_zero) =  uint256_eq(mul_high, Uint256(0, 0))
        assert is_equal_to_zero = 1
        let (fee: Uint256, _) = uint256_unsigned_div_rem(mul_low, Uint256(MAX_BPS, 0))
        let (local amount_to_burn_local: Uint256) = uint256_sub(amount, fee)
        assert amount_to_burn = amount_to_burn_local
        _transfer(msg_sender, fee_recipient, fee)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        assert amount_to_burn = amount
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    
    _burn(msg_sender, amount_to_burn)

    _transfer_assets_to_sender(msg_sender, 0, assets_len, amount_to_burn, _total_supply)
    
    return ()
end

@external
func update_fee_recipient{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_fee_recipient: felt):
    _only_owner()
    assert_not_equal(new_fee_recipient, 0)
    _fee_recipient.write(new_fee_recipient)
    return ()
end

@external
func update_mint_fee{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_fee: felt):
    _only_owner()
    assert_le(new_fee, MAX_MINT_FEE)
    _mint_fee.write(new_fee)
    return ()
end

@external
func update_burn_fee{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_fee: felt):
    _only_owner()
    assert_le(new_fee, MAX_BURN_FEE)
    _burn_fee.write(new_fee)
    return ()
end

@external
func sweep{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(token: felt, recipient: felt):
    alloc_locals
    _only_owner()
    assert_not_equal(token, 0)
    assert_not_equal(recipient, 0)
    let (local num_assets) = _num_assets.read()
    let (is_asset) = _is_asset(token, 0, num_assets)
    assert_not_equal(is_asset, 1)
    let (self_address) = get_contract_address()
    let (token_balance: Uint256) = IERC20.balanceOf(contract_address=token, account=self_address)
    IERC20.transfer(contract_address=token, recipient=recipient, amount=token_balance)
    return ()
end


#
# Internals ERC20
#

func _mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256):
    alloc_locals
    assert_not_zero(recipient)
    uint256_check(amount)

    let (balance: Uint256) = balances.read(account=recipient)
    # overflow is not possible because sum is guaranteed to be less than total supply
    # which we check for overflow below
    let (new_balance, _: Uint256) = uint256_add(balance, amount)
    balances.write(recipient, new_balance)

    let (local supply: Uint256) = total_supply.read()
    let (local new_supply: Uint256, is_overflow) = uint256_add(supply, amount)
    assert (is_overflow) = 0

    total_supply.write(new_supply)
    return ()
end

func _transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(sender: felt, recipient: felt, amount: Uint256):
    alloc_locals
    assert_not_zero(sender)
    assert_not_zero(recipient)
    uint256_check(amount) # almost surely not needed, might remove after confirmation

    let (local sender_balance: Uint256) = balances.read(account=sender)

    # validates amount <= sender_balance and returns 1 if true
    let (enough_balance) = uint256_le(amount, sender_balance)
    assert_not_zero(enough_balance)

    # subtract from sender
    let (new_sender_balance: Uint256) = uint256_sub(sender_balance, amount)
    balances.write(sender, new_sender_balance)

    # add to recipient
    let (recipient_balance: Uint256) = balances.read(account=recipient)
    # overflow is not possible because sum is guaranteed by mint to be less than total supply
    let (new_recipient_balance, _: Uint256) = uint256_add(recipient_balance, amount)
    balances.write(recipient, new_recipient_balance)
    return ()
end

func _approve{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(caller: felt, spender: felt, amount: Uint256):
    assert_not_zero(caller)
    assert_not_zero(spender)
    uint256_check(amount)
    allowances.write(caller, spender, amount)
    return ()
end

func _burn{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt, amount: Uint256):
    alloc_locals
    assert_not_zero(account)
    uint256_check(amount)

    let (balance: Uint256) = balances.read(account)
    # validates amount <= balance and returns 1 if true
    let (enough_balance) = uint256_le(amount, balance)
    assert_not_zero(enough_balance)
    
    let (new_balance: Uint256) = uint256_sub(balance, amount)
    balances.write(account, new_balance)

    let (supply: Uint256) = total_supply.read()
    let (new_supply: Uint256) = uint256_sub(supply, amount)
    total_supply.write(new_supply)
    return ()
end

#
# Internals Ownable
#

func _only_owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (owner) = _owner.read()
    let (caller) = get_caller_address()
    assert owner = caller
    return ()
end

#
# Internals Index
#

func _is_asset{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(address: felt, current_index: felt, num_assets: felt) -> (res: felt):
    alloc_locals
    if current_index == num_assets:
        return (0)
    end
    let (asset_address) = _asset_addresses.read(current_index)
    if asset_address == address:
        return (1)
    else:
        return _is_asset(address, current_index + 1, num_assets)
    end
end


func _initiate_assets{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(current_index: felt, num_assets: felt, assets: felt*):
    alloc_locals
    if current_index == num_assets:
        return ()
    end
    _asset_addresses.write(current_index, [assets])
    _initiate_assets(current_index + 1, num_assets, assets + 1)
    return ()
end

func _convert_felt_array_to_uint256_array{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(current_index: felt, num_assets: felt, amounts: felt*, amounts_in_uint256: Uint256*) -> (amounts_in_uint256: Uint256*):
    alloc_locals
    if current_index == num_assets:
        return (amounts_in_uint256)
    end
    assert [amounts_in_uint256] = Uint256([amounts], 0)
    
    return _convert_felt_array_to_uint256_array(current_index + 1, num_assets, amounts + 1, amounts_in_uint256 + Uint256.SIZE)
end

func _transfer_assets_from_sender{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(sender: felt, current_index: felt, num_assets: felt, amounts: Uint256*):
    alloc_locals
    if current_index == num_assets:
        return ()
    end
    let (self_address) = get_contract_address()
    let (asset_address) = _asset_addresses.read(current_index)
    IERC20.transferFrom(contract_address=asset_address, sender=sender, recipient=self_address, amount=[amounts])
    _transfer_assets_from_sender(sender, current_index + 1, num_assets, amounts + Uint256.SIZE)
    return ()
end

func _get_amounts_to_mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount_out: Uint256) -> (amounts: Uint256*):
    alloc_locals
    uint256_check(amount_out)
    let (local _total_supply: Uint256) = total_supply.read()
    let (local num_assets) = _num_assets.read()
    let (local amounts_start : Uint256*) = alloc()

    let (amounts_end: Uint256*) = _build_amounts_to_mint(amount_out, _total_supply, num_assets, 0, amounts_start)
    return (amounts_start)
end

func _build_amounts_to_mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount_out: Uint256, total_supply: Uint256, num_assets: felt, current_index: felt, amounts: Uint256*) -> (amounts: Uint256*):
        alloc_locals
        if current_index == num_assets:
            return (amounts)
        end
        
        let (asset_address) = _asset_addresses.read(current_index)
        let (self_address) = get_contract_address()
        let (asset_balance: Uint256) = IERC20.balanceOf(contract_address=asset_address, account=self_address)

        let (mul_low: Uint256, mul_high: Uint256) = uint256_mul(asset_balance, amount_out)

        let (is_equal_to_zero) =  uint256_eq(mul_high, Uint256(0, 0))
        assert is_equal_to_zero = 1

        let (local amount_in: Uint256, _) = uint256_unsigned_div_rem(mul_low, total_supply)

        assert [amounts] = amount_in

        return _build_amounts_to_mint(amount_out, total_supply, num_assets, current_index + 1, amounts + Uint256.SIZE)
    end
        
    func _transfer_assets_to_sender{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(sender: felt, current_index: felt, num_assets: felt, amount_to_burn: Uint256, total_supply: Uint256):
    alloc_locals
    if current_index == num_assets:
        return ()
    end
    let (asset_address) = _asset_addresses.read(current_index)
    let (self_address) = get_contract_address()
    let (current_balance: Uint256) = IERC20.balanceOf(contract_address=asset_address, account=self_address)
    let (mul_low: Uint256, mul_high: Uint256) = uint256_mul(current_balance, amount_to_burn)
    let (is_equal_to_zero) =  uint256_eq(mul_high, Uint256(0, 0))
    assert is_equal_to_zero = 1
    let (local amount_to_transfer: Uint256, _) = uint256_unsigned_div_rem(mul_low, total_supply)
    let (final_balance: Uint256) = uint256_sub(current_balance, amount_to_transfer)
    IERC20.transfer(contract_address=asset_address, recipient=sender, amount=amount_to_transfer)
    _transfer_assets_to_sender(sender, current_index + 1, num_assets, amount_to_burn, total_supply)
    return ()
end
