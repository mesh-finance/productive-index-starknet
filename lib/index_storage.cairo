%lang starknet

from starkware.cairo.common.uint256 import Uint256

struct Asset:
    member address: felt
    member balance: Uint256
end

@storage_var
func INDEX_num_assets() -> (num: felt):
end

@storage_var
func INDEX_asset_addresses(index: felt) -> (address: felt):
end

@storage_var
func INDEX_fee_recipient() -> (address: felt):
end

@storage_var
func INDEX_mint_fee() -> (fee: felt):
end

@storage_var
func INDEX_burn_fee() -> (fee: felt):
end

@storage_var
func STRATEGY_strategy_registry() -> (address: felt):
end