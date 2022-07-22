%lang starknet

from protostar.asserts import (assert_eq)
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

from src.interfaces.IIndex_factory import IIndex_factory

const base = 1000000000000000000 # 1e18
const stake_selector = 1234
const unstake_selector = 4321
const set_strategy_registry = 12632

@external
func __setup__{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}():
    alloc_locals

    ###########################################
    #                  USERS
    ###########################################
    local admin = 111813453203092678575228394645067365508785178229282836578911214210165801044
    local user1 = 222813453203092678575228394645067365508785178229282836578911214210165801044
    local user2 = 333813453203092678575228394645067365508785178229282836578911214210165801044

    %{ context.admin = ids.admin %}
    %{ context.user1 = ids.user1 %}
    %{ context.user2 = ids.user2 %}

    ###########################################
    #              Deploy ERC20s
    ###########################################

    local ERC20_1 : felt
    %{ context.ERC20_1 = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12345,345,18,100000000*ids.base,0,ids.admin]).contract_address %}
    %{ ids.ERC20_1 = context.ERC20_1 %}

    local ERC20_2 : felt
    %{ context.ERC20_2 = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [6789,789,18,100000000*ids.base,0,ids.admin]).contract_address %}
    %{ ids.ERC20_2 = context.ERC20_2 %}

    local ERC20_3 : felt
    %{ context.ERC20_3 = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [98754,754,18,100000000*ids.base,0,ids.admin]).contract_address %}
    %{ ids.ERC20_3 = context.ERC20_3 %}

    ###########################################
    #       Generate Startegy_Module Hash
    ###########################################

    local strategy_hash: felt
    %{
        declared = declare("./src/modules/strategy_module.cairo")
        prepared = prepare(declared, [])
        ids.strategy_hash = prepared.class_hash
        context.strategy_hash = ids.strategy_hash
    %}

    ###########################################
    #        Generate index_hash Hash
    ###########################################

    #Set Constructor Params
    local name = 1234
    local symbol = 123
    local initial_owner = admin
    local assets_len = 3
    local asset_1 = ERC20_1 
    local asset_2 = ERC20_2 
    local asset_3 = ERC20_3 
    local amounts_len = 3
    local amount_1 = base
    local amount_2 = base
    local amount_3 = base
    local module_hashes_len = 3
    local module_hashes_1 = strategy_hash
    local module_hashes_2 = strategy_hash
    local module_hashes_3 = strategy_hash
    local selectors_len = 3
    local selectors_1 = stake_selector
    local selectors_2 = unstake_selector
    local selectors_3 = set_strategy_registry

    #Generate Index Hash
    local index_hash: felt
    %{
        stop_prank_callable = start_prank(ids.admin, target_contract_address=prepared.contract_address)
        declared = declare("./src/Index.cairo")
        prepared = prepare(declared, [
            ids.name,
            ids.symbol,
            ids.initial_owner,
            ids.assets_len,
            ids.asset_1,
            ids.asset_2,
            ids.asset_3,
            ids.amounts_len,
            ids.amount_1,
            ids.amount_2,
            ids.amount_3,
            ids.module_hashes_len,
            ids.module_hashes_1,
            ids.module_hashes_2,
            ids.module_hashes_3,
            ids.selectors_len,
            ids.selectors_1,
            ids.selectors_2,
            ids.selectors_3
        ])
        ids.index_hash = prepared.class_hash
        stop_prank_callable()
    %}

    ###########################################
    #          Deploy Index Factory
    ###########################################

    local index_factory_address : felt
    %{ 
        stop_prank_callable = start_prank(ids.admin, target_contract_address=prepared.contract_address)
        context.index_factory_address = deploy_contract("./src/index_factory.cairo", []).contract_address 
        stop_prank_callable()
    %}

    return ()
end

@external
func test_factory{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}():
    alloc_locals

    local admin
    %{ ids.admin = context.admin %}
    local ERC20_1
    %{ ids.ERC20_1 = context.ERC20_1 %}
    local ERC20_2
    %{ ids.ERC20_2 = context.ERC20_2 %}
    local ERC20_3
    %{ ids.ERC20_3 = context.ERC20_3 %}
    local strategy_hash
    %{ ids.strategy_hash = context.strategy_hash %}

    local name = 1234
    local symbol = 123
    local initial_owner = admin
    local assets_len = 3
    local asset_1 = ERC20_1 
    local asset_2 = ERC20_2 
    local asset_3 = ERC20_3 
    local amounts_len = 3
    local amount_1 = base
    local amount_2 = base
    local amount_3 = base
    local module_hashes_len = 3
    local module_hashes_1 = strategy_hash
    local module_hashes_2 = strategy_hash
    local module_hashes_3 = strategy_hash
    local selectors_len = 3
    local selectors_1 = stake_selector
    local selectors_2 = unstake_selector
    local selectors_3 = set_strategy_registry

    local index_factory_address
    %{ 
        ids.index_factory_address = context.index_factory_address 
        stop_prank_callable = start_prank(ids.admin, target_contract_address=prepared.contract_address)
    %}
    
    IIndex_factory.create_index(
        index_factory_address,
        name,
        symbol,
        initial_owner,
        assets_len,
        asset_1,
        asset_2,
        asset_3,
        amounts_len,
        amount_1,
        amount_2,
        amount_3,
        module_hashes_len,
        module_hashes_1,
        module_hashes_2,
        module_hashes_3,
        selectors_len,
        selectors_1,
        selectors_2,
        selectors_3
    )

    %{ stop_prank_callable() %}

    return()
end

@external
func test_lending{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}():
    return()
end