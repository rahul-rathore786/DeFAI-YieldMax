# DummyPool.vy

# Define the MockUSDC interface inline
interface MockUSDC:
    def transfer(_to: address, _value: uint256) -> bool: nonpayable
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable
    def mint(_to: address, _value: uint256): nonpayable

usdc: public(address)
apy: public(uint256)  # APY as percentage * 10000 (e.g., 10% = 1000)
staked: public(HashMap[address, uint256])
startTime: public(HashMap[address, uint256])
accumulatedReward: public(HashMap[address, uint256])

SECONDS_PER_YEAR: constant(uint256) = 31_536_000  # 365 * 86400

@deploy
def __init__(_usdc: address, _apy: uint256):
    self.usdc = _usdc
    self.apy = _apy

@internal
def _updateReward(user: address):
    earned: uint256 = (self.staked[user] * self.apy * (block.timestamp - self.startTime[user])) / (SECONDS_PER_YEAR * 10000)
    self.accumulatedReward[user] += earned
    self.startTime[user] = block.timestamp

@external
def stake(amount: uint256):
    self._updateReward(msg.sender)
    assert MockUSDC(self.usdc).transferFrom(msg.sender, self, amount), "Transfer failed"
    self.staked[msg.sender] += amount
    if self.startTime[msg.sender] == 0:
        self.startTime[msg.sender] = block.timestamp

@external
def unstake(amount: uint256):
    assert self.staked[msg.sender] >= amount, "Insufficient staked amount"
    self._updateReward(msg.sender)
    self.staked[msg.sender] -= amount
    assert MockUSDC(self.usdc).transfer(msg.sender, amount), "Transfer failed"

@external
def claimReward():
    self._updateReward(msg.sender)
    reward: uint256 = self.accumulatedReward[msg.sender]
    if reward > 0:
        self.accumulatedReward[msg.sender] = 0
        MockUSDC(self.usdc).mint(msg.sender, reward)