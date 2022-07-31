%lang starknet

from lib.index_storage import Asset
from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IIndex:

    func initialize(
        assets_len: felt,
        assets: felt*,
        amounts_len: felt, 
        amounts: felt*,
        module_hashes_len: felt, 
        module_hashes: felt*, 
        selectors_len: felt, 
        selectors: felt*):
    end

    func mint(amount_out: Uint256):
    end

    func brun(amount_out: Uint256):
    end

    func mint_fee() -> (fee: felt):
    end

    func num_assets() -> (num: felt):
    end

    func assets(index: felt) -> (asset: Asset):
    end

    func set_strategy_registry(_new_registry: felt):
    end

    func transfer_ownership(new_owner: felt):
    end

    func get_amounts_to_mint(amount_out: Uint256) -> (amounts_len: felt, amounts: Uint256*):
    end

    func stake(_amount : Uint256, _asset: felt, _protocol: felt)->(wrapped_amount: Uint256):
    end
end