%lang starknet

@contract_interface
namespace IStrategy {
    func stake(_amount: Uint256, underlying: felt) -> (return_amount: Uint256) {
    }

    func unstake(_amount: Uint256, _wrapped_token: felt) -> (res: felt) {
    }
}
