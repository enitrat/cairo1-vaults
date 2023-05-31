use starknet::ContractAddress;

// Mock ERC20 contract with unprotected mint function

#[abi]
trait IMockERC20 {
    fn name() -> felt252;
    fn symbol() -> felt252;
    fn decimals() -> u8;
    fn total_supply() -> u256;
    fn balance_of(account: ContractAddress) -> u256;
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn approve(spender: ContractAddress, amount: u256) -> bool;
    fn mint(to: ContractAddress, value: u256);
    fn burn(from: ContractAddress, value: u256);
}

#[contract]
mod MockERC20 {
    use openzeppelin::token::erc20::ERC20;
    use starknet::ContractAddress;

    #[constructor]
    fn constructor(name: felt252, symbol: felt252) {
        ERC20::initializer(name, symbol);
    }

    #[view]
    fn name() -> felt252 {
        ERC20::name()
    }

    #[view]
    fn symbol() -> felt252 {
        ERC20::symbol()
    }

    #[view]
    fn decimals() -> u8 {
        ERC20::decimals()
    }

    #[view]
    fn total_supply() -> u256 {
        ERC20::total_supply()
    }

    #[view]
    fn balance_of(account: ContractAddress) -> u256 {
        ERC20::balance_of(account)
    }

    #[view]
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256 {
        ERC20::allowance(owner, spender)
    }

    #[external]
    fn transfer(recipient: ContractAddress, amount: u256) -> bool {
        ERC20::transfer(recipient, amount)
    }

    #[external]
    fn transfer_from(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
        ERC20::transfer_from(sender, recipient, amount)
    }

    #[external]
    fn approve(spender: ContractAddress, amount: u256) -> bool {
        ERC20::approve(spender, amount)
    }

    #[external]
    fn increase_allowance(spender: ContractAddress, added_value: u256) -> bool {
        ERC20::_increase_allowance(spender, added_value)
    }

    #[external]
    fn decrease_allowance(spender: ContractAddress, subtracted_value: u256) -> bool {
        ERC20::_decrease_allowance(spender, subtracted_value)
    }

    // ADDED FUNCTIONS

    #[external]
    fn mint(to: ContractAddress, value: u256) {
        ERC20::_mint(to, value)
    }

    #[external]
    fn burn(from: ContractAddress, value: u256) {
        ERC20::_burn(from, value)
    }
}
