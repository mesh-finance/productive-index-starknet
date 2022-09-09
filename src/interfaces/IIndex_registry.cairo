%lang starknet

@contract_interface
namespace IIndex_registry:

    #
    # Views
    #

    func get_index(_index_id: felt) -> (index_address: felt):
    end

    func get_next_id() -> (index_id: felt):
    end

    #
    # Admin
    #

    func add_index(_index_address: felt) -> (id: felt):
    end

end