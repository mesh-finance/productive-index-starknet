import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils.Signer import Signer

index_name_string = "Mesh Generic Index"
index_symbol_string = "MGI"

def uint(a):
    return(a, 0)

def str_to_felt(text):
    b_text = bytes(text, 'UTF-8')
    return int.from_bytes(b_text, "big")


@pytest.fixture
def event_loop():
    return asyncio.new_event_loop()

@pytest.fixture
async def starknet():
    starknet = await Starknet.empty()
    return starknet


@pytest.fixture
async def owner(starknet):
    owner_signer = Signer(123456789987654321)
    owner_account = await starknet.deploy(
        "contracts/test/Account.cairo",
        constructor_calldata=[owner_signer.public_key]
    )

    return owner_signer, owner_account

@pytest.fixture
async def random_acc(starknet):
    random_signer = Signer(987654320023456789)
    random_account = await starknet.deploy(
        "contracts/test/Account.cairo",
        constructor_calldata=[random_signer.public_key]
    )

    return random_signer, random_account

@pytest.fixture
async def user_1(starknet):
    user_1_signer = Signer(987654321123456789)
    user_1_account = await starknet.deploy(
        "contracts/test/Account.cairo",
        constructor_calldata=[user_1_signer.public_key]
    )

    return user_1_signer, user_1_account

@pytest.fixture
async def fee_recipient(starknet):
    fee_recipient_signer = Signer(987654301103456789)
    fee_recipient_account = await starknet.deploy(
        "contracts/test/Account.cairo",
        constructor_calldata=[fee_recipient_signer.public_key]
    )
    return fee_recipient_signer, fee_recipient_account

@pytest.fixture
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

@pytest.fixture
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

@pytest.fixture
async def index_name():
    return str_to_felt(index_name_string)

@pytest.fixture
async def index_symbol():
    return str_to_felt(index_symbol_string)

@pytest.fixture
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

@pytest.fixture
async def index_with_2_assets(index, asset_1, asset_2, owner, random_acc):
    owner_signer, owner_account = owner
    random_signer, random_account = random_acc
    
    execution_info = await asset_1.decimals().call()
    asset_1_decimals = execution_info.result.decimals
    amount_asset_1 = 10 ** asset_1_decimals
    ## Mint asset_1 to owner and approve for index
    await random_signer.send_transaction(random_account, asset_1.contract_address, 'mint', [owner_account.contract_address, *uint(amount_asset_1)])
    await owner_signer.send_transaction(owner_account, asset_1.contract_address, 'approve', [index.contract_address, *uint(amount_asset_1)])
    
    execution_info = await asset_2.decimals().call()
    asset_2_decimals = execution_info.result.decimals
    amount_asset_2 = 10 ** asset_2_decimals
    ## Mint asset_2 to owner and approve for index
    await random_signer.send_transaction(random_account, asset_2.contract_address, 'mint', [owner_account.contract_address, *uint(amount_asset_2)])
    await owner_signer.send_transaction(owner_account, asset_2.contract_address, 'approve', [index.contract_address, *uint(amount_asset_2)])
    
    await owner_signer.send_transaction(owner_account, index.contract_address, 'initial_mint', [
        2,
        asset_1.contract_address,
        asset_2.contract_address,
        2,
        amount_asset_1,
        amount_asset_2
    ])

    return index