// SPDX-License-Identifier: AGPL-3.0-or-later

%lang starknet

from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.uint256 import ALL_ONES, Uint256, uint256_check, uint256_eq

from src.interfaces.IERC20 import IERC20
from src.openzeppelin.token.erc20.library import ERC20

from src.yagi.erc4626.library import ERC4626, ERC4626_asset, Deposit, Withdraw
from src.yagi.utils.fixedpointmathlib import mul_div_down, mul_div_up

// @title Generic ERC4626 vault (copy this to build your own).
// @description An ERC4626-style vault implementation.
//              Adapted from the solmate implementation: https://github.com/Rari-Capital/solmate/blob/main/src/mixins/ERC4626.sol
// @dev When extending this contract, don't forget to incorporate the ERC20 implementation.
// @author Peteris <github.com/Pet3ris>

//############################################
//                CONSTRUCTOR                #
//############################################

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    asset: felt, name: felt, symbol: felt
) {
    ERC4626.initializer(asset, name, symbol);
    return ();
}

//############################################
//                 GETTERS                   #
//############################################

@view
func asset{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (asset: felt) {
    return ERC4626_asset.read();
}

//############################################
//                 STORAGE                   #
//############################################

//############################################
//                  ACTIONS                  #
//############################################

@external
func deposit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    assets: Uint256, receiver: felt
) -> (shares: Uint256) {
    alloc_locals;
    // Check for rounding error since we round down in previewDeposit.
    let (local shares) = previewDeposit(assets);
    with_attr error_message("ERC4626: cannot deposit 0 shares") {
        let ZERO = Uint256(0, 0);
        let (shares_is_zero) = uint256_eq(shares, ZERO);
        assert shares_is_zero = FALSE;
    }

    // Need to transfer before minting or ERC777s could reenter.
    let (asset) = ERC4626_asset.read();
    let (local msg_sender) = get_caller_address();
    let (local this) = get_contract_address();
    IERC20.transferFrom(contract_address=asset, sender=msg_sender, recipient=this, amount=assets);

    ERC20._mint(receiver, shares);

    Deposit.emit(msg_sender, receiver, assets, shares);

    _after_deposit(assets, shares);

    return (shares,);
}

@external
func mint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    shares: Uint256, receiver: felt
) -> (assets: Uint256) {
    alloc_locals;
    // No need to check for rounding error, previewMint rounds up.
    let (local assets) = previewMint(shares);

    // Need to transfer before minting or ERC777s could reenter.
    let (asset) = ERC4626_asset.read();
    let (local msg_sender) = get_caller_address();
    let (local this) = get_contract_address();
    IERC20.transferFrom(contract_address=asset, sender=msg_sender, recipient=this, amount=assets);

    ERC20._mint(receiver, shares);

    Deposit.emit(msg_sender, receiver, assets, shares);

    _after_deposit(assets, shares);

    return (assets,);
}

@external
func withdraw{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    assets: Uint256, receiver: felt, owner: felt
) -> (shares: Uint256) {
    alloc_locals;
    // No need to check for rounding error, previewWithdraw rounds up.
    let (local shares) = previewWithdraw(assets);

    let (local msg_sender) = get_caller_address();
    ERC4626.ERC20_decrease_allowance_manual(owner, msg_sender, shares);

    _before_withdraw(assets, shares);

    ERC20._burn(owner, shares);

    Withdraw.emit(owner, receiver, assets, shares);

    let (asset) = ERC4626_asset.read();
    IERC20.transfer(contract_address=asset, recipient=receiver, amount=assets);

    return (shares,);
}

@external
func redeem{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    shares: Uint256, receiver: felt, owner: felt
) -> (assets: Uint256) {
    alloc_locals;

    let (local msg_sender) = get_caller_address();
    ERC4626.ERC20_decrease_allowance_manual(owner, msg_sender, shares);

    // Check for rounding error since we round down in previewRedeem.
    let (local assets) = previewRedeem(shares);

    let ZERO = Uint256(0, 0);
    let (local assets_is_zero) = uint256_eq(assets, ZERO);

    with_attr error_message("ERC4626: cannot redeem 0 assets") {
        assert assets_is_zero = FALSE;
    }

    _before_withdraw(assets, shares);

    ERC20._burn(owner, shares);

    Withdraw.emit(owner, receiver, assets, shares);

    let (asset) = ERC4626_asset.read();
    IERC20.transfer(contract_address=asset, recipient=receiver, amount=assets);

    return (assets,);
}

//############################################
//               MAX ACTIONS                 #
//############################################

@view
func maxDeposit(to: felt) -> (maxAssets: Uint256) {
    let (max_deposit) = ERC4626.max_deposit(to);
    return (max_deposit,);
}

@view
func maxMint(to: felt) -> (maxShares: Uint256) {
    let (max_mint) = ERC4626.max_mint(to);
    return (max_mint,);
}

@view
func maxWithdraw{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(from_: felt) -> (
    maxAssets: Uint256
) {
    let (balance) = ERC20.balance_of(from_);
    let (max_assets) = convertToAssets(balance);
    return (max_assets,);
}

@view
func maxRedeem{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(caller: felt) -> (
    maxShares: Uint256
) {
    let (max_redeem) = ERC4626.max_redeem(caller);
    return (max_redeem,);
}

//############################################
//             PREVIEW ACTIONS               #
//############################################

@view
func previewDeposit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    assets: Uint256
) -> (shares: Uint256) {
    return convertToShares(assets);
}

@view
func previewMint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    shares: Uint256
) -> (assets: Uint256) {
    alloc_locals;
    // Probably not needed
    with_attr error_message("ERC4626: shares is not a valid Uint256") {
        uint256_check(shares);
    }

    let (local supply) = ERC20.total_supply();
    let (local all_assets) = totalAssets();
    let ZERO = Uint256(0, 0);
    let (supply_is_zero) = uint256_eq(supply, ZERO);
    if (supply_is_zero == TRUE) {
        return (shares,);
    }
    let (local z) = mul_div_up(shares, all_assets, supply);
    return (z,);
}

@view
func previewWithdraw{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    assets: Uint256
) -> (shares: Uint256) {
    alloc_locals;
    // Probably not needed
    with_attr error_message("ERC4626: assets is not a valid Uint256") {
        uint256_check(assets);
    }

    let (local supply) = ERC20.total_supply();
    let (local all_assets) = totalAssets();
    let ZERO = Uint256(0, 0);
    let (supply_is_zero) = uint256_eq(supply, ZERO);
    if (supply_is_zero == TRUE) {
        return (assets,);
    }
    let (local z) = mul_div_up(assets, supply, all_assets);
    return (z,);
}

@view
func previewRedeem{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    shares: Uint256
) -> (assets: Uint256) {
    return convertToAssets(shares);
}

//############################################
//             CONVERT ACTIONS               #
//############################################

@view
func convertToShares{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    assets: Uint256
) -> (shares: Uint256) {
    alloc_locals;
    with_attr error_message("ERC4626: assets is not a valid Uint256") {
        uint256_check(assets);
    }

    let (local supply) = ERC20.total_supply();
    let (local all_assets) = totalAssets();
    let ZERO = Uint256(0, 0);
    let (supply_is_zero) = uint256_eq(supply, ZERO);
    if (supply_is_zero == TRUE) {
        return (assets,);
    }
    let (local z) = mul_div_down(assets, supply, all_assets);
    return (z,);
}

@view
func convertToAssets{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    shares: Uint256
) -> (assets: Uint256) {
    alloc_locals;
    with_attr error_message("ERC4626: shares is not a valid Uint256") {
        uint256_check(shares);
    }

    let (local supply) = ERC20.total_supply();
    let (local all_assets) = totalAssets();

    let ZERO = Uint256(0, 0);
    let (supply_is_zero) = uint256_eq(supply, ZERO);
    if (supply_is_zero == TRUE) {
        return (shares,);
    }
    let (local z) = mul_div_down(shares, all_assets, supply);
    return (z,);
}

//############################################
//           HOOKS TO OVERRIDE               #
//############################################

@view
func totalAssets{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    totalManagedAssets: Uint256
) {
    let (asset) = ERC4626_asset.read();
    let (this_address) = get_contract_address();
    let (asset_balance: Uint256) = IERC20.balanceOf(asset, this_address);
    return (asset_balance,);
}

func _before_withdraw(assets: Uint256, shares: Uint256) {
    return ();
}

func _after_deposit(assets: Uint256, shares: Uint256) {
    return ();
}

//############################################
//                  ERC20                    #
//############################################

//
// Getters
//

@view
func name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (name: felt) {
    let (name) = ERC20.name();
    return (name,);
}

@view
func symbol{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (symbol: felt) {
    let (symbol) = ERC20.symbol();
    return (symbol,);
}

@view
func totalSupply{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    totalSupply: Uint256
) {
    let (totalSupply: Uint256) = ERC20.total_supply();
    return (totalSupply,);
}

@view
func decimals{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    decimals: felt
) {
    let (decimals) = ERC20.decimals();
    return (decimals,);
}

@view
func balanceOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(account: felt) -> (
    balance: Uint256
) {
    let (balance: Uint256) = ERC20.balance_of(account);
    return (balance,);
}

@view
func allowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, spender: felt
) -> (remaining: Uint256) {
    let (remaining: Uint256) = ERC20.allowance(owner, spender);
    return (remaining,);
}

//
// Externals
//

@external
func transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient: felt, amount: Uint256
) -> (success: felt) {
    ERC20.transfer(recipient, amount);
    return (TRUE,);
}

@external
func transferFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender: felt, recipient: felt, amount: Uint256
) -> (success: felt) {
    ERC20.transfer_from(sender, recipient, amount);
    return (TRUE,);
}

@external
func approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, amount: Uint256
) -> (success: felt) {
    ERC20.approve(spender, amount);
    return (TRUE,);
}

@external
func increaseAllowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, added_value: Uint256
) -> (success: felt) {
    ERC20.increase_allowance(spender, added_value);
    return (TRUE,);
}

@external
func decreaseAllowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, subtracted_value: Uint256
) -> (success: felt) {
    ERC20.decrease_allowance(spender, subtracted_value);
    return (TRUE,);
}
