use starknet::ContractAddress;

//TODO unfortunately, we can't create a supertrait here requiring ERC4626Impl, because
// it causes an `internal cycle detected` error.
#[abi]
trait IVault {
    /// IERC20 functions
    fn name() -> felt252;
    fn symbol() -> felt252;
    fn decimals() -> u8;
    fn total_supply() -> u256;
    fn balance_of(account: ContractAddress) -> u256;
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn approve(spender: ContractAddress, amount: u256) -> bool;
    /// ERC4626-specific functions
    fn asset() -> ContractAddress;
    fn total_assets() -> u256;
    fn convert_to_shares(assets: u256) -> u256;
    fn convert_to_assets(shares: u256) -> u256;
    fn max_deposit(amount: u256) -> u256;
    fn preview_deposit(assets: u256) -> u256;
    fn deposit(assets: u256, receiver: ContractAddress) -> u256;
    fn max_mint(receiver: ContractAddress) -> u256;
    fn preview_mint(shares: u256) -> u256;
    fn mint(shares: u256, receiver: ContractAddress, ) -> u256;
    fn max_withdraw(owner: ContractAddress) -> u256;
    fn preview_withdraw(assets: u256) -> u256;
    fn withdraw(assets: u256, receiver: ContractAddress, owner: ContractAddress) -> u256;
    fn max_redeem(owner: ContractAddress) -> u256;
    fn preview_redeem(shares: u256) -> u256;
    fn redeem(shares: u256, receiver: ContractAddress, owner: ContractAddress) -> u256;
    // Vault-specific functions
    fn total_float() -> u256;
    fn deposit_into_strategy(underlying_amount: u256);
    fn withdraw_from_strategy(underlying_amount: u256);
    fn total_strategy_holdings() -> u256;
    // Ownership functions
    fn owner() -> ContractAddress;
    fn transfer_ownership(new_owner: ContractAddress);
    fn renounce_ownership();
}
#[contract]
mod Vault {
    use super::IVault;
    use simple_vault::erc4626::ERC4626;
    use simple_vault::strategy::{IStrategyDispatcher, IStrategyDispatcherTrait};
    use simple_vault::ownable::{Ownable, Ownable::OwnableImpl};
    use openzeppelin::token::erc20::{ERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use traits::Into;
    use integer::BoundedInt;
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_contract_address};
    use option::OptionTrait;
    use simple_vault::utils::maths::MathRounding;
    use debug::PrintTrait;

    struct Storage {
        _strategy: IStrategyDispatcher
    }

    impl Vault of IVault {
        fn name() -> felt252 {
            ERC20::name()
        }


        fn symbol() -> felt252 {
            ERC20::symbol()
        }


        fn decimals() -> u8 {
            ERC20::decimals()
        }


        fn total_supply() -> u256 {
            ERC20::total_supply()
        }


        fn balance_of(account: ContractAddress) -> u256 {
            ERC20::balance_of(account)
        }


        fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256 {
            ERC20::allowance(owner, spender)
        }


        fn transfer(recipient: ContractAddress, amount: u256) -> bool {
            ERC20::transfer(recipient, amount)
        }


        fn transfer_from(
            sender: ContractAddress, recipient: ContractAddress, amount: u256
        ) -> bool {
            ERC20::transfer_from(sender, recipient, amount)
        }


        fn approve(spender: ContractAddress, amount: u256) -> bool {
            ERC20::approve(spender, amount)
        }


        // fn increase_allowance(spender: ContractAddress, added_value: u256) -> bool {
        //     ERC20::_increase_allowance(spender, added_value)
        // }

        // fn decrease_allowance(spender: ContractAddress, subtracted_value: u256) -> bool {
        //     ERC20::_decrease_allowance(spender, subtracted_value)
        // }
        ////////////////////////////////////////////////////////////////
        // ERC4626 functions
        ////////////////////////////////////////////////////////////////

        fn asset() -> ContractAddress {
            ERC4626::asset()
        }

        //TODO Find a better way to override ERC4626's base implementation.
        // We want to return assets invested in strategies + free assets
        // Might not be possible until the Contract Syntax Update
        fn total_assets() -> u256 {
            let float = Vault::total_float();
            let invested = _strategy::read().balance_of_underlying(get_contract_address());
            float + invested
        }

        fn convert_to_shares(assets: u256) -> u256 {
            if Vault::total_supply() == 0.into() {
                assets
            } else {
                // Note: if supply is 0, total_assets should be 0 as well.
                (assets * Vault::total_supply()) / Vault::total_assets()
            }
        }

        //TODO the problem here is that everything that previously relied on ERC4626::total_assets()
        // must now be redefined explicitly, as we now want it to use the Vault implementation instead.
        // No other way until the Contract Syntax Update
        fn convert_to_assets(shares: u256) -> u256 {
            let supply = Vault::total_supply();
            if supply == 0.into() {
                shares
            } else {
                (shares * Vault::total_assets()) / supply
            }
        }

        fn max_deposit(amount: u256) -> u256 {
            ERC4626::max_deposit(amount)
        }

        fn preview_deposit(assets: u256) -> u256 {
            ERC4626::preview_deposit(assets)
        }

        fn deposit(assets: u256, receiver: ContractAddress) -> u256 {
            ERC4626::deposit(assets, receiver)
        }

        fn max_mint(receiver: ContractAddress) -> u256 {
            ERC4626::max_mint(receiver)
        }

        fn preview_mint(shares: u256) -> u256 {
            if Vault::total_supply() == 0.into() {
                shares
            } else {
                (shares * Vault::total_assets()).div_up(Vault::total_supply())
            }
        }

        fn mint(shares: u256, receiver: ContractAddress) -> u256 {
            ERC4626::mint(shares, receiver)
        }

        fn max_withdraw(owner: ContractAddress) -> u256 {
            ERC4626::max_withdraw(owner)
        }

        fn preview_withdraw(assets: u256) -> u256 {
            if Vault::total_supply() == 0.into() {
                assets
            } else {
                (assets * Vault::total_supply()).div_up(Vault::total_assets())
            }
        }

        fn withdraw(assets: u256, receiver: ContractAddress, owner: ContractAddress) -> u256 {
            //Note: Since we need to retrieve missing underlying assets, we have to re-write
            // the withdraw function here by adding the _retrieve_underlying call.
            let shares = ERC4626::preview_withdraw(assets);

            if get_caller_address() != owner {
                let allowed = ERC4626::allowance(owner, get_caller_address());
                if allowed != BoundedInt::<u256>::max() {
                    let new_allowed = allowed - shares;
                    // Note: here, we need to modify a storage variable of the ERC20 contract.
                    // We can directly access it under the ERC20 Module
                    ERC20::_allowances::write((owner, get_caller_address()), new_allowed);
                }
            }

            _retrieve_underlying(assets);
            ERC20::_burn(owner, shares);
            let token = ERC4626::_asset::read();
            token.transfer(receiver, assets);
            ERC4626::Withdraw(get_caller_address(), receiver, owner, assets, shares);
            shares
        }

        fn max_redeem(owner: ContractAddress) -> u256 {
            ERC4626::max_redeem(owner)
        }

        fn preview_redeem(shares: u256) -> u256 {
            ERC4626::preview_redeem(shares)
        }

        fn redeem(shares: u256, receiver: ContractAddress, owner: ContractAddress) -> u256 {
            //Note: same as withdraw()
            if get_caller_address() != owner {
                let allowed = ERC4626::allowance(owner, get_caller_address());
                if allowed != BoundedInt::<u256>::max() {
                    let new_allowed = allowed - shares;
                    ERC20::_allowances::write((owner, get_caller_address()), new_allowed);
                }
            }

            let assets = ERC4626::preview_redeem(shares);
            assert(assets != 0.into(), 'ZERO_ASSETS');

            _retrieve_underlying(assets);
            ERC20::_burn(owner, shares);
            let token = ERC4626::_asset::read();
            token.transfer(receiver, assets);
            ERC4626::Withdraw(get_caller_address(), receiver, owner, assets, shares);
            shares
        }

        ////////////////////////////////////////////////////////////////
        // Vault-specific functions
        ////////////////////////////////////////////////////////////////

        // idle tokens in vault
        fn total_float() -> u256 {
            let token = Vault::asset();
            IERC20Dispatcher { contract_address: token }.balance_of(get_contract_address())
        }

        fn deposit_into_strategy(underlying_amount: u256) {
            Ownable::assert_only_owner();
            let underlying = IERC20Dispatcher { contract_address: Vault::asset() };
            underlying.approve(_strategy::read().contract_address, underlying_amount);
            _strategy::read().invest(underlying_amount);
        }

        fn withdraw_from_strategy(underlying_amount: u256) {
            Ownable::assert_only_owner();
            _strategy::read().withdraw(underlying_amount);
        }

        fn total_strategy_holdings() -> u256 {
            _strategy::read().balance_of_underlying(get_contract_address())
        }

        ////////////////////////////////
        // Ownable entrypoints
        ////////////////////////////////

        fn owner() -> ContractAddress {
            OwnableImpl::owner()
        }

        fn renounce_ownership() {
            OwnableImpl::renounce_ownership()
        }

        fn transfer_ownership(new_owner: ContractAddress) {
            OwnableImpl::transfer_ownership(new_owner)
        }
    }


    ////////////////////////////////////////////////////////////////
    // ENTRYPOINTS
    ////////////////////////////////////////////////////////////////

    #[constructor]
    fn constructor(
        name: felt252,
        symbol: felt252,
        asset: ContractAddress,
        strategy: ContractAddress,
        owner: ContractAddress
    ) {
        ERC4626::initializer(name, symbol, asset);
        _strategy::write(IStrategyDispatcher { contract_address: strategy });
        Ownable::initializer(owner);
    }

    ////////////////////////////////
    // ERC20 entrypoints
    ////////////////////////////////

    #[view]
    fn name() -> felt252 {
        Vault::name()
    }

    #[view]
    fn symbol() -> felt252 {
        Vault::symbol()
    }

    #[view]
    fn decimals() -> u8 {
        Vault::decimals()
    }

    #[view]
    fn total_supply() -> u256 {
        Vault::total_supply()
    }

    #[view]
    fn balance_of(account: ContractAddress) -> u256 {
        Vault::balance_of(account)
    }

    #[view]
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256 {
        Vault::allowance(owner, spender)
    }

    #[external]
    fn transfer(recipient: ContractAddress, amount: u256) -> bool {
        Vault::transfer(recipient, amount)
    }

    #[external]
    fn transfer_from(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
        Vault::transfer_from(sender, recipient, amount)
    }

    #[external]
    fn approve(spender: ContractAddress, amount: u256) -> bool {
        Vault::approve(spender, amount)
    }

    // #[external]
    // fn increase_allowance(spender: ContractAddress, added_value: u256) -> bool {
    //     ERC20::_increase_allowance(spender, added_value)
    // }

    // #[external]
    // fn decrease_allowance(spender: ContractAddress, subtracted_value: u256) -> bool {
    //     ERC20::_decrease_allowance(spender, subtracted_value)
    // }

    ////////////////////////////////////////////////////////////////
    // ERC4626 functions
    ////////////////////////////////////////////////////////////////

    #[view]
    fn asset() -> ContractAddress {
        Vault::asset()
    }

    #[view]
    fn total_assets() -> u256 {
        Vault::total_assets()
    }

    #[view]
    fn convert_to_shares(assets: u256) -> u256 {
        Vault::convert_to_shares(assets)
    }

    #[view]
    fn convert_to_assets(shares: u256) -> u256 {
        Vault::convert_to_assets(shares)
    }

    #[view]
    fn max_deposit(amount: u256) -> u256 {
        Vault::max_deposit(amount)
    }

    #[view]
    fn preview_deposit(assets: u256) -> u256 {
        Vault::preview_deposit(assets)
    }

    #[external]
    fn deposit(assets: u256, receiver: ContractAddress) -> u256 {
        Vault::deposit(assets, receiver)
    }

    #[view]
    fn max_mint(receiver: ContractAddress) -> u256 {
        Vault::max_mint(receiver)
    }

    #[view]
    fn preview_mint(shares: u256) -> u256 {
        Vault::preview_mint(shares)
    }

    #[external]
    fn mint(shares: u256, receiver: ContractAddress) -> u256 {
        Vault::mint(shares, receiver)
    }

    #[view]
    fn max_withdraw(owner: ContractAddress) -> u256 {
        Vault::max_withdraw(owner)
    }

    #[view]
    fn preview_withdraw(assets: u256) -> u256 {
        Vault::preview_withdraw(assets)
    }

    #[external]
    fn withdraw(assets: u256, receiver: ContractAddress, owner: ContractAddress) -> u256 {
        Vault::withdraw(assets, receiver, owner)
    }

    #[view]
    fn max_redeem(owner: ContractAddress) -> u256 {
        Vault::max_redeem(owner)
    }

    #[view]
    fn preview_redeem(shares: u256) -> u256 {
        Vault::preview_redeem(shares)
    }

    #[external]
    fn redeem(shares: u256, receiver: ContractAddress, owner: ContractAddress) -> u256 {
        Vault::redeem(shares, receiver, owner)
    }

    ////////////////////////////////
    // Ownable entrypoints
    ////////////////////////////////

    #[view]
    fn owner() -> ContractAddress {
        Vault::owner()
    }


    #[external]
    fn renounce_ownership() {
        Vault::renounce_ownership()
    }

    #[external]
    fn transfer_ownership(new_owner: ContractAddress) {
        Vault::transfer_ownership(new_owner)
    }

    ////////////////////////////////
    // Vault-specific entrypoints
    ////////////////////////////////

    #[view]
    fn total_float() -> u256 {
        Vault::total_float()
    }

    #[external]
    fn deposit_into_strategy(underlying_amount: u256) {
        Vault::deposit_into_strategy(underlying_amount)
    }

    #[external]
    fn withdraw_from_strategy(underlying_amount: u256) {
        Vault::withdraw_from_strategy(underlying_amount)
    }

    #[view]
    fn total_strategy_holdings() -> u256 {
        Vault::total_strategy_holdings()
    }

    ////////////////////////////////////////////////////////////////
    // Internal functions
    ////////////////////////////////////////////////////////////////

    // simple function that retrieves underlying assets from the vault's strategies.
    // For now, the vault only supports one strategy that is stored in a storage var
    fn _retrieve_underlying(underlying_amount: u256) {
        let float = Vault::total_float();

        if float < underlying_amount {
            let float_missing_for_withdrawal = underlying_amount - float;
            let strategy = _strategy::read();
            strategy.withdraw(float_missing_for_withdrawal);
        }
    }
}
