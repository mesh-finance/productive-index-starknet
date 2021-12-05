import pytest
import asyncio
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode

def uint(a):
    return(a, 0)

burn_fee = 400

@pytest.mark.asyncio
async def test_burn_without_balance(index_with_2_assets_user_1_minted, random_acc):
    random_signer, random_account = random_acc

    execution_info = await index_with_2_assets_user_1_minted.decimals().call()
    index_decimals = execution_info.result.decimals
    amount_to_burn = 10 ** index_decimals
    
    try:
        await random_signer.send_transaction(random_account, index_with_2_assets_user_1_minted.contract_address, 'burn', [*uint(amount_to_burn)])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.mark.asyncio
async def test_burn_without_initial_mint(index, user_1):
    user_1_signer, user_1_account = user_1

    execution_info = await index.decimals().call()
    index_decimals = execution_info.result.decimals
    amount_to_burn = 10 ** index_decimals
    
    try:
        await user_1_signer.send_transaction(user_1_account, index.contract_address, 'burn', [*uint(amount_to_burn)])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.mark.asyncio
async def test_burn_less_than_minimum(index_with_2_assets_user_1_minted, user_1):
    user_1_signer, user_1_account = user_1
    amount_to_burn = 10 ** 5
    
    try:
        await user_1_signer.send_transaction(user_1_account, index_with_2_assets_user_1_minted.contract_address, 'burn', [*uint(amount_to_burn)])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.mark.asyncio
async def test_burn(index_with_2_assets_user_1_minted, user_1):
    user_1_signer, user_1_account = user_1

    execution_info = await index_with_2_assets_user_1_minted.decimals().call()
    index_decimals = execution_info.result.decimals
    amount_to_burn = 2 * 10 ** index_decimals

    execution_info = await index_with_2_assets_user_1_minted.num_assets().call()
    num_assets =  execution_info.result.num

    assets = []
    expected_amounts_out = []
    amounts_initial = []

    execution_info = await index_with_2_assets_user_1_minted.totalSupply().call()
    total_supply_initial = execution_info.result.totalSupply[0]

    execution_info = await index_with_2_assets_user_1_minted.balanceOf(user_1_account.contract_address).call()
    user_1_index_balance_initial = execution_info.result.balance[0]

    for i in range(0, num_assets):
        execution_info = await index_with_2_assets_user_1_minted.assets(i).call()
        asset_contract_address, amount_initial_asset =  execution_info.result.asset
        asset_expected_amount_out = amount_initial_asset[0] * amount_to_burn / total_supply_initial
        print(f"Initial balance for asset {i} in index: {amount_initial_asset[0]}")

        expected_amounts_out.append(asset_expected_amount_out)
        amounts_initial.append(amount_initial_asset[0])
    
    await user_1_signer.send_transaction(user_1_account, index_with_2_assets_user_1_minted.contract_address, 'burn', [*uint(amount_to_burn)])

    execution_info = await index_with_2_assets_user_1_minted.totalSupply().call()
    total_supply_final =  execution_info.result.totalSupply[0]
    print(f"Check: Final total supply: {total_supply_final}, {total_supply_initial}, {amount_to_burn}")
    assert total_supply_final == total_supply_initial - amount_to_burn
    
    execution_info = await index_with_2_assets_user_1_minted.balanceOf(user_1_account.contract_address).call()
    user_1_index_balance_final = execution_info.result.balance[0]
    print(f"Check: Final index balance for user_1: {user_1_index_balance_final}, {user_1_index_balance_initial}, {amount_to_burn}")
    assert user_1_index_balance_final == user_1_index_balance_initial - amount_to_burn

    for i in range(0, num_assets):
        execution_info = await index_with_2_assets_user_1_minted.assets(i).call()
        _, amount_final_asset =  execution_info.result.asset
        print(f"Check: final balance for asset {i} in index: {amount_final_asset[0]}, {amounts_initial[i]}, {expected_amounts_out[i]}")
        assert amount_final_asset[0] == amounts_initial[i] - expected_amounts_out[i]

@pytest.fixture()
async def index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient(index_with_2_assets_user_1_minted, owner, fee_recipient):
    owner_signer, owner_account = owner
    fee_recipient_signer, fee_recipient_account = fee_recipient

    await owner_signer.send_transaction(owner_account, index_with_2_assets_user_1_minted.contract_address, 'update_burn_fee', [burn_fee])
    await owner_signer.send_transaction(owner_account, index_with_2_assets_user_1_minted.contract_address, 'update_fee_recipient', [fee_recipient_account.contract_address])
    return index_with_2_assets_user_1_minted

@pytest.mark.asyncio
async def test_burn_with_burn_fee_and_fee_recipient(index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient, user_1, fee_recipient):
    user_1_signer, user_1_account = user_1
    fee_recipient_signer, fee_recipient_account = fee_recipient

    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.decimals().call()
    index_decimals = execution_info.result.decimals
    amount_to_burn = 2 * 10 ** index_decimals

    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.num_assets().call()
    num_assets =  execution_info.result.num

    assets = []
    expected_amounts_out = []
    amounts_initial = []

    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.totalSupply().call()
    total_supply_initial = execution_info.result.totalSupply[0]

    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.balanceOf(user_1_account.contract_address).call()
    user_1_index_balance_initial = execution_info.result.balance[0]

    expected_burn_fee = amount_to_burn * burn_fee / 10000

    amount_to_burn_after_fee = amount_to_burn - expected_burn_fee

    for i in range(0, num_assets):
        execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.assets(i).call()
        asset_contract_address, amount_initial_asset =  execution_info.result.asset
        asset_expected_amount_out = amount_initial_asset[0] * amount_to_burn_after_fee / total_supply_initial
        print(f"Initial balance for asset {i} in index: {amount_initial_asset[0]}")

        expected_amounts_out.append(asset_expected_amount_out)
        amounts_initial.append(amount_initial_asset[0])
    
    await user_1_signer.send_transaction(user_1_account, index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.contract_address, 'burn', [*uint(amount_to_burn)])

    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.totalSupply().call()
    total_supply_final =  execution_info.result.totalSupply[0]
    print(f"Check: Final total supply: {total_supply_final}, {total_supply_initial}, {amount_to_burn}")
    assert total_supply_final == total_supply_initial - amount_to_burn_after_fee
    
    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.balanceOf(user_1_account.contract_address).call()
    user_1_index_balance_final = execution_info.result.balance[0]
    print(f"Check: Final index balance for user_1: {user_1_index_balance_final}, {user_1_index_balance_initial}, {amount_to_burn}")
    assert user_1_index_balance_final == user_1_index_balance_initial - amount_to_burn

    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.balanceOf(fee_recipient_account.contract_address).call()
    fee_recipient_index_balance_final = execution_info.result.balance[0]
    print(f"Check: Final index balance for fee recipient: {fee_recipient_index_balance_final}, {expected_burn_fee}")
    assert fee_recipient_index_balance_final ==  expected_burn_fee

    for i in range(0, num_assets):
        execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.assets(i).call()
        _, amount_final_asset =  execution_info.result.asset
        print(f"Check: final balance for asset {i} in index: {amount_final_asset[0]}, {amounts_initial[i]}, {expected_amounts_out[i]}")
        assert amount_final_asset[0] == amounts_initial[i] - expected_amounts_out[i]

@pytest.mark.asyncio
async def test_burn_with_burn_fee_and_fee_recipient_from_owner(index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient, owner, fee_recipient):
    owner_signer, owner_account = owner
    fee_recipient_signer, fee_recipient_account = fee_recipient

    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.decimals().call()
    index_decimals = execution_info.result.decimals
    amount_to_burn = 10 ** index_decimals

    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.num_assets().call()
    num_assets =  execution_info.result.num

    assets = []
    expected_amounts_out = []
    amounts_initial = []

    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.totalSupply().call()
    total_supply_initial = execution_info.result.totalSupply[0]

    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.balanceOf(owner_account.contract_address).call()
    owner_index_balance_initial = execution_info.result.balance[0]

    expected_burn_fee = 0  ## 0 fee for owner

    amount_to_burn_after_fee = amount_to_burn - expected_burn_fee

    for i in range(0, num_assets):
        execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.assets(i).call()
        asset_contract_address, amount_initial_asset =  execution_info.result.asset
        asset_expected_amount_out = amount_initial_asset[0] * amount_to_burn_after_fee / total_supply_initial
        print(f"Initial balance for asset {i} in index: {amount_initial_asset[0]}")

        expected_amounts_out.append(asset_expected_amount_out)
        amounts_initial.append(amount_initial_asset[0])
    
    await owner_signer.send_transaction(owner_account, index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.contract_address, 'burn', [*uint(amount_to_burn)])

    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.totalSupply().call()
    total_supply_final =  execution_info.result.totalSupply[0]
    print(f"Check: Final total supply: {total_supply_final}, {total_supply_initial}, {amount_to_burn}")
    assert total_supply_final == total_supply_initial - amount_to_burn_after_fee
    
    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.balanceOf(owner_account.contract_address).call()
    owner_index_balance_final = execution_info.result.balance[0]
    print(f"Check: Final index balance for owner: {owner_index_balance_final}, {owner_index_balance_initial}, {amount_to_burn}")
    assert owner_index_balance_final == owner_index_balance_initial - amount_to_burn

    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.balanceOf(fee_recipient_account.contract_address).call()
    fee_recipient_index_balance_final = execution_info.result.balance[0]
    print(f"Check: Final index balance for fee recipient: {fee_recipient_index_balance_final}, {expected_burn_fee}")
    assert fee_recipient_index_balance_final ==  expected_burn_fee

    for i in range(0, num_assets):
        execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.assets(i).call()
        _, amount_final_asset =  execution_info.result.asset
        print(f"Check: final balance for asset {i} in index: {amount_final_asset[0]}, {amounts_initial[i]}, {expected_amounts_out[i]}")
        assert amount_final_asset[0] == amounts_initial[i] - expected_amounts_out[i]

@pytest.mark.asyncio
async def test_burn_with_burn_fee_and_fee_recipient_from_fee_recipient(index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient, owner, user_1):
    owner_signer, owner_account = owner
    user_1_signer, user_1_account = user_1

    ## Set user_1 as fee recipient
    await owner_signer.send_transaction(owner_account, index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.contract_address, 'update_fee_recipient', [user_1_account.contract_address])

    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.decimals().call()
    index_decimals = execution_info.result.decimals
    amount_to_burn = 2 * 10 ** index_decimals

    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.num_assets().call()
    num_assets =  execution_info.result.num

    assets = []
    expected_amounts_out = []
    amounts_initial = []

    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.totalSupply().call()
    total_supply_initial = execution_info.result.totalSupply[0]

    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.balanceOf(user_1_account.contract_address).call()
    user_1_index_balance_initial = execution_info.result.balance[0]

    expected_burn_fee = 0  ## 0 fee for fee recipient

    amount_to_burn_after_fee = amount_to_burn - expected_burn_fee

    for i in range(0, num_assets):
        execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.assets(i).call()
        asset_contract_address, amount_initial_asset =  execution_info.result.asset
        asset_expected_amount_out = amount_initial_asset[0] * amount_to_burn_after_fee / total_supply_initial
        print(f"Initial balance for asset {i} in index: {amount_initial_asset[0]}")

        expected_amounts_out.append(asset_expected_amount_out)
        amounts_initial.append(amount_initial_asset[0])
    
    await user_1_signer.send_transaction(user_1_account, index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.contract_address, 'burn', [*uint(amount_to_burn)])

    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.totalSupply().call()
    total_supply_final =  execution_info.result.totalSupply[0]
    print(f"Check: Final total supply: {total_supply_final}, {total_supply_initial}, {amount_to_burn}")
    assert total_supply_final == total_supply_initial - amount_to_burn_after_fee
    
    execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.balanceOf(user_1_account.contract_address).call()
    user_1_index_balance_final = execution_info.result.balance[0]
    print(f"Check: Final index balance for user_1: {user_1_index_balance_final}, {user_1_index_balance_initial}, {amount_to_burn}")
    assert user_1_index_balance_final == user_1_index_balance_initial - amount_to_burn

    for i in range(0, num_assets):
        execution_info = await index_with_2_assets_user_1_minted_with_burn_fee_and_fee_recipient.assets(i).call()
        _, amount_final_asset =  execution_info.result.asset
        print(f"Check: final balance for asset {i} in index: {amount_final_asset[0]}, {amounts_initial[i]}, {expected_amounts_out[i]}")
        assert amount_final_asset[0] == amounts_initial[i] - expected_amounts_out[i]