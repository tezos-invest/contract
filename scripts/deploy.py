import os
import json

import dotenv
from pytezos import ContractInterface, pytezos
from pytezos.client import PyTezosClient


dotenv.load_dotenv()

SHELL = "https://rpc.tzkt.io/hangzhou2net/"
KEY_FILENAME = os.environ["KEY_FILENAME"]
CONTRACT_FILENAME = "invest.tz"


metadata = json.dumps(
    {
        "version": "0.1.0",
        "name": "Tezos Invest",
        "authors": ["HackTheHack"],
        "source": {
            "tools": ["Ligo 0.40.0"],
            "location": "https://github.com/tezos-invest",
        },
        "interfaces": [],
        "errors": [],
        "views": [],
    }
)


if __name__ == "__main__":
    client: PyTezosClient = pytezos.using(key=KEY_FILENAME, shell=SHELL)
    contract = ContractInterface.from_file(CONTRACT_FILENAME).using(
        key=KEY_FILENAME, shell=SHELL
    )

    initial_storage = {
        "admin": client.key.public_key_hash(),
        "pending_admin": None,
        "portfolios": {},
        "balances": {},
        "is_paused": False,
        "withdrawal_address": None,
        "pending_requests": {},
        "pools": {},
    }

    contract.program.storage.from_python_object(initial_storage)
    op = contract.originate(initial_storage=initial_storage).send()
    print(f"Success: {op.hash()}")
    client.wait(op)

    # Searching for contract address:
    opg = client.shell.blocks[-10:].find_operation(op.hash())
    op_result = opg["contents"][0]["metadata"]["operation_result"]
    address = op_result["originated_contracts"][0]
    print(f"Contract address: {address}")
    # Contract address: KT18q4si6YmzJjbgZ3wV7HYfds1E3EbD7tBx
