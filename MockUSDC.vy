# MockUSDC.vy
interface ERC20:
    def transfer(_to: address, _value: uint256) -> bool: nonpayable
    def approve(_spender: address, _value: uint256) -> bool: nonpayable
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable
    def allowance(_owner: address, _spender: address) -> uint256: view
    def balanceOf(_account: address) -> uint256: view
    def totalSupply() -> uint256: view

implements: ERC20

# Define ZERO_CONSTANT constant
ZERO_CONSTANT: constant(address) = 0x0000000000000000000000000000000000000000

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

@deploy
def __init__():
    self.name = "Mock USDC"
    self.symbol = "mUSDC"
    self.decimals = 6  # USDC typically has 6 decimals
    self.totalSupply = 0

@external
def transfer(_to: address, _value: uint256) -> bool:
    assert self.balanceOf[msg.sender] >= _value, "Insufficient balance"
    self.balanceOf[msg.sender] -= _value
    self.balanceOf[_to] += _value
    log Transfer(msg.sender, _to, _value)
    return True

@external
def approve(_spender: address, _value: uint256) -> bool:
    self.allowance[msg.sender][_spender] = _value
    log Approval(msg.sender, _spender, _value)
    return True

@external
def transferFrom(_from: address, _to: address, _value: uint256) -> bool:
    assert self.balanceOf[_from] >= _value, "Insufficient balance"
    assert self.allowance[_from][msg.sender] >= _value, "Insufficient allowance"
    self.balanceOf[_from] -= _value
    self.balanceOf[_to] += _value
    self.allowance[_from][msg.sender] -= _value
    log Transfer(_from, _to, _value)
    return True

@external
def mint(_to: address, _value: uint256):
    # For simulation purposes, no access control; in production, restrict this
    self.totalSupply += _value
    self.balanceOf[_to] += _value
    log Transfer(ZERO_CONSTANT, _to, _value)

@external
def burn(_from: address, _value: uint256):
    # For simulation purposes
    assert self.balanceOf[_from] >= _value, "Insufficient balance"
    self.totalSupply -= _value
    self.balanceOf[_from] -= _value
    log Transfer(_from, ZERO_CONSTANT, _value)