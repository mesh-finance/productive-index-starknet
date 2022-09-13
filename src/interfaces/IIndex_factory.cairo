%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IIndex_factory {
    func create_index(
        _name: felt,
        _symbol: felt,
        _assets_len: felt,
        _assets: felt*,
        _amounts_len: felt,
        _amounts: felt*,
        _module_hashes_len: felt,
        _module_hashes: felt*,
        _selectors_len: felt,
        _selectors: felt*,
    ) -> (new_index_address: felt) {
    }

    func set_index_hash(_index_hash: felt) {
    }

    func set_strategy_registry(_new_registry: felt) {
    }

    func set_index_registry(_new_registry: felt) {
    }
}
