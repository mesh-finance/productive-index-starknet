%lang starknet

from starkware.cairo.common.uint256 import (Uint256)

@contract_interface
namespace ILending_registry:
    func get_lending_logic(_asset : felt,_amount: Uint256,_protocol: felt)->(call_data_len: felt, call_data : felt*, call_target: felt):
    end
end