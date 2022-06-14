%lang starknet

@contract_interface
namespace IStrategy:
    func lend(_amount: Uint256, underlying: felt) -> (return_amount: Uint256):
    end

    func unlend(_amount: Uint256, _wrapped_token: felt) -> (res : felt):
    end
end
