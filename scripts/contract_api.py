import os

import dotenv
from pytezos import pytezos
from pytezos.client import PyTezosClient

dotenv.load_dotenv()

SHELL = "https://rpc.tzkt.io/hangzhou2net/"
KEY_FILENAME = os.environ["KEY_FILENAME"]
CONTRACT_ADDRESS = "KT18q4si6YmzJjbgZ3wV7HYfds1E3EbD7tBx"

client: PyTezosClient = pytezos.using(key=KEY_FILENAME, shell=SHELL)


class Invest:
    def __init__(self, client, contract_address):
        self.client = client
        self.contract = self.client.contract(contract_address)

    def create_portfolio(self, weights, tokens):
        self.client.wait(
            self.contract
            .create_portfolio(
                weights=weights,
                tokens=tokens,
            )
            .send()
        )

    def rebalance(self, prices, pools, slippage, amount):
        self.client.wait(
            self.contract
            .rebalance(
                prices=prices,
                pools=pools,
                slippage=slippage,
            )
            .with_amount(amount)
            .send()
        )

    def withdraw(self, pools):
        self.client.wait(
            self.contract
            .withdraw(pools)
            .send()
        )


if __name__ == "__main__":
    weights = {"RCT": 25, "FA12": 10, "TS": 65}
    tokens = {
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

    api = Invest(client, CONTRACT_ADDRESS)
    # api.create_portfolio(weights=weights, tokens=tokens)
    # api.rebalance(prices, pools, slippage=5, amount=100_000_000)
    # api.withdraw(pools=pools)
