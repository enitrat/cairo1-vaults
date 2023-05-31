use starknet::ContractAddress;
use openzeppelin::token::erc20::IERC20;

// Mock Strategy contract with a function to simulate a change in the amount of underlying held by the strategy
// This effectively simulates a yield-bearing strategy / yield loosing strategy

#[abi]
trait IMockStrategy {
    fn invest(amount: u256);
    fn withdraw(amount: u256) -> u256;
    fn balance_of_underlying(vault: ContractAddress) -> u256;
    fn simulate_underlying_amount_change(value_change: u256, positive: bool);
}

#[contract]
mod MockStrategy {
    use tests::mocks::mock_erc20::{IMockERC20, IMockERC20Dispatcher, IMockERC20DispatcherTrait};
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_contract_address};
    use option::OptionTrait;
    use traits::Into;
    use simple_vault::utils::maths::{div_wad_down, mul_div_down};
    use debug::PrintTrait;

    struct Storage {
        _underlying_token: IMockERC20Dispatcher,
        _invested_balance: LegacyMap<ContractAddress, u256>,
        _total_supply: u256,
    }

    #[constructor]
    fn constructor(underlying_token: ContractAddress) {
        _underlying_token::write(IMockERC20Dispatcher { contract_address: underlying_token });
        let WAD: u256 = 1000000000000000000.into();
    }

    #[external]
    fn invest(amount: u256) {
        let caller = get_caller_address();
        _invested_balance::write(caller, _invested_balance::read(caller) + amount);
        _total_supply::write(_total_supply::read() + amount);
        _underlying_token::read().transfer_from(caller, get_contract_address(), amount);
    }

    #[external]
    fn withdraw(amount: u256) {
        let caller = get_caller_address();
        assert(balance_of_underlying(caller) >= amount, 'NOT_ENOUGH_BALANCE');
        _total_supply::write(_total_supply::read() - amount);
        _invested_balance::write(caller, _invested_balance::read(caller) - amount);
        _underlying_token::read().transfer(caller, amount);
    }

    #[view]
    fn balance_of_underlying(account: ContractAddress) -> u256 {
        let WAD: u256 = 1000000000000000000.into();
        mul_div_down(_invested_balance::read(account), _exchange_rate(), WAD)
    }


    #[external]
    fn simulate_underlying_amount_change(value_change: u256, positive: bool) {
        let current_holdings = _underlying_token::read().balance_of(get_contract_address());
        if positive {
            _underlying_token::read().mint(get_contract_address(), value_change);
        } else {
            assert(
                _underlying_token::read().balance_of(get_contract_address()) >= value_change,
                'Cant simulate decrease'
            );
            _underlying_token::read().burn(get_contract_address(), value_change);
        }
    }


    fn _exchange_rate() -> u256 {
        // NOTE: ERC20 are assumed to always have 18 decimals here, as they're defined like this in OZ's standard.
        //TODO(low priority: mock) modify this by calling `.decimals` on the ERC20.
        let WAD: u256 = 1000000000000000000.into();
        if _total_supply::read() == 0.into() {
            return WAD;
        } else {
            return mul_div_down(
                _underlying_token::read().balance_of(get_contract_address()),
                WAD,
                _total_supply::read()
            );
        }
    }
}


#[cfg(test)]
mod test { //TODO(low priority, it's only a mock)
}
