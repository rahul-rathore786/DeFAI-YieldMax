# DeFAI_YieldMax.vy
from vyper.interfaces import ERC20

interface MockUSDC:
    def transfer(_to: address, _value: uint256) -> bool: nonpayable
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable
    def balanceOf(_account: address) -> uint256: view

interface DummyPool:
    def stake(amount: uint256): nonpayable
    def unstake(amount: uint256): nonpayable
    def claimReward(): nonpayable
    def staked(user: address) -> uint256: view
    def accumulatedReward(user: address) -> uint256: view

# ERC20 Implementation
name: public(String[32])
symbol: public(String[32])
decimals: public(uint256)
totalSupply: public(uint256)
balanceOf: public(HashMap[address, uint256])
allowance: public(HashMap[address, HashMap[address, uint256]])

event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    value: uint256

event Approval:
    owner: indexed(address)
    spender: indexed(address)
    value: uint256

usdc: public(address)
pools: public(address[15])  # 3 platforms * 5 pools
allocationPercent: public(HashMap[address, uint256])  # Percentage * 10000
owner: public(address)
feeRecipient: public(address)
performanceFee: public(uint256)  # Fee as percentage * 10000 (e.g., 10% = 1000)
lastHarvestAssets: public(uint256)

@external
def __init__(_usdc: address, _pools: address[15], _feeRecipient: address):
    self.name = "DeFAI YieldMax"
    self.symbol = "DFYM"
    self.decimals = 6
    self.usdc = _usdc
    self.owner = msg.sender
    self.feeRecipient = _feeRecipient
    self.performanceFee = 1000  # 10%
    self.pools = _pools
    # Initialize equal allocation (100% / 15 = ~666 per pool)
    for i in range(15):
        self.allocationPercent[_pools[i]] = 666
    self.allocationPercent[_pools[14]] = 672  # Adjust last one to sum to 10000

@internal
def _totalAssets() -> uint256:
    total: uint256 = MockUSDC(self.usdc).balanceOf(self)
    for i in range(15):
        pool: address = self.pools[i]
        total += DummyPool(pool).staked(self)
        total += DummyPool(pool).accumulatedReward(self)
    return total

@external
def deposit(amount: uint256):
    assert amount > 0, "Amount must be greater than 0"
    total_assets: uint256 = self._totalAssets()
    shares: uint256 = 0
    if self.totalSupply == 0:
        shares = amount
    else:
        shares = (amount * self.totalSupply) / total_assets
    assert MockUSDC(self.usdc).transferFrom(msg.sender, self, amount), "Transfer failed"
    self.totalSupply += shares
    self.balanceOf[msg.sender] += shares
    log Transfer(ZERO_ADDRESS, msg.sender, shares)

@external
def withdraw(shares: uint256):
    assert self.balanceOf[msg.sender] >= shares, "Insufficient shares"
    total_assets: uint256 = self._totalAssets()
    amount: uint256 = (shares * total_assets) / self.totalSupply
    self.totalSupply -= shares
    self.balanceOf[msg.sender] -= shares
    log Transfer(msg.sender, ZERO_ADDRESS, shares)

    available: uint256 = MockUSDC(self.usdc).balanceOf(self)
    if available < amount:
        self.harvest()  # Claim rewards
        available = MockUSDC(self.usdc).balanceOf(self)
        if available < amount:
            shortage: uint256 = amount - available
            total_staked: uint256 = 0
            for i in range(15):
                total_staked += DummyPool(self.pools[i]).staked(self)
            for i in range(15):
                pool_stake: uint256 = DummyPool(self.pools[i]).staked(self)
                unstake_amount: uint256 = (shortage * pool_stake) / total_staked
                if unstake_amount > 0:
                    DummyPool(self.pools[i]).unstake(unstake_amount)
    assert MockUSDC(self.usdc).transfer(msg.sender, amount), "Transfer failed"

@external
def rebalance(newAllocations: uint256[15]):
    assert msg.sender == self.owner, "Only owner"
    total_percent: uint256 = 0
    for i in range(15):
        total_percent += newAllocations[i]
    assert total_percent == 10000, "Allocations must sum to 100%"
    for i in range(15):
        self.allocationPercent[self.pools[i]] = newAllocations[i]
    self._rebalanceFunds()

@internal
def _rebalanceFunds():
    for i in range(15):
        DummyPool(self.pools[i]).claimReward()
    total_capital: uint256 = MockUSDC(self.usdc).balanceOf(self)
    for i in range(15):
        total_capital += DummyPool(self.pools[i]).staked(self)
    for i in range(15):
        pool: address = self.pools[i]
        desired: uint256 = (total_capital * self.allocationPercent[pool]) / 10000
        current: uint256 = DummyPool(pool).staked(self)
        if current > desired:
            DummyPool(pool).unstake(current - desired)
        elif current < desired:
            amount: uint256 = desired - current
            if MockUSDC(self.usdc).balanceOf(self) >= amount:
                assert MockUSDC(self.usdc).transfer(pool, amount), "Transfer failed"
                DummyPool(pool).stake(amount)

@external
def harvest():
    total_assets_before: uint256 = self._totalAssets()
    for i in range(15):
        DummyPool(self.pools[i]).claimReward()
    total_assets_after: uint256 = self._totalAssets()
    if total_assets_after > self.lastHarvestAssets:
        profit: uint256 = total_assets_after - self.lastHarvestAssets
        fee: uint256 = (profit * self.performanceFee) / 10000
        if fee > 0:
            assert MockUSDC(self.usdc).transfer(self.feeRecipient, fee), "Fee transfer failed"
    self.lastHarvestAssets = total_assets_after

@external
def earn():
    available: uint256 = MockUSDC(self.usdc).balanceOf(self)
    if available > 0:
        total_assets: uint256 = self._totalAssets()
        for i in range(15):
            pool: address = self.pools[i]
            desired: uint256 = (total_assets * self.allocationPercent[pool]) / 10000
            current: uint256 = DummyPool(pool).staked(self)
            if current < desired:
                stake_amount: uint256 = min(desired - current, available)
                if stake_amount > 0:
                    assert MockUSDC(self.usdc).transfer(pool, stake_amount), "Transfer failed"
                    DummyPool(pool).stake(stake_amount)
                    available -= stake_amount

# ERC20 Functions (transfer, approve, etc.) similar to MockUSDC...