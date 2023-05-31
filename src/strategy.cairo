use starknet::ContractAddress;
#[abi]
trait IStrategy {
    fn invest(underlying_amount: u256);
    fn withdraw(underlying_amount: u256);
    fn balance_of_underlying(account: ContractAddress) -> u256;
}
