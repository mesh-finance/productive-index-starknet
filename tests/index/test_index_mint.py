import pytest
import asyncio
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode

def uint(a):
    return(a, 0)

mint_fee = 400

@pytest.mark.asyncio
async def test_initial_mint_again(index_with_2_assets, asset_1, asset_2, owner, random_acc):
    owner_signer, owner_account = owner
    random_signer, random_account = random_acc
    
    execution_info = await asset_1.decimals().call()
    asset_1_decimals = execution_info.result.decimals
    amount_asset_1 = 10 ** asset_1_decimals
    ## Mint asset_1 to owner and approve for index
    await random_signer.send_transaction(random_account, asset_1.contract_address, 'mint', [owner_account.contract_address, *uint(amount_asset_1)])
    await owner_signer.send_transaction(owner_account, asset_1.contract_address, 'approve', [index_with_2_assets.contract_address, *uint(amount_asset_1)])
    
    execution_info = await asset_2.decimals().call()
    asset_2_decimals = execution_info.result.decimals
    amount_asset_2 = 10 ** asset_2_decimals
    ## Mint asset_2 to owner and approve for index
    await random_signer.send_transaction(random_account, asset_2.contract_address, 'mint', [owner_account.contract_address, *uint(amount_asset_2)])
    await owner_signer.send_transaction(owner_account, asset_2.contract_address, 'approve', [index_with_2_assets.contract_address, *uint(amount_asset_2)])
    try:
        await owner_signer.send_transaction(owner_account, index_with_2_assets.contract_address, 'initial_mint', [
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
async def test_mint_without_balance(index_with_2_assets, asset_1, asset_2, owner):
    owner_signer, owner_account = owner

    execution_info = await index_with_2_assets.decimals().call()
    index_decimals = execution_info.result.decimals
    amount_to_mint = 10 ** index_decimals
    
    try:
        await owner_signer.send_transaction(owner_account, index_with_2_assets.contract_address, 'mint', [*uint(amount_to_mint)])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.mark.asyncio
async def test_mint_without_approval(index_with_2_assets, user_1, random_acc):
    user_1_signer, user_1_account = user_1
    random_signer, random_account = random_acc

    execution_info = await index_with_2_assets.decimals().call()
    index_decimals = execution_info.result.decimals
    amount_to_mint = 5 * 10 ** index_decimals

    execution_info = await index_with_2_assets.num_assets().call()
    num_assets =  execution_info.result.num

    for i in range(0, num_assets):
        execution_info = await index_with_2_assets.get_amount_to_mint(i, uint(amount_to_mint)).call()
        amount_to_transfer_asset = execution_info.result.amount
        execution_info = await index_with_2_assets.assets(i).call()
        asset_contract_address, amount_initial_asset =  execution_info.result.asset
        print(f"Minting {amount_to_transfer_asset} of asset {i} {asset_contract_address} to user_1")
        ## Mint asset to user_1
        await random_signer.send_transaction(random_account, asset_contract_address, 'mint', [user_1_account.contract_address, *amount_to_transfer_asset])
    
    try:
        await user_1_signer.send_transaction(user_1_account, index_with_2_assets.contract_address, 'mint', [*uint(amount_to_mint)])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_mint(index_with_2_assets, user_1, random_acc):
    user_1_signer, user_1_account = user_1
    random_signer, random_account = random_acc

    execution_info = await index_with_2_assets.decimals().call()
    index_decimals = execution_info.result.decimals
    amount_to_mint = 5 * 10 ** index_decimals

    execution_info = await index_with_2_assets.num_assets().call()
    num_assets =  execution_info.result.num

    assets = []
    amounts_to_transfer = []
    amounts_initial = []

    execution_info = await index_with_2_assets.totalSupply().call()
    total_supply_initial = execution_info.result.totalSupply[0]

    for i in range(0, num_assets):
        execution_info = await index_with_2_assets.get_amount_to_mint(i, uint(amount_to_mint)).call()
        amount_to_transfer_asset = execution_info.result.amount
        execution_info = await index_with_2_assets.assets(i).call()
        asset_contract_address, amount_initial_asset =  execution_info.result.asset
        print(f"Minting {amount_to_transfer_asset} of asset {i} {asset_contract_address} to user_1")
        ## Mint asset to user_1 and approve to index
        await random_signer.send_transaction(random_account, asset_contract_address, 'mint', [user_1_account.contract_address, *amount_to_transfer_asset])
        await user_1_signer.send_transaction(user_1_account, asset_contract_address, 'approve', [index_with_2_assets.contract_address, *amount_to_transfer_asset])

        amounts_to_transfer.append(amount_to_transfer_asset[0])
        amounts_initial.append(amount_initial_asset[0])

        # TODO
        # execution_info = await asset_contract_address.balanceOf(user_1_account.contract_address).call()
        # print(f"Check: Initial asset {i} balance for user_1 is {amount_to_transfer_asset}")
        # assert execution_info.result.balance == uint(amount_to_transfer_asset)
    
    await user_1_signer.send_transaction(user_1_account, index_with_2_assets.contract_address, 'mint', [*uint(amount_to_mint)])

    execution_info = await index_with_2_assets.totalSupply().call()
    total_supply_final =  execution_info.result.totalSupply[0]
    print(f"Check: Final total supply")
    assert total_supply_final == total_supply_initial + amount_to_mint
    
    execution_info = await index_with_2_assets.balanceOf(user_1_account.contract_address).call()
    user_1_index_balance_final = execution_info.result.balance[0]
    print(f"Check: Final index balance for user_1")
    assert user_1_index_balance_final == amount_to_mint

    # TODO
    # for i in range(0, num_assets):
    #     execution_info = await index_with_2_assets.assets(i).call()
    #     _, amount_final_asset =  execution_info.result.asset
    #     print(f"Check: final balance for asset {i} in index")
    #     assert amount_final_asset[0] == amounts_initial[i] + amounts_to_transfer[i]

@pytest.mark.asyncio
async def test_mint_without_initial_mint(index, user_1):
    user_1_signer, user_1_account = user_1

    execution_info = await index.decimals().call()
    index_decimals = execution_info.result.decimals
    amount_to_mint = 5 * 10 ** index_decimals
    
    try:
        await user_1_signer.send_transaction(user_1_account, index.contract_address, 'mint', [*uint(amount_to_mint)])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

@pytest.fixture()
async def index_with_2_assets_with_mint_fee_and_fee_recipient(index_with_2_assets, owner, fee_recipient):
    owner_signer, owner_account = owner
    fee_recipient_signer, fee_recipient_account = fee_recipient

    await owner_signer.send_transaction(owner_account, index_with_2_assets.contract_address, 'update_mint_fee', [mint_fee])
    await owner_signer.send_transaction(owner_account, index_with_2_assets.contract_address, 'update_fee_recipient', [fee_recipient_account.contract_address])
    return index_with_2_assets

@pytest.mark.asyncio
async def test_mint_with_mint_fee_and_fee_recipient(index_with_2_assets_with_mint_fee_and_fee_recipient, user_1, random_acc, fee_recipient):
    user_1_signer, user_1_account = user_1
    random_signer, random_account = random_acc
    fee_recipient_signer, fee_recipient_account = fee_recipient

    execution_info = await index_with_2_assets_with_mint_fee_and_fee_recipient.decimals().call()
    index_decimals = execution_info.result.decimals
    amount_to_mint = 5 * 10 ** index_decimals

    execution_info = await index_with_2_assets_with_mint_fee_and_fee_recipient.num_assets().call()
    num_assets =  execution_info.result.num

    assets = []
    amounts_to_transfer = []
    amounts_initial = []

    execution_info = await index_with_2_assets_with_mint_fee_and_fee_recipient.totalSupply().call()
    total_supply_initial = execution_info.result.totalSupply[0]

    for i in range(0, num_assets):
        execution_info = await index_with_2_assets_with_mint_fee_and_fee_recipient.get_amount_to_mint(i, uint(amount_to_mint)).call()
        amount_to_transfer_asset = execution_info.result.amount
        execution_info = await index_with_2_assets_with_mint_fee_and_fee_recipient.assets(i).call()
        asset_contract_address, amount_initial_asset =  execution_info.result.asset
        print(f"Minting {amount_to_transfer_asset} of asset {i} {asset_contract_address} to user_1")
        ## Mint asset to user_1 and approve to index
        await random_signer.send_transaction(random_account, asset_contract_address, 'mint', [user_1_account.contract_address, *amount_to_transfer_asset])
        await user_1_signer.send_transaction(user_1_account, asset_contract_address, 'approve', [index_with_2_assets_with_mint_fee_and_fee_recipient.contract_address, *amount_to_transfer_asset])

        amounts_to_transfer.append(amount_to_transfer_asset[0])
        amounts_initial.append(amount_initial_asset[0])

        # TODO
        # execution_info = await asset_contract_address.balanceOf(user_1_account.contract_address).call()
        # print(f"Check: Initial asset {i} balance for user_1 is {amount_to_transfer_asset}")
        # assert execution_info.result.balance == uint(amount_to_transfer_asset)
    
    await user_1_signer.send_transaction(user_1_account, index_with_2_assets_with_mint_fee_and_fee_recipient.contract_address, 'mint', [*uint(amount_to_mint)])

    expected_mint_fee = amount_to_mint * mint_fee / 10000

    execution_info = await index_with_2_assets_with_mint_fee_and_fee_recipient.totalSupply().call()
    total_supply_final =  execution_info.result.totalSupply[0]
    print(f"Check: Final total supply")
    assert total_supply_final == total_supply_initial + amount_to_mint
    
    execution_info = await index_with_2_assets_with_mint_fee_and_fee_recipient.balanceOf(user_1_account.contract_address).call()
    user_1_index_balance_final = execution_info.result.balance[0]
    print(f"Check: Final index balance for user_1")
    assert user_1_index_balance_final == amount_to_mint - expected_mint_fee

    execution_info = await index_with_2_assets_with_mint_fee_and_fee_recipient.balanceOf(fee_recipient_account.contract_address).call()
    fee_recipient_index_balance_final = execution_info.result.balance[0]
    print(f"Check: Final index balance for fee recipient")
    assert fee_recipient_index_balance_final == expected_mint_fee

    # TODO
    # for i in range(0, num_assets):
    #     execution_info = await index_with_2_assets_with_mint_fee_and_fee_recipient.assets(i).call()
    #     _, amount_final_asset =  execution_info.result.asset
    #     print(f"Check: final balance for asset {i} in index")
    #     assert amount_final_asset[0] == amounts_initial[i] + amounts_to_transfer[i]
