%lang starknet

from protostar.asserts import (assert_eq)
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from src.interfaces.IIndex_factory import IIndex_factory
from src.interfaces.IERC20 import IERC20

const base = 1000000000000000000 # 1e18
const stake_selector = 1640128135334360963952617826950674415490722662962339953698475555721960042361
const unstake_selector = 1014598069209108454895257238053232298398249443106650014590517510826791002668
const set_strategy_registry_selector = 762785838310885800878865590618530261278822814355561342555512793822747737561

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
    local selectors_3 = set_strategy_registry_selector

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
        ids.index_factory_address = context.index_factory_address
    %}

    IIndex_factory.set_index_hash(index_factory_address,index_hash)

    %{stop_prank_callable()%}

    return ()
end

@external
func test_factory{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}():
    alloc_locals

    ###########################################
    #        Prepare Index Parameters
    ###########################################

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

    let (assets : felt*) = alloc()
    let (amounts : felt*) = alloc()
    let (module_hashes : felt*) = alloc()
    let (selectors : felt*) = alloc()

    local assets_len = 3
    assert assets[0] = ERC20_1 
    assert assets[1] = ERC20_2 
    assert assets[2] = ERC20_3 
    local amounts_len = 3
    assert amounts[0] = base
    assert amounts[1] = base
    assert amounts[2] = base
    local module_hashes_len = 3
    assert module_hashes[0] = strategy_hash
    assert module_hashes[1] = strategy_hash
    assert module_hashes[2] = strategy_hash
    local selectors_len = 3
    assert selectors[0] = stake_selector
    assert selectors[1] = unstake_selector
    assert selectors[2] = set_strategy_registry_selector
    
    ###########################################
    #             Create New Index
    ###########################################

    local index_factory_address
    %{ ids.index_factory_address = context.index_factory_address %}

    #Transfer initial tokens to Factory
    %{ stop_prank_callable = start_prank(ids.admin, target_contract_address=ids.ERC20_1) %}
    IERC20.transfer(ERC20_1,index_factory_address,Uint256(amounts[0]*2,0))
    %{stop_prank_callable()%}
    %{ stop_prank_callable = start_prank(ids.admin, target_contract_address=ids.ERC20_2) %}
    IERC20.transfer(ERC20_2,index_factory_address,Uint256(amounts[1]*2,0))
    %{stop_prank_callable()%}
    %{ stop_prank_callable = start_prank(ids.admin, target_contract_address=ids.ERC20_3) %}
    IERC20.transfer(ERC20_3,index_factory_address,Uint256(amounts[2]*2,0))
    %{stop_prank_callable()%}


    %{ stop_prank_callable = start_prank(ids.admin, target_contract_address=ids.index_factory_address) %}
    #Create Index
    let (local new_index_address) = IIndex_factory.create_index(
        index_factory_address,
        name,
        symbol,
        assets_len,
        assets,
        amounts_len,
        amounts,
        module_hashes_len,
        module_hashes,
        selectors_len,
        selectors
    )
    %{ stop_prank_callable() %}

    %{ print(ids.new_index_address) %}
    
    return()
end

@external
func test_lending{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}():
    return()
end