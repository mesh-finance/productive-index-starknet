%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.openzeppelin.access.ownable import Ownable

struct Strategy_Info:
    member asset : felt
    member protocol : felt
end

struct Asset_Protocol:
    member asset : felt
    member protocol: felt
end

@storage_var
func protocol_to_hash(protocol: felt)->(strategy_hash: felt):  
end

@storage_var
func underlying_protocol_to_wrapped(underlying: felt, protocol: felt)->(wrapped: felt):  
end

@storage_var
func wrapped_to_underlying_protocol(wrapped: felt)->(asset_protocol: Asset_Protocol):  
end

#
# Constructor
#

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_owner: felt):
    Ownable.initializer(_owner)
    return ()
end

#
#Views
#

@view
func get_strategy_hash{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_protocol: felt)->(strategy_hash: felt):
    let (strategy_hash) = protocol_to_hash.read(_protocol)
    return(strategy_hash)
end

@view
func get_wrapped_token{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_underlying: felt, _protocol: felt)->(wrapped_token: felt):
    let (wrapped_token) = underlying_protocol_to_wrapped.read(_underlying,_protocol)
    return(wrapped_token)
end 
    
@view
func get_underlying_token{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_wrapped: felt)->(_protocol: felt, underlying_token: felt):
    let (res: Asset_Protocol) = wrapped_to_underlying_protocol.read(_wrapped)
    return(res.protocol, res.asset)
end

#
#Admin
#

@external 
func set_asset_strategy{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_underlying_asset: felt, _wrapped_asset: felt, _protocol: felt)->():
    Ownable.assert_only_owner()
    underlying_protocol_to_wrapped.write(_underlying_asset,_protocol,_wrapped_asset)
    wrapped_to_underlying_protocol.write(_wrapped_asset,Asset_Protocol(_underlying_asset,_protocol))
    return()
end

@external 
func set_protocol_strategy{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_protocol: felt, _strategy_hash: felt)->():
    Ownable.assert_only_owner()
    protocol_to_hash.write(_protocol,_strategy_hash)
    return()
end
