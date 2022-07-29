%lang starknet

from starkware.cairo.common.uint256 import (Uint256)

@contract_interface
namespace IStrategy_registry:

    func get_strategy_hash(_protocol: felt)->(strategy_hash: felt):
    end

    func get_wrapped_token(_underlying: felt, _protocol: felt)->(wrapped_token: felt):
    end 
        
    func get_underlying_token(_wrapped: felt)->(_protocol: felt, underlying_token: felt): 
    end

    func set_asset_strategy(_underlying_asset: felt, _wrapped_asset: felt, _protocol: felt):
    end

    func set_protocol_strategy(_protocol: felt, _strategy_hash: felt):
    end
    
end