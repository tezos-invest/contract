import os

import dotenv
from pytezos import pytezos
from pytezos.client import PyTezosClient

dotenv.load_dotenv()

SHELL = "https://rpc.tzkt.io/hangzhou2net/"
KEY_FILENAME = os.environ["KEY_FILENAME"]
CONTRACT_ADDRESS = "KT1BbMoCrZFPgdhkzgpS1PkzFehnwAQwEx3m"

client: PyTezosClient = pytezos.using(key=KEY_FILENAME, shell=SHELL)


def get_balance(token, owner):
    if "fa2" in token:
        token_address, token_id = token["fa2"]
        contract = client.contract(token_address)
        responses = contract.balance_of(requests=[{'token_id': token_id, 'owner': owner}], callback=None).callback_view()
        balance = responses[0]["balance"]
    else:
        token_address = token["fa12"]
        contract = client.contract(token_address)
        balance = contract.getBalance(owner, None).callback_view()
    return balance


def update_operators(token, owner, operator):
    if "fa2" in token:
        token_address, token_id = token["fa2"]
        contract = client.contract(token_address)
        return contract.update_operators([{
            "add_operator": {
                "owner": owner,
                "operator": operator,
                "token_id": token_id,
            }
        }])

def update_operators2(address, owner, operator):
    contract = client.contract(address)
    return contract.update_operators([{
        "add_operator": {
            "owner": owner,
            "operator": operator,
            "token_id": token_id,
        }
    }])

if __name__ == "__main__":
    weights = {"RCT": 25, "FA12": 10, "TS": 65}
    token_addresses = {
        "TS": {"fa2": ("KT1CaWSNEnU6RR9ZMSSgD5tQtQDqdpw4sG83", 0)},
        "RCT": {"fa2": ("KT1QGgr6k1CDf4Svd18MtKNQukboz8JzRPd5", 0)},
        "FA12": {"fa12": "KT1Dr8Qf9at75uEvwN4QnGTNFfPMAr8KL4kK"},
    }
    pools = {
        "TS": "KT1DaP41e8fk4BsRB2pPk1HXuX3R47dp7mnU",
        "RCT": "KT1PASJkScZRKzhyivCqw4ejHBHC8pUAfJWs",
        "FA12": "KT1A787UhgpQnSntyA6U9VaUnxwzMZs7xsSt",
    }
    prices = {
        "TS": 98650,
        "RCT": 235606,
        "FA12": 1794313,
    }

    exit()
    for symbol, token in token_addresses.items():
        balance = get_balance(token, owner=client.key.public_key_hash())
        print(f"Current balance of {symbol}: {balance}")
        # Current balance of TS: 0
        # Current balance of RCT: 400431122
        # Current balance of FA12: 9990766

    api = client.contract(CONTRACT_ADDRESS)

    client.wait(
        api
        .create_portfolio(weights)
        .send()
    )

    client.wait(
        api
        .rebalance(
            prices=prices,
            pools=pools,
            slippage=5,
        )
        .with_amount(100_000_000)
        .send()
    )

    # client.wait(
    #     client
    #     .bulk(
    #         *filter(None, (
    #             update_operators(token, owner=client.key.public_key_hash(), operator=client.key.public_key_hash())
    #             for token in token_addresses.values()
    #         ))
    #     )
    #     .send()
    # )

    # client.wait(
    #     client
    #     .bulk(
    #         *filter(None, (
    #             update_operators(token, owner=client.key.public_key_hash(), operator=pools[symbol])
    #             for symbol, token in token_addresses.items()
    #         ))
    #     )
    #     .send()
    # )

    client.wait(
        api
        .withdraw(
            tokens=token_addresses,
            pools=pools,
        )
        .send()
    )
