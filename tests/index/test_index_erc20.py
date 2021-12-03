import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode

def uint(a):
    return(a, 0)

MAX_AMOUNT = (2**128 - 1, 2**128 - 1)

@pytest.mark.asyncio
async def test_transfer(index, owner):
    owner_signer, owner_account = owner
    recipient = 123
    amount = uint(100)

    minting_amount = uint(1000)
    await owner_signer.send_transaction(owner_account, index.contract_address, 'mint', [owner_account.contract_address, *minting_amount])
    execution_info = await index.totalSupply().call()
    previous_supply = execution_info.result.totalSupply

    execution_info = await index.balanceOf(owner_account.contract_address).call()
    assert execution_info.result.balance == uint(1000)

    execution_info = await index.balanceOf(recipient).call()
    assert execution_info.result.balance == uint(0)

    # transfer
    return_bool = await owner_signer.send_transaction(owner_account, index.contract_address, 'transfer', [recipient, *amount])
    # check return value equals true ('1')
    assert return_bool.result.response == [1]

    execution_info = await index.balanceOf(owner_account.contract_address).call()
    assert execution_info.result.balance == uint(900)

    execution_info = await index.balanceOf(recipient).call()
    assert execution_info.result.balance == uint(100)

    execution_info = await index.totalSupply().call()
    assert execution_info.result.totalSupply == previous_supply


@pytest.mark.asyncio
async def test_insufficient_sender_funds(index, owner):
    owner_signer, owner_account = owner
    recipient = 123
    execution_info = await index.balanceOf(owner_account.contract_address).call()
    balance = execution_info.result.balance

    try:
        await owner_signer.send_transaction(owner_account, index.contract_address, 'transfer', [
            recipient,
            *uint(balance[0] + 1)
        ])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_approve(index, owner):
    owner_signer, owner_account = owner
    spender = 123
    amount = uint(345)

    execution_info = await index.allowance(owner_account.contract_address, spender).call()
    assert execution_info.result.remaining == uint(0)

    # set approval
    return_bool = await owner_signer.send_transaction(owner_account, index.contract_address, 'approve', [spender, *amount])
    # check return value equals true ('1')
    assert return_bool.result.response == [1]

    execution_info = await index.allowance(owner_account.contract_address, spender).call()
    assert execution_info.result.remaining == amount


@pytest.mark.asyncio
async def test_transferFrom(index, owner, starknet):
    owner_signer, owner_account = owner
    spender = await starknet.deploy(
        "contracts/test/Account.cairo",
        constructor_calldata=[owner_signer.public_key]
    )
    # we use the same owner_signer to control the main and the spender accounts
    # this is ok since they're still two different accounts
    amount = uint(345)
    recipient = 987

    minting_amount = uint(1000)
    await owner_signer.send_transaction(owner_account, index.contract_address, 'mint', [owner_account.contract_address, *minting_amount])
    execution_info = await index.balanceOf(owner_account.contract_address).call()
    previous_balance = execution_info.result.balance
    # approve
    await owner_signer.send_transaction(owner_account, index.contract_address, 'approve', [spender.contract_address, *amount])
    # transferFrom
    return_bool = await owner_signer.send_transaction(
        spender, index.contract_address, 'transferFrom', [
            owner_account.contract_address, recipient, *amount])
    # check return value equals true ('1')
    assert return_bool.result.response == [1]

    execution_info = await index.balanceOf(owner_account.contract_address).call()
    assert execution_info.result.balance == (
        uint(previous_balance[0] - amount[0])
    )

    execution_info = await index.balanceOf(recipient).call()
    assert execution_info.result.balance == amount

    execution_info = await index.allowance(owner_account.contract_address, spender.contract_address).call()
    assert execution_info.result.remaining == uint(0)


@pytest.mark.asyncio
async def test_increaseAllowance(index, owner):
    owner_signer, owner_account = owner
    # new spender, starting from zero
    spender = 234
    amount = uint(345)

    execution_info = await index.allowance(owner_account.contract_address, spender).call()
    assert execution_info.result.remaining == uint(0)

    # set approve
    await owner_signer.send_transaction(owner_account, index.contract_address, 'approve', [spender, *amount])

    execution_info = await index.allowance(owner_account.contract_address, spender).call()
    assert execution_info.result.remaining == amount

    # increase allowance
    return_bool = await owner_signer.send_transaction(owner_account, index.contract_address, 'increaseAllowance', [spender, *amount])
    # check return value equals true ('1')
    assert return_bool.result.response == [1]

    execution_info = await index.allowance(owner_account.contract_address, spender).call()
    assert execution_info.result.remaining == (
        uint(amount[0] * 2)
    )


@pytest.mark.asyncio
async def test_decreaseAllowance(index, owner):
    owner_signer, owner_account = owner
    # new spender, starting from zero
    spender = 321
    init_amount = uint(345)
    subtract_amount = uint(100)

    execution_info = await index.allowance(owner_account.contract_address, spender).call()
    assert execution_info.result.remaining == uint(0)

    # set approve
    await owner_signer.send_transaction(owner_account, index.contract_address, 'approve', [spender, *init_amount])

    execution_info = await index.allowance(owner_account.contract_address, spender).call()
    assert execution_info.result.remaining == init_amount

    # decrease allowance
    return_bool = await owner_signer.send_transaction(owner_account, index.contract_address, 'decreaseAllowance', [spender, *subtract_amount])
    # check return value equals true ('1')
    assert return_bool.result.response == [1]

    execution_info = await index.allowance(owner_account.contract_address, spender).call()
    assert execution_info.result.remaining == (
        uint(init_amount[0] - subtract_amount[0])
    )


@pytest.mark.asyncio
async def test_decreaseAllowance_underflow(index, owner):
    owner_signer, owner_account = owner
    # new spender, starting from zero
    spender = 987
    init_amount = uint(345)
    await owner_signer.send_transaction(owner_account, index.contract_address, 'approve', [spender, *init_amount])

    execution_info = await index.allowance(owner_account.contract_address, spender).call()
    assert execution_info.result.remaining == init_amount

    try:
        # increasing the decreased allowance amount by more than the user's allowance
        await owner_signer.send_transaction(owner_account, index.contract_address, 'decreaseAllowance', [
            spender,
            *uint(init_amount[0] + 1)
        ])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_transfer_funds_greater_than_allowance(index, owner, starknet):
    owner_signer, owner_account = owner
    spender = await starknet.deploy(
        "contracts/test/Account.cairo",
        constructor_calldata=[owner_signer.public_key]
    )
    # we use the same owner_signer to control the main and the spender accounts
    # this is ok since they're still two different accounts
    recipient = 222
    allowance = uint(111)
    await owner_signer.send_transaction(owner_account, index.contract_address, 'approve', [spender.contract_address, *allowance])

    try:
        # increasing the transfer amount above allowance
        await owner_signer.send_transaction(spender, index.contract_address, 'transferFrom', [
            owner_account.contract_address,
            recipient,
            *uint(allowance[0] + 1)
        ])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_increaseAllowance_overflow(index, owner):
    owner_signer, owner_account = owner
    # new spender, starting from zero
    spender = 234
    amount = (MAX_AMOUNT)
    # overflow_amount adds (1, 0) to (2**128 - 1, 2**128 - 1)
    overflow_amount = uint(1)
    await owner_signer.send_transaction(owner_account, index.contract_address, 'approve', [spender, *amount])

    try:
        # overflow check will revert the transaction
        await owner_signer.send_transaction(owner_account, index.contract_address, 'increaseAllowance', [spender, *overflow_amount])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_transfer_to_zero_address(index, owner):
    owner_signer, owner_account = owner
    recipient = 0
    amount = uint(1)

    try:
        await owner_signer.send_transaction(owner_account, index.contract_address, 'transfer', [recipient, *amount])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_transferFrom_zero_address(index, owner):
    owner_signer, owner_account = owner
    recipient = 123
    amount = uint(1)

    # Without using an owner_account abstraction, the caller address
    # (get_caller_address) is zero
    try:
        await index.transfer(recipient, amount).invoke()
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_transferFrom_func_to_zero_address(index, owner, starknet):
    owner_signer, owner_account = owner
    spender = await starknet.deploy(
        "contracts/test/Account.cairo",
        constructor_calldata=[owner_signer.public_key]
    )
    # we use the same owner_signer to control the main and the spender accounts
    # this is ok since they're still two different accounts
    amount = uint(1)
    zero_address = 0

    await owner_signer.send_transaction(owner_account, index.contract_address, 'approve', [spender.contract_address, *amount])

    try:
        await owner_signer.send_transaction(
            spender, index.contract_address, 'transferFrom',
            [
                owner_account.contract_address,
                zero_address,
                *amount
            ])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_transferFrom_func_from_zero_address(index, owner, starknet):
    owner_signer, owner_account = owner
    spender = await starknet.deploy(
        "contracts/test/Account.cairo",
        constructor_calldata=[owner_signer.public_key]
    )
    # we use the same owner_signer to control the main and the spender accounts
    # this is ok since they're still two different accounts
    zero_address = 0
    recipient = 123
    amount = uint(1)

    try:
        await owner_signer.send_transaction(
            spender, index.contract_address, 'transferFrom',
            [
                zero_address,
                recipient,
                *amount
            ])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_approve_zero_address_spender(index, owner):
    owner_signer, owner_account = owner
    spender = 0
    amount = uint(1)

    try:
        await owner_signer.send_transaction(owner_account, index.contract_address, 'approve', [spender, *amount])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_approve_zero_address_caller(index, owner):
    owner_signer, owner_account = owner
    spender = 123
    amount = uint(345)

    # Without using an owner_account abstraction, the caller address
    # (get_caller_address) is zero
    try:
        await index.approve(spender, amount).invoke()
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED
