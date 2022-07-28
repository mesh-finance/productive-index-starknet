%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.openzeppelin.access.ownable import Ownable

struct Strategy_Info:
    member asset : felt
    member protocol : felt
end

struct Strategy:
    member asset : felt
    member hash: felt
end

@storage_var
func asset_to_strategy(info: Strategy_Info)->(strategy_hash: Strategy):  
end

#
#Views
#

@view
func get_strategy_hash{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_asset : felt,_protocol: felt)->(strategy_hash: felt):
end

@view
func get_wrapped_token{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_underlying: felt, _protocol: felt)->(wrapped_token: felt):
end 
    
@view
func get_underlying_token{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_wrapped: felt, _protocol: felt)->(underlying_token: felt):
end

#
#Admin
#

@external 
func set_strategy{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_asset: felt, _opposing_asset: felt, _protocol: felt, _strategy_hash: felt)->():
    Ownable.assert_only_owner()
    asset_to_strategy.write(Strategy_Info(_asset,_protocol), Strategy(_opposing_asset,_strategy_hash))
    return()
end
