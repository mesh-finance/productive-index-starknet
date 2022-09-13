%lang starknet

from protostar.asserts import assert_eq
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_sub

from lib.index_storage import Asset, UINT128
from lib.index_core import MAX_BPS
from lib.utils import Utils

from src.interfaces.IIndex_factory import IIndex_factory
from src.interfaces.IStrategy_registry import IStrategy_registry
from src.interfaces.IIndex import IIndex
from src.interfaces.IERC20 import IERC20

const base = 1000000000000000000;  // 1e18
const stake_selector = 1640128135334360963952617826950674415490722662962339953698475555721960042361;
const unstake_selector = 1014598069209108454895257238053232298398249443106650014590517510826791002668;
const set_strategy_registry_selector = 762785838310885800878865590618530261278822814355561342555512793822747737561;
// Arbitrary number that will represent a specific protocol
const protocol1 = 1;

@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    //##########################################
    //                  USERS
    //##########################################
    local admin = 111813453203092678575228394645067365508785178229282836578911214210165801044;
    local user1 = 222813453203092678575228394645067365508785178229282836578911214210165801044;
    local user2 = 333813453203092678575228394645067365508785178229282836578911214210165801044;

    %{ context.admin = ids.admin %}
    %{ context.user1 = ids.user1 %}
    %{ context.user2 = ids.user2 %}

    //##########################################
    //              Deploy ERC20s
    //##########################################

    local ERC20_1: felt;
    %{ context.ERC20_1 = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12345,345,18,100000000*ids.base,0,ids.admin]).contract_address %}
    %{ ids.ERC20_1 = context.ERC20_1 %}

    local ERC20_2: felt;
    %{ context.ERC20_2 = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [6789,789,18,100000000*ids.base,0,ids.admin]).contract_address %}
    %{ ids.ERC20_2 = context.ERC20_2 %}

    local ERC20_3: felt;
    %{ context.ERC20_3 = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [98754,754,18,100000000*ids.base,0,ids.admin]).contract_address %}
    %{ ids.ERC20_3 = context.ERC20_3 %}

    //##########################################
    //       Generate Module Hashes
    //##########################################

    local strategy_hash: felt;
    %{
        declared = declare("./src/modules/strategy_module.cairo")
        prepared = prepare(declared, [])
        ids.strategy_hash = prepared.class_hash
        context.strategy_hash = ids.strategy_hash
    %}

    local erc20_hash: felt;
    %{
        declared = declare("./src/openzeppelin/token/erc20/library.cairo")
        prepared = prepare(declared, [])
        ids.erc20_hash = prepared.class_hash
        context.erc20_hash = ids.erc20_hash
    %}

    local ownable_hash: felt;
    %{
        declared = declare("./src/openzeppelin/access/ownable.cairo")
        prepared = prepare(declared, [])
        ids.ownable_hash = prepared.class_hash
        context.ownable_hash = ids.ownable_hash
    %}

    //##########################################
    //        Generate index_hash Hash
    //##########################################

    // Set Constructor Params
    local name = 1234;
    local symbol = 123;
    local initial_owner = admin;
    local assets_len = 3;
    local asset_1 = ERC20_1;
    local asset_2 = ERC20_2;
    local asset_3 = ERC20_3;
    local amounts_len = 3;
    local amount_1 = base;
    local amount_2 = base;
    local amount_3 = base;
    local module_hashes_len = 3;
    local module_hashes_1 = strategy_hash;
    local module_hashes_2 = strategy_hash;
    local module_hashes_3 = strategy_hash;
    local selectors_len = 3;
    local selectors_1 = stake_selector;
    local selectors_2 = unstake_selector;
    local selectors_3 = set_strategy_registry_selector;

    // Generate Index Hash
    local index_hash: felt;
    %{
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
    %}

    //##########################################
    //          Deploy Index Factory
    //##########################################

    local index_factory_address: felt;
    %{
        context.index_factory_address = deploy_contract("./src/index_factory.cairo", [ids.admin]).contract_address 
        ids.index_factory_address = context.index_factory_address
    %}

    //##########################################
    //          Deploy Index Registry
    //##########################################

    local index_registry_address: felt;
    %{
        context.index_registry_address = deploy_contract("./src/index_registry.cairo", [ids.index_factory_address]).contract_address 
        ids.index_registry_address = context.index_registry_address
    %}

    //##########################################
    //        Configure Index Factory
    //##########################################

    %{ stop_prank_callable = start_prank(ids.admin, target_contract_address=ids.index_factory_address) %}
    IIndex_factory.set_index_hash(index_factory_address, index_hash);
    IIndex_factory.set_index_registry(index_factory_address, index_registry_address);
    %{ stop_prank_callable() %}

    //##########################################
    //         Setup Index Strategy
    //##########################################

    // Deploy Mock_Lending Protocol
    // ERC4626 (with ERC20_1)
    local yagi_vault_address: felt;
    local wrapped_name = 837465;
    local wrapped_symbol = 837;
    %{
        context.yagi_vault_address = deploy_contract("./src/yagi/erc4626/ERC4626.cairo", [ids.ERC20_1,ids.wrapped_name,ids.wrapped_symbol]).contract_address 
        ids.yagi_vault_address = context.yagi_vault_address
    %}

    // Deploy Strategy Registry
    local strategy_registry_address: felt;
    %{
        context.strategy_registry_address = deploy_contract("./src/strategy_registry.cairo", [ids.admin]).contract_address 
        ids.strategy_registry_address = context.strategy_registry_address
    %}

    // Generate Strategy Hash
    local ERC4626_strategy_hash: felt;
    %{
        declared = declare("./src/strategies/ERC4626_strategy.cairo")
        prepared = prepare(declared, [])
        ids.ERC4626_strategy_hash = prepared.class_hash
        context.ERC4626_strategy_hash = ids.ERC4626_strategy_hash
    %}

    // Add Strategy to Registry
    // IStrategy_registry.set_asset_strategy(strategy_registry_address, ERC20_1, wrapped_asset, protocol1)->():
    %{ stop_prank_callable = start_prank(ids.admin, target_contract_address=ids.strategy_registry_address) %}
    IStrategy_registry.set_protocol_strategy(
        strategy_registry_address, protocol1, ERC4626_strategy_hash
    );
    IStrategy_registry.set_asset_strategy(
        strategy_registry_address, ERC20_1, yagi_vault_address, protocol1
    );
    %{ stop_prank_callable() %}

    // Add Strategy Registry to IndexFactory
    %{ stop_prank_callable = start_prank(ids.admin, target_contract_address=ids.index_factory_address) %}
    IIndex_factory.set_strategy_registry(index_factory_address, strategy_registry_address);
    %{ stop_prank_callable() %}

    return ();
}

@external
func test_factory{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    local admin;
    %{ ids.admin = context.admin %}
    local user1;
    %{ ids.user1 = context.user1 %}
    local user2;
    %{ ids.user2 = context.user2 %}

    //##########################################
    //        Prepare Index Parameters
    //##########################################

    local ERC20_1;
    %{ ids.ERC20_1 = context.ERC20_1 %}
    local ERC20_2;
    %{ ids.ERC20_2 = context.ERC20_2 %}
    local ERC20_3;
    %{ ids.ERC20_3 = context.ERC20_3 %}
    local strategy_hash;
    %{ ids.strategy_hash = context.strategy_hash %}

    local name = 1234;
    local symbol = 123;
    local initial_owner = admin;

    let (assets: felt*) = alloc();
    let (amounts: felt*) = alloc();
    let (module_hashes: felt*) = alloc();
    let (selectors: felt*) = alloc();

    local assets_len = 3;
    assert assets[0] = ERC20_1;
    assert assets[1] = ERC20_2;
    assert assets[2] = ERC20_3;
    local amounts_len = 3;
    assert amounts[0] = base;
    assert amounts[1] = base;
    assert amounts[2] = base;
    local module_hashes_len = 3;
    assert module_hashes[0] = strategy_hash;
    assert module_hashes[1] = strategy_hash;
    assert module_hashes[2] = strategy_hash;
    local selectors_len = 3;
    assert selectors[0] = stake_selector;
    assert selectors[1] = unstake_selector;
    assert selectors[2] = set_strategy_registry_selector;

    //##########################################
    //             Create New Index
    //##########################################

    local index_factory_address;
    %{ ids.index_factory_address = context.index_factory_address %}

    // Transfer initial tokens to Factory
    %{ stop_prank_callable = start_prank(ids.admin, target_contract_address=ids.ERC20_1) %}
    IERC20.transfer(ERC20_1, index_factory_address, Uint256(amounts[0], 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.admin, target_contract_address=ids.ERC20_2) %}
    IERC20.transfer(ERC20_2, index_factory_address, Uint256(amounts[1], 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.admin, target_contract_address=ids.ERC20_3) %}
    IERC20.transfer(ERC20_3, index_factory_address, Uint256(amounts[2], 0));
    %{ stop_prank_callable() %}

    // Create Index
    %{ stop_prank_callable = start_prank(ids.admin, target_contract_address=ids.index_factory_address) %}
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
        selectors,
    );
    %{ stop_prank_callable() %}

    //##########################################
    //             Perform Tests
    //##########################################

    // Check that ERC20 functions are callable
    let (actual_name) = IERC20.name(new_index_address);
    assert_eq(name, actual_name);

    // Check that Initial index state is as expected
    let (initial_mint_amount: Uint256) = IERC20.balanceOf(new_index_address, admin);
    assert_eq(initial_mint_amount.low, base);

    let (actual_assets_len) = IIndex.num_assets(new_index_address);
    assert_eq(actual_assets_len, assets_len);

    let (asset0: Asset) = IIndex.assets(new_index_address, 0);
    assert_eq(asset0.address, ERC20_1);
    let (asset1: Asset) = IIndex.assets(new_index_address, 1);
    assert_eq(asset1.address, ERC20_2);
    let (asset2: Asset) = IIndex.assets(new_index_address, 2);
    assert_eq(asset2.address, ERC20_3);

    %{ print(ids.new_index_address) %}

    //##########################################
    //               Join Indice
    //##########################################

    local join_token_amount: Uint256 = Uint256(base, 0);

    let (local asset_amounts_len, local asset_amounts: Uint256*) = IIndex.get_amounts_to_mint(
        new_index_address, join_token_amount
    );

    // Send Tokens to user1
    %{ stop_prank_callable = start_prank(ids.admin, target_contract_address=ids.ERC20_1) %}
    IERC20.transfer(ERC20_1, user1, Uint256(1000 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.admin, target_contract_address=ids.ERC20_2) %}
    IERC20.transfer(ERC20_2, user1, Uint256(1000 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.admin, target_contract_address=ids.ERC20_3) %}
    IERC20.transfer(ERC20_3, user1, Uint256(1000 * base, 0));
    %{ stop_prank_callable() %}

    // Save original balance of user1
    let (local original_user_balance_1: Uint256) = IERC20.balanceOf(ERC20_1, user1);
    let (local original_user_balance_2: Uint256) = IERC20.balanceOf(ERC20_2, user1);
    let (local original_user_balance_3: Uint256) = IERC20.balanceOf(ERC20_3, user1);
    // Save original balance of index
    let (local original_index_balance_1: Uint256) = IERC20.balanceOf(ERC20_1, new_index_address);
    let (local original_index_balance_2: Uint256) = IERC20.balanceOf(ERC20_2, new_index_address);
    let (local original_index_balance_3: Uint256) = IERC20.balanceOf(ERC20_3, new_index_address);

    // Approve token transfers from user1 to Index
    %{ stop_prank_callable = start_prank(ids.user1, target_contract_address=ids.ERC20_1) %}
    IERC20.approve(ERC20_1, new_index_address, Uint256(1000 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.user1, target_contract_address=ids.ERC20_2) %}
    IERC20.approve(ERC20_2, new_index_address, Uint256(1000 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.user1, target_contract_address=ids.ERC20_3) %}
    IERC20.approve(ERC20_3, new_index_address, Uint256(1000 * base, 0));
    %{ stop_prank_callable() %}

    // Mint tokens
    %{ stop_prank_callable = start_prank(ids.user1, target_contract_address=ids.new_index_address) %}
    IIndex.mint(new_index_address, join_token_amount);
    %{ stop_prank_callable() %}

    // Check that minted amount is correct
    let (mint_fee) = IIndex.mint_fee(new_index_address);
    let (fee_amount: Uint256) = Utils.fmul(
        join_token_amount, Uint256(mint_fee, 0), Uint256(MAX_BPS, 0)
    );
    let (user1_calculated_index_balance: Uint256) = uint256_sub(join_token_amount, fee_amount);
    let (user1_actual_index_balance: Uint256) = IERC20.balanceOf(new_index_address, user1);
    assert_eq(user1_actual_index_balance.low, user1_calculated_index_balance.low);
    assert_eq(user1_actual_index_balance.high, user1_calculated_index_balance.high);

    // Check user token amounts are correct
    let (local new_user_balance_1: Uint256) = IERC20.balanceOf(ERC20_1, user1);
    let (local new_user_balance_2: Uint256) = IERC20.balanceOf(ERC20_2, user1);
    let (local new_user_balance_3: Uint256) = IERC20.balanceOf(ERC20_3, user1);
    let (removed_amount1: Uint256) = uint256_sub(original_user_balance_1, new_user_balance_1);
    let (removed_amount2: Uint256) = uint256_sub(original_user_balance_2, new_user_balance_2);
    let (removed_amount3: Uint256) = uint256_sub(original_user_balance_3, new_user_balance_3);
    assert_eq(removed_amount1.low, asset_amounts[0].low);
    assert_eq(removed_amount2.low, asset_amounts[1].low);
    assert_eq(removed_amount3.low, asset_amounts[2].low);
    // Check that index token amounts are correct
    let (local new_index_balance_1: Uint256) = IERC20.balanceOf(ERC20_1, new_index_address);
    let (local new_index_balance_2: Uint256) = IERC20.balanceOf(ERC20_2, new_index_address);
    let (local new_index_balance_3: Uint256) = IERC20.balanceOf(ERC20_3, new_index_address);
    let (added_amount1: Uint256) = uint256_sub(new_index_balance_1, original_index_balance_1);
    let (added_amount2: Uint256) = uint256_sub(new_index_balance_2, original_index_balance_2);
    let (added_amount3: Uint256) = uint256_sub(new_index_balance_3, original_index_balance_3);
    assert_eq(removed_amount1.low, added_amount1.low);
    assert_eq(removed_amount2.low, added_amount2.low);
    assert_eq(removed_amount3.low, added_amount3.low);

    //##########################################
    //              Stake Tokens
    //##########################################

    // Store initial values for later checks
    let (initial_assets_num) = IIndex.num_assets(new_index_address);

    // Get ERC4626 vault that we will be staking in
    local yagi_vault_address;
    %{ ids.yagi_vault_address = context.yagi_vault_address %}

    // Stake Asset
    %{ stop_prank_callable = start_prank(ids.admin, target_contract_address=ids.new_index_address) %}
    IIndex.stake(new_index_address, new_index_balance_1, ERC20_1, protocol1);
    %{ stop_prank_callable() %}

    // Check that token balance are as expected
    let (local underlying_token_balance: Uint256) = IERC20.balanceOf(ERC20_1, new_index_address);
    let (local wrapped_token_balance: Uint256) = IERC20.balanceOf(
        yagi_vault_address, new_index_address
    );

    assert_eq(underlying_token_balance.low, 0);
    assert_eq(wrapped_token_balance.low, new_index_balance_1.low);

    // Check that stored index tokens are correct
    let (new_assets_num) = IIndex.num_assets(new_index_address);
    assert_eq(new_assets_num, initial_assets_num);
    let (newly_add_asset: Asset) = IIndex.assets(new_index_address, new_assets_num - 1);
    assert_eq(newly_add_asset.address, yagi_vault_address);

    //##########################################
    //            Unstake Tokens
    //##########################################

    // Uint256(UINT128,UINT128) will unstake the total balance, no matter what the value is
    %{ stop_prank_callable = start_prank(ids.admin, target_contract_address=ids.new_index_address) %}
    let (local unstaked_amount: Uint256) = IIndex.unstake(
        new_index_address, Uint256(UINT128, UINT128), yagi_vault_address, protocol1
    );
    %{ stop_prank_callable() %}

    // Check that token balance are as expected
    let (local underlying_token_balance: Uint256) = IERC20.balanceOf(ERC20_1, new_index_address);
    let (local wrapped_token_balance: Uint256) = IERC20.balanceOf(
        yagi_vault_address, new_index_address
    );
    assert_eq(underlying_token_balance.low, new_index_balance_1.low);
    assert_eq(wrapped_token_balance.low, 0);

    // Check that stored index tokens are correct
    let (new_assets_num) = IIndex.num_assets(new_index_address);
    assert_eq(new_assets_num, initial_assets_num);
    let (newly_add_asset: Asset) = IIndex.assets(new_index_address, new_assets_num - 1);
    assert_eq(newly_add_asset.address, ERC20_1);

    return ();
}
