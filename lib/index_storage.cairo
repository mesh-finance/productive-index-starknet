%lang starknet

from starkware.cairo.common.uint256 import Uint256

const UINT128 = 2 ** 128 - 1;
const MAX_FELT = 0 - 1;

struct Asset {
    address: felt,
    balance: Uint256,
}

@storage_var
func INDEX_module_hash(selector: felt) -> (class_hash: felt) {
}

@storage_var
func INDEX_num_assets() -> (num: felt) {
}

@storage_var
func INDEX_asset_addresses(index: felt) -> (address: felt) {
}

@storage_var
func INDEX_fee_recipient() -> (address: felt) {
}

@storage_var
func INDEX_mint_fee() -> (fee: felt) {
}

@storage_var
func INDEX_burn_fee() -> (fee: felt) {
}

@storage_var
func INDEX_is_initialized() -> (is_initialized: felt) {
}

@storage_var
func INDEX_strategy_registry() -> (strategy_registry_address: felt) {
}
