%lang starknet

@contract_interface
namespace IIndex_factory:

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
        _selectors: felt*
    ) -> (new_index_address: felt):
    end

    func set_index_hash(_index_hash: felt):
    end

end