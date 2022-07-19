%lang starknet

from starkware.cairo.common.uint256 import (Uint256)

@contract_interface
namespace IStrategy_registry:

    func get_wrapped_token(_underlying: felt, _protocol: felt)->(wrapped_token: felt):
    end 
    
    func get_underlying_token(_wrapped: felt, _protocol: felt)->(underlying_token: felt):
    end

    func get_strategy_hash(_asset : felt,_protocol: felt)->(strategy_hash: felt):
    end
    
end