%lang starknet

from contracts.interfaces.IERC4626 import IERC4626
from starkware.starknet.common.syscalls import get_contract_address

const xBank = 0

@external 
func lend{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(_amount : Uint256, _underlying_token: felt)->(wrapped_amount: Uint256):
    
    let (this_address) = get_contract_address()    

    IERC20.approve(_underlying_token,xBank,_amount)
    let (shares) = IERC4626.deposit(xBank, _amount, this_address)

    return(shares)
end

@external
func unlend{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_amount : Uint256, _wrapped_token: felt)->(underlying_amount: Uint256):

    let (this_address) = get_contract_address()

    let (assets) = IERC4626.redeem(xBank,_amount, this_address, this_address)
    
    return(assets)
end
