%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address
from starkware.cairo.common.math import assert_not_zero, assert_in_range, assert_le, assert_not_equal
from starkware.cairo.common.pow import pow
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_check, uint256_eq, uint256_mul, uint256_unsigned_div_rem
)
from src.interfaces.IERC20 import IERC20
from lib.index_storage import (INDEX_asset_addresses, INDEX_num_assets, INDEX_module_hash)
from lib.ERC20 import ERC20, ERC20_total_supply, ERC20_decimals
from lib.ownable import Ownable

const MAX_ASSETS = 10
const MIN_ASSET_AMOUNT = 1000000 # 1e6 min token amount to prevent rounding errors
const MAX_BPS = 10000     ## 100% in basis points
const MAX_MINT_FEE = 500  ## In BPS, 5%, goes to fee recipient
const MAX_BURN_FEE = 500  ## In BPS, 5%, goes to fee recipient

namespace Index_Core:

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
        #Initital Mint
        _initial_mint(assets_len, assets, amounts_len, amounts)
        #Enable Modules
        _set_modules(module_hashes_len,module_hashes,selectors_len,selectors)
        return()
    end

    func _is_asset{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(address: felt, current_index: felt, num_assets: felt) -> (res: felt):
        alloc_locals
        if current_index == num_assets:
            return (0)
        end
        let (asset_address) = INDEX_asset_addresses.read(current_index)
        if asset_address == address:
            return (1)
        else:
            return _is_asset(address, current_index + 1, num_assets)
        end
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
        let (asset_address) = INDEX_asset_addresses.read(current_index)
        IERC20.transferFrom(contract_address=asset_address, sender=sender, recipient=self_address, amount=[amounts])
        _transfer_assets_from_sender(sender, current_index + 1, num_assets, amounts + Uint256.SIZE)
        return ()
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
        let (asset_address) = INDEX_asset_addresses.read(current_index)
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

    func _get_amounts_to_mint{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(amount_out: Uint256) -> (amounts: Uint256*):
        alloc_locals
        uint256_check(amount_out)
        let (local _total_supply: Uint256) = ERC20_total_supply.read()
        let (local num_assets) = INDEX_num_assets.read()
        let (local amounts_start : Uint256*) = alloc()

        let (amounts_end: Uint256*) = _build_amounts_to_mint(amount_out, _total_supply, num_assets, 0, amounts_start)
        return (amounts_start)
    end

    func _add_asset{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
        }(_asset: felt):
        alloc_locals

        #Check that we haven't reached Max assets
        let (local num: felt) = INDEX_num_assets.read()
        assert_le(num+1,MAX_ASSETS)

        #Check that asset isn't already part of the index
        let (is_asset) = _is_asset(_asset, 0, num)
        assert is_asset = FALSE

        #Balance of added asset should be larger then MIN_ASSET_AMOUNT
        let (this_address) = get_contract_address()
        let (asset_balance) = IERC20.balanceOf(_asset,this_address)
        let (is_balance_sufficient) = uint256_le(Uint256(MIN_ASSET_AMOUNT,0),asset_balance)
        assert is_balance_sufficient = TRUE

        #Add asset to index
        INDEX_asset_addresses.write(num,_asset)
        INDEX_num_assets.write(num+1)

        return()
    end

    func _remove_asset{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
        }(_token_address: felt):
        alloc_locals
        
        #Check that we haven't reached 0 assets
        let (num: felt) = INDEX_num_assets.read()
        local last_asset_index = num-1

        #Get asset index (reverts if asset isn't part of index)
        let (asset_index) = _get_asset_index(num,_token_address)

        #Remove asset from index
        let (asset_at_last_index) = INDEX_asset_addresses.read(last_asset_index)
        #This move is redundant if the removed asset is the last one, but it shouldn't cost extra gas as we're writing to the same storage var twice.
        INDEX_asset_addresses.write(asset_index,asset_at_last_index)
        INDEX_asset_addresses.write(last_asset_index,0)
        INDEX_num_assets.write(last_asset_index)

        return()
    end

    func _get_asset_index{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
        }(_assets_num: felt, _asset: felt) -> (_asset_index: felt):
        
        if _assets_num == 0 :
            #Asset is not part of index
            assert 1 = 2
        end

        let (asset_at_num) = INDEX_asset_addresses.read(_assets_num-1)

        if asset_at_num == _asset:
            return(_assets_num)
        else:
            let (asset_num) = _get_asset_index(_assets_num-1,_asset)
            return(asset_num)
        end
    end

end

#
# Internals
# 

func _build_amounts_to_mint{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(amount_out: Uint256, total_supply: Uint256, num_assets: felt, current_index: felt, amounts: Uint256*) -> (amounts: Uint256*):
    alloc_locals
    if current_index == num_assets:
        return (amounts)
    end
    
    let (asset_address) = INDEX_asset_addresses.read(current_index)
    let (self_address) = get_contract_address()
    let (asset_balance: Uint256) = IERC20.balanceOf(contract_address=asset_address, account=self_address)

    let (mul_low: Uint256, mul_high: Uint256) = uint256_mul(asset_balance, amount_out)

    let (is_equal_to_zero) =  uint256_eq(mul_high, Uint256(0, 0))
    assert is_equal_to_zero = 1

    let (local amount_in: Uint256, _) = uint256_unsigned_div_rem(mul_low, total_supply)

    assert [amounts] = amount_in

    return _build_amounts_to_mint(amount_out, total_supply, num_assets, current_index + 1, amounts + Uint256.SIZE)
end

func _set_modules{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
    }(
        module_hashes_len: felt, 
        module_hashes: felt*, 
        selectors_len: felt, 
        selectors: felt*
    ):

    if module_hashes_len == 0:
        return()
    end

    INDEX_module_hash.write(selectors[0],module_hashes[0])

    _set_modules(module_hashes_len-1,module_hashes+1,selectors_len,selectors+1)

    return()
end

#TODO:
#Change this so that initial mint amount is a parameter and not alway 1
func _initial_mint{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(assets_len: felt, assets: felt*, amounts_len: felt, amounts: felt*):
    alloc_locals
    assert assets_len = amounts_len
    assert_in_range(assets_len, 2, MAX_ASSETS + 1)    ## Max 10 assets

    INDEX_num_assets.write(assets_len)

    let (local owner) = Ownable.owner()
    _initiate_assets(0, assets_len, assets)
    let (amounts_in_uint256: Uint256*) = alloc()
    let (amounts_in_uint256_end: Uint256*) = _convert_felt_array_to_uint256_array(0, assets_len, amounts, amounts_in_uint256)
    Index_Core._transfer_assets_from_sender(owner, 0, assets_len, amounts_in_uint256)

    let (local decimals) = ERC20_decimals.read()
    let (local unit) = pow(10, decimals)
    uint256_check(Uint256(1 * unit, 0))
    ERC20._mint(owner, Uint256(1 * unit, 0))
    return ()
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
    INDEX_asset_addresses.write(current_index, [assets])
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
        
    