
from brownie import Lottery, accounts, config, network

def test_get_entreance_fee():
    account = accounts[0]
    lottery = lottery.deploy(
        config["networks"][network.shoe_active()]["eth_usd_price_feed"], 
        {"from": account}
    )
    assert lottery.getEntranceFee() > web3.toWei(0.018, "ether")
    assert lottery.getEntranceFee() < web3.toWei(0.022, "ether")