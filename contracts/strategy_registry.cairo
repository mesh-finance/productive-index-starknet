%lang starknet

from openzeppelin.access.ownable import Ownable

struct Strategy:
    member underlying : felt,
    member logic : felt
end

@storage_var
func wrapped_to_strategy(wrapped_token: felt)->(strategy: Strategy):  
end

#
#Views
#

@view
func get_strategy{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(_wrapped_token: felt) -> (strategy: Strategy):
    let (strategy: Strategy) = wrapped_to_strategy.read(_wrapped_token)
    return(strategy)
end

#
#Admin
#

@external 
func set_strategy{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_wrapped_token: felt, _strategy: Strategy)->():
    Ownable.assert_only_owner()
    wrapped_to_strategy.write(_wrapped_token, _strategy)
    return()
end
