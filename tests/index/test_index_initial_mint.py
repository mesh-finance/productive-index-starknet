import pytest
import asyncio
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode

def uint(a):
    return(a, 0)

def str_to_felt(text):
    b_text = bytes(text, 'UTF-8')
    return int.from_bytes(b_text, "big")

@pytest.mark.asyncio
async def test_initial_mint_non_owner(index, asset_1, asset_2, random_acc):
    random_signer, random_account = random_acc
    execution_info = await asset_1.decimals().call()
    asset_1_decimals = execution_info.result.decimals
    amount_asset_1 = 10 ** asset_1_decimals
    execution_info = await asset_2.decimals().call()
    asset_2_decimals = execution_info.result.decimals
    amount_asset_2 = 10 ** asset_2_decimals
    try:
        await random_signer.send_transaction(random_account, index.contract_address, 'initial_mint', [
            2,
            asset_1.contract_address,
            asset_2.contract_address,
            2,
            amount_asset_1,
            amount_asset_2
        ])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.mark.asyncio
async def test_initial_mint_single_asset(index, asset_1, owner):
    owner_signer, owner_account = owner
    execution_info = await asset_1.decimals().call()
    asset_1_decimals = execution_info.result.decimals
    amount_asset_1 = 10 ** asset_1_decimals
    try:
        await owner_signer.send_transaction(owner_account, index.contract_address, 'initial_mint', [
            1,
            asset_1.contract_address,
            1,
            amount_asset_1
        ])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.mark.asyncio
async def test_initial_mint_wrong_array_length(index, asset_1, asset_2, owner):
    owner_signer, owner_account = owner
    execution_info = await asset_1.decimals().call()
    asset_1_decimals = execution_info.result.decimals
    amount_asset_1 = 10 ** asset_1_decimals
    try:
        await owner_signer.send_transaction(owner_account, index.contract_address, 'initial_mint', [
            2,
            asset_1.contract_address,
            asset_2.contract_address,
            1,
            amount_asset_1
        ])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.mark.asyncio
async def test_initial_mint_without_balance(index, asset_1, asset_2, owner):
    owner_signer, owner_account = owner
    execution_info = await asset_1.decimals().call()
    asset_1_decimals = execution_info.result.decimals
    amount_asset_1 = 10 ** asset_1_decimals
    execution_info = await asset_2.decimals().call()
    asset_2_decimals = execution_info.result.decimals
    amount_asset_2 = 10 ** asset_2_decimals
    try:
        await owner_signer.send_transaction(owner_account, index.contract_address, 'initial_mint', [
            2,
            asset_1.contract_address,
            asset_2.contract_address,
            2,
            amount_asset_1,
            amount_asset_2
        ])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.mark.asyncio
async def test_initial_mint_without_approval(index, asset_1, asset_2, owner, random_acc):
    owner_signer, owner_account = owner
    random_signer, random_account = random_acc
    
    execution_info = await asset_1.decimals().call()
    asset_1_decimals = execution_info.result.decimals
    amount_asset_1 = 10 ** asset_1_decimals
    ## Mint asset_1 to owner and approve for index
    await random_signer.send_transaction(random_account, asset_1.contract_address, 'mint', [owner_account.contract_address, *uint(amount_asset_1)])
    
    execution_info = await asset_2.decimals().call()
    asset_2_decimals = execution_info.result.decimals
    amount_asset_2 = 10 ** asset_2_decimals
    ## Mint asset_2 to owner and approve for index
    await random_signer.send_transaction(random_account, asset_2.contract_address, 'mint', [owner_account.contract_address, *uint(amount_asset_2)])
    
    try:
        await owner_signer.send_transaction(owner_account, index.contract_address, 'initial_mint', [
            2,
            asset_1.contract_address,
            asset_2.contract_address,
            2,
            amount_asset_1,
            amount_asset_2
        ])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.mark.asyncio
async def test_initial_mint_2_assets(index, asset_1, asset_2, owner, random_acc):
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

    execution_info = await asset_1.balanceOf(owner_account.contract_address).call()
    print(f"Check: Initial asset_1 balance for owner is {amount_asset_1}")
    assert execution_info.result.balance == uint(amount_asset_1)

    execution_info = await asset_2.balanceOf(owner_account.contract_address).call()
    print(f"Check: Initial asset_2 balance for owner is {amount_asset_2}")
    assert execution_info.result.balance == uint(amount_asset_2)

    execution_info = await index.totalSupply().call()
    print("Check: Initial total supply is 0")
    assert execution_info.result.totalSupply == uint(0)
    
    await owner_signer.send_transaction(owner_account, index.contract_address, 'initial_mint', [
        2,
        asset_1.contract_address,
        asset_2.contract_address,
        2,
        amount_asset_1,
        amount_asset_2
    ])

    execution_info = await index.num_assets().call()
    print("Check: Number of constituent assets is 2")
    assert execution_info.result.res == 2

    execution_info = await index.assets(0).call()
    print("Check: First asset")
    assert execution_info.result.asset == (asset_1.contract_address, uint(amount_asset_1))

    execution_info = await index.assets(1).call()
    print("Check: Second asset")
    assert execution_info.result.asset == (asset_2.contract_address, uint(amount_asset_2))

    execution_info = await index.decimals().call()
    index_decimals = execution_info.result.decimals

    execution_info = await index.totalSupply().call()
    print(f"Check: Final total supply is {10 ** index_decimals}")
    assert execution_info.result.totalSupply == uint(10 ** index_decimals)

    execution_info = await asset_1.balanceOf(owner_account.contract_address).call()
    print("Check: Final asset_1 balance for owner is 0")
    assert execution_info.result.balance == uint(0)

    execution_info = await asset_2.balanceOf(owner_account.contract_address).call()
    print("Check: Final asset_2 balance for owner is 0")
    assert execution_info.result.balance == uint(0)

    execution_info = await index.balanceOf(owner_account.contract_address).call()
    print(f"Check: Final index balance for owner is {10 ** index_decimals}")
    assert execution_info.result.balance == uint(10 ** index_decimals)


@pytest.mark.asyncio
async def test_initial_mint_10_assets(starknet, index, owner, random_acc):
    owner_signer, owner_account = owner
    random_signer, random_account = random_acc

    assets = []
    asset_contracts = []
    amounts = []

    for i in range(0, 10):
        asset = await starknet.deploy(
            "contracts/test/token/ERC20.cairo",
            constructor_calldata=[
                str_to_felt(f"Asset {i}"),  # name
                str_to_felt(f"ASSET{i}"),  # symbol
                random_account.contract_address
            ]
        )
        
        execution_info = await asset.decimals().call()
        asset_decimals = execution_info.result.decimals
        amount_asset = 10 ** asset_decimals
        ## Mint asset to owner and approve for index
        await random_signer.send_transaction(random_account, asset.contract_address, 'mint', [owner_account.contract_address, *uint(amount_asset)])
        await owner_signer.send_transaction(owner_account, asset.contract_address, 'approve', [index.contract_address, *uint(amount_asset)])

        execution_info = await asset.balanceOf(owner_account.contract_address).call()
        print(f"Check: Initial asset {i} balance for owner is {amount_asset}")
        assert execution_info.result.balance == uint(amount_asset)

        assets.append(asset)
        asset_contracts.append(asset.contract_address)
        amounts.append(amount_asset)

    execution_info = await index.totalSupply().call()
    print("Check: Initial total supply is 0")
    assert execution_info.result.totalSupply == uint(0)

    num_assets = len(assets)

    transaction_args = [num_assets] + asset_contracts + [num_assets] + amounts
    
    await owner_signer.send_transaction(owner_account, index.contract_address, 'initial_mint', transaction_args)

    execution_info = await index.num_assets().call()
    print(f"Check: Number of constituent assets is {num_assets}")
    assert execution_info.result.res == num_assets

    for i in range(0, 10):
        execution_info = await index.assets(i).call()
        print(f"Check: asset {i}")
        assert execution_info.result.asset == (assets[i].contract_address, uint(amounts[i]))

        execution_info = await assets[i].balanceOf(owner_account.contract_address).call()
        print(f"Check: Final asset_{i} balance for owner is 0")
        assert execution_info.result.balance == uint(0)

    execution_info = await index.decimals().call()
    index_decimals = execution_info.result.decimals

    execution_info = await index.totalSupply().call()
    print(f"Check: Final total supply is {10 ** index_decimals}")
    assert execution_info.result.totalSupply == uint(10 ** index_decimals)

    execution_info = await index.balanceOf(owner_account.contract_address).call()
    print(f"Check: Final index balance for owner is {10 ** index_decimals}")
    assert execution_info.result.balance == uint(10 ** index_decimals)


@pytest.mark.asyncio
async def test_initial_mint_11_assets(starknet, index, owner, random_acc):
    owner_signer, owner_account = owner
    random_signer, random_account = random_acc

    assets = []
    amounts = []

    for i in range(0, 11):
        asset = await starknet.deploy(
            "contracts/test/token/ERC20.cairo",
            constructor_calldata=[
                str_to_felt(f"Asset {i}"),  # name
                str_to_felt(f"ASSET{i}"),  # symbol
                random_account.contract_address
            ]
        )
        
        execution_info = await asset.decimals().call()
        asset_decimals = execution_info.result.decimals
        amount_asset = 10 ** asset_decimals
        ## Mint asset to owner and approve for index
        await random_signer.send_transaction(random_account, asset.contract_address, 'mint', [owner_account.contract_address, *uint(amount_asset)])
        await owner_signer.send_transaction(owner_account, asset.contract_address, 'approve', [index.contract_address, *uint(amount_asset)])

        execution_info = await asset.balanceOf(owner_account.contract_address).call()
        print(f"Check: Initial asset {i} balance for owner is {amount_asset}")
        assert execution_info.result.balance == uint(amount_asset)

        assets.append(asset)
        amounts.append(amount_asset)

    num_assets = len(assets)

    transaction_args = [num_assets] + assets + [num_assets] + amounts

    try:
        await owner_signer.send_transaction(owner_account, index.contract_address, 'initial_mint', transaction_args)
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED