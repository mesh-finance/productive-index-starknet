%lang starknet

from lib.index_storage import Asset

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
        selectors: felt*
    ):
    end

    func num_assets() -> (num: felt):
    end

    func assets(index: felt) -> (asset: Asset):
    end

    func transfer_ownership(new_owner: felt):
    end
end