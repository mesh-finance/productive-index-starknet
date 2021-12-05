import pytest
import asyncio
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode

def uint(a):
    return(a, 0)

@pytest.fixture
async def index_with_2_assets_and_sweepable_token(index_with_2_assets, sweepable_token, random_acc):
    random_signer, random_account = random_acc

    execution_info = await sweepable_token.decimals().call()
    sweepable_token_decimals = execution_info.result.decimals
    amount_sweepable_token = 10 ** sweepable_token_decimals

    await random_signer.send_transaction(random_account, sweepable_token.contract_address, 'mint', [index_with_2_assets.contract_address, *uint(amount_sweepable_token)])
    return index_with_2_assets

@pytest.mark.asyncio
async def test_sweep_non_owner(index_with_2_assets_and_sweepable_token, sweepable_token, random_acc):
    random_signer, random_account = random_acc

    try:
        await random_signer.send_transaction(random_account, index_with_2_assets_and_sweepable_token.contract_address, 'sweep', [sweepable_token.contract_address, random_account.contract_address])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.mark.asyncio
async def test_sweep_to_zero_address(index_with_2_assets_and_sweepable_token, sweepable_token, owner):
    owner_signer, owner_account = owner

    try:
        await owner_signer.send_transaction(owner_account, index_with_2_assets_and_sweepable_token.contract_address, 'sweep', [sweepable_token.contract_address, 0])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.mark.asyncio
async def test_sweep_zero_token(index_with_2_assets_and_sweepable_token, owner, random_acc):
    owner_signer, owner_account = owner
    random_signer, random_account = random_acc

    try:
        await owner_signer.send_transaction(owner_account, index_with_2_assets_and_sweepable_token.contract_address, 'sweep', [0, random_account.contract_address])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.mark.asyncio
async def test_sweep_constituent_asset(index_with_2_assets_and_sweepable_token, asset_1, owner, random_acc):
    owner_signer, owner_account = owner
    random_signer, random_account = random_acc

    try:
        await owner_signer.send_transaction(owner_account, index_with_2_assets_and_sweepable_token.contract_address, 'sweep', [asset_1.contract_address, random_account.contract_address])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.mark.asyncio
async def test_sweep(index_with_2_assets_and_sweepable_token, sweepable_token, owner, random_acc):
    owner_signer, owner_account = owner
    random_signer, random_account = random_acc

    execution_info = await sweepable_token.balanceOf(random_account.contract_address).call()
    random_account_sweepable_token_balance_initial = execution_info.result.balance[0]

    execution_info = await sweepable_token.balanceOf(index_with_2_assets_and_sweepable_token.contract_address).call()
    index_sweepable_token_balance_initial = execution_info.result.balance[0]

    await owner_signer.send_transaction(owner_account, index_with_2_assets_and_sweepable_token.contract_address, 'sweep', [sweepable_token.contract_address, random_account.contract_address])

    execution_info = await sweepable_token.balanceOf(random_account.contract_address).call()
    random_account_sweepable_token_balance_final = execution_info.result.balance[0]
    print(f"Check : Sweepable balance of random account")
    assert random_account_sweepable_token_balance_final == random_account_sweepable_token_balance_initial + index_sweepable_token_balance_initial

    execution_info = await sweepable_token.balanceOf(index_with_2_assets_and_sweepable_token.contract_address).call()
    index_sweepable_token_balance_final = execution_info.result.balance[0]
    print(f"Check : Sweepable balance of index is 0")
    assert index_sweepable_token_balance_final == 0