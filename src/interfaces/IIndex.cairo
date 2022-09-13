%lang starknet

from lib.index_storage import Asset
from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IIndex {
    func initialize(
        assets_len: felt,
        assets: felt*,
        amounts_len: felt,
        amounts: felt*,
        module_hashes_len: felt,
        module_hashes: felt*,
        selectors_len: felt,
        selectors: felt*,
    ) {
    }

    func mint(amount_out: Uint256) {
    }

    func brun(amount_out: Uint256) {
    }

    func mint_fee() -> (fee: felt) {
    }

    func num_assets() -> (num: felt) {
    }

    func assets(index: felt) -> (asset: Asset) {
    }

    func set_strategy_registry(_new_registry: felt) {
    }

    func transfer_ownership(new_owner: felt) {
    }

    func get_amounts_to_mint(amount_out: Uint256) -> (amounts_len: felt, amounts: Uint256*) {
    }

    func stake(_amount: Uint256, _asset: felt, _protocol: felt) -> (wrapped_amount: Uint256) {
    }

    func unstake(_amount: Uint256, _wrapped_asset: felt, _protocol: felt) -> (
        underlying_amount: Uint256
    ) {
    }
}
