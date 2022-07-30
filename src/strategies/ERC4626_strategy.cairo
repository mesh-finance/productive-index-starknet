%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.interfaces.IERC4626 import IERC4626
from src.interfaces.IERC20 import IERC20
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_contract_address

const base = 1000000000000000000

@external 
func stake{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(_amount : Uint256, _underlying_asset: felt, _wrapped_asset: felt)->(wrapped_amount: Uint256):
    
    let (this_address) = get_contract_address()    

    IERC20.approve(_underlying_asset,_wrapped_asset,_amount)
    let (shares) = IERC4626.deposit(_wrapped_asset, _amount, this_address)

    return(shares)
end

@external
func unstake{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_amount : Uint256, _wrapped_asset: felt)->(underlying_amount: Uint256):

    let (this_address) = get_contract_address()

    let (assets) = IERC4626.redeem(_wrapped_asset, _amount, this_address, this_address)
    
    return(assets)
end

#scaled to 1e18
@view
func get_exchange_rate{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }()->(exchange_rate: Uint256):
    return(Uint256(base,0))
end