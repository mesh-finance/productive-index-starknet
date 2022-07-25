%lang starknet

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

end