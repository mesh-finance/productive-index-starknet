import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils.Signer import Signer

index_name_string = "Mesh Generic Index"
index_symbol_string = "MGI"

def str_to_felt(text):
    b_text = bytes(text, 'UTF-8')
    return int.from_bytes(b_text, "big")


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()

@pytest.fixture(scope='module')
async def starknet():
    starknet = await Starknet.empty()
    return starknet


@pytest.fixture(scope='module')
async def owner(starknet):
    owner_signer = Signer(123456789987654321)
    owner_account = await starknet.deploy(
        "contracts/test/Account.cairo",
        constructor_calldata=[owner_signer.public_key]
    )

    return owner_signer, owner_account

@pytest.fixture(scope='module')
async def random_acc(starknet):
    random_signer = Signer(987654321123456789)
    random_account = await starknet.deploy(
        "contracts/test/Account.cairo",
        constructor_calldata=[random_signer.public_key]
    )

    return random_signer, random_account

@pytest.fixture(scope='module')
async def asset_1(starknet, random_acc):
    random_signer, random_account = random_acc
    asset_1 = await starknet.deploy(
        "contracts/test/token/ERC20.cairo",
        constructor_calldata=[
            str_to_felt("Asset 1"),  # name
            str_to_felt("ASSET1"),  # symbol
            random_account.contract_address
        ]
    )
    return asset_1

@pytest.fixture(scope='module')
async def asset_2(starknet, random_acc):
    random_signer, random_account = random_acc
    asset_2 = await starknet.deploy(
        "contracts/test/token/ERC20.cairo",
        constructor_calldata=[
            str_to_felt("Asset 2"),  # name
            str_to_felt("ASSET2"),  # symbol
            random_account.contract_address
        ]
    )
    return asset_2

@pytest.fixture(scope='module')
async def index_name():
    return str_to_felt(index_name_string)

@pytest.fixture(scope='module')
async def index_symbol():
    return str_to_felt(index_symbol_string)

@pytest.fixture(scope='module')
async def index(starknet, owner, index_name, index_symbol):
    owner_signer, owner_account = owner
    index = await starknet.deploy(
        "contracts/Index.cairo",
        constructor_calldata=[
            index_name,  # name
            index_symbol,  # symbol
            owner_account.contract_address   # initial_owner
        ]
    )
    return index