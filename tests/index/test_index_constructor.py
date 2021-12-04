import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode

def uint(a):
    return(a, 0)

@pytest.mark.asyncio
async def test_name(index, index_name):
    execution_info = await index.name().call()
    assert execution_info.result == (index_name,)

@pytest.mark.asyncio
async def test_symbol(index, index_symbol):
    execution_info = await index.symbol().call()
    assert execution_info.result == (index_symbol,)

@pytest.mark.asyncio
async def test_decimals(index):
    execution_info = await index.decimals().call()
    assert execution_info.result == (18,)

@pytest.mark.asyncio
async def test_total_supply(index):
    execution_info = await index.totalSupply().call()
    assert execution_info.result == (uint(0),)

@pytest.mark.asyncio
async def test_owner(index, owner):
    owner_signer, owner_account = owner
    execution_info = await index.owner().call()
    assert execution_info.result == (owner_account.contract_address,)

@pytest.mark.asyncio
async def test_fee_recipient(index, owner):
    owner_signer, owner_account = owner
    execution_info = await index.fee_recipient().call()
    assert execution_info.result == (owner_account.contract_address,)

@pytest.mark.asyncio
async def test_mint_fee(index, owner):
    owner_signer, owner_account = owner
    execution_info = await index.mint_fee().call()
    assert execution_info.result == (0,)

@pytest.mark.asyncio
async def test_burn_fee(index, owner):
    owner_signer, owner_account = owner
    execution_info = await index.burn_fee().call()
    assert execution_info.result == (0,)
