import pytest
import asyncio
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode

new_mint_fee = new_burn_fee = 400
new_invalid_mint_fee = new_invalid_burn_fee = 1400

@pytest.mark.asyncio
async def test_update_mint_fee_non_owner(index, random_acc):
    random_signer, random_account = random_acc

    try:
        await random_signer.send_transaction(random_account, index.contract_address, 'update_mint_fee', [new_mint_fee])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.mark.asyncio
async def test_update_mint_fee_invalid_fee(index, owner):
    owner_signer, owner_account = owner

    try:
        await owner_signer.send_transaction(owner_account, index.contract_address, 'update_mint_fee', [new_invalid_mint_fee])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.mark.asyncio
async def test_update_mint_fee(index, owner):
    owner_signer, owner_account = owner

    await owner_signer.send_transaction(owner_account, index.contract_address, 'update_mint_fee', [new_mint_fee])

    execution_info = await index.mint_fee().call()
    print(f"Check new mint fee is {new_mint_fee}")
    assert execution_info.result == (new_mint_fee, )


@pytest.mark.asyncio
async def test_update_burn_fee_non_owner(index, random_acc):
    random_signer, random_account = random_acc

    try:
        await random_signer.send_transaction(random_account, index.contract_address, 'update_burn_fee', [new_burn_fee])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.mark.asyncio
async def test_update_burn_fee_invalid_fee(index, owner):
    owner_signer, owner_account = owner

    try:
        await owner_signer.send_transaction(owner_account, index.contract_address, 'update_burn_fee', [new_invalid_burn_fee])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.mark.asyncio
async def test_update_burn_fee(index, owner):
    owner_signer, owner_account = owner

    await owner_signer.send_transaction(owner_account, index.contract_address, 'update_burn_fee', [new_burn_fee])

    execution_info = await index.burn_fee().call()
    print(f"Check new burn fee is {new_burn_fee}")
    assert execution_info.result == (new_burn_fee, )

@pytest.mark.asyncio
async def test_update_fee_recipient_non_owner(index, random_acc, fee_recipient):
    random_signer, random_account = random_acc
    fee_recipient_signer, fee_recipient_account = fee_recipient

    try:
        await random_signer.send_transaction(random_account, index.contract_address, 'update_fee_recipient', [fee_recipient_account.contract_address])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.mark.asyncio
async def test_update_fee_recipient_zero_address(index, owner):
    owner_signer, owner_account = owner

    try:
        await owner_signer.send_transaction(owner_account, index.contract_address, 'update_fee_recipient', [0])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.mark.asyncio
async def test_update_fee_recipient(index, owner, fee_recipient):
    owner_signer, owner_account = owner
    fee_recipient_signer, fee_recipient_account = fee_recipient

    await owner_signer.send_transaction(owner_account, index.contract_address, 'update_fee_recipient', [fee_recipient_account.contract_address])

    execution_info = await index.fee_recipient().call()
    print(f"Check new fee recipient is {fee_recipient_account.contract_address}")
    assert execution_info.result == (fee_recipient_account.contract_address, )
