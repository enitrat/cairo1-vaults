use starknet::syscalls::deploy_syscall;
use starknet::class_hash::Felt252TryIntoClassHash;
use starknet::contract_address::contract_address_const;
use starknet::ContractAddress;
use starknet::testing;
use starknet::get_contract_address;
use traits::Into;
use traits::TryInto;
use option::OptionTrait;
use result::ResultTrait;
use array::ArrayTrait;
use debug::PrintTrait;

use simple_vault::vault::Vault;
use simple_vault::vault::IVaultDispatcher;
use simple_vault::vault::IVaultDispatcherTrait;
use tests::mocks::mock_erc20::MockERC20;
use tests::mocks::mock_erc20::IMockERC20Dispatcher;
use tests::mocks::mock_erc20::IMockERC20DispatcherTrait;
use tests::mocks::mock_strategy::{
    MockStrategy, IMockStrategyDispatcher, IMockStrategyDispatcherTrait
};
use openzeppelin::token::erc20::IERC20Dispatcher;
use openzeppelin::token::erc20::IERC20DispatcherTrait;

fn setup() -> (IMockERC20Dispatcher, IVaultDispatcher, IMockStrategyDispatcher) {
    // Set up.

    // Deploy mock token.

    let alice = contract_address_const::<0x123456789>();

    let mut calldata = ArrayTrait::new();
    let name = 'Mock Token';
    let symbol = 'TKN';
    calldata.append(name);
    calldata.append(symbol);

    // Alice is the deployer of the contracts and thus the owner of the Vault
    testing::set_contract_address(alice);
    let (token_address, _) = deploy_syscall(
        MockERC20::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();

    let mut calldata = ArrayTrait::<felt252>::new();
    calldata.append(token_address.into());
    let (strategy, _) = deploy_syscall(
        MockStrategy::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();

    let mut calldata = ArrayTrait::<felt252>::new();
    calldata.append('Mock Token Vault');
    calldata.append('vwTKN');
    calldata.append(token_address.into());
    calldata.append(strategy.into());

    //TODO(temporary) pass owner as parameter
    // given that it's impossible to test it by mocking deployer address.
    // Or, we could deploy as-is, mock 0 address and transfer ownership.
    calldata.append(alice.into());

    testing::set_contract_address(alice);
    let (vault_address, _) = deploy_syscall(
        Vault::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();

    let token = IMockERC20Dispatcher { contract_address: token_address };
    let vault = IVaultDispatcher { contract_address: vault_address };
    let strategy = IMockStrategyDispatcher { contract_address: strategy };

    (token, vault, strategy)
}
#[test]
#[available_gas(2000000000000)]
fn test_atomic_deposit_withdraw() {
    let (underlying, vault, _) = setup();
    let alice = contract_address_const::<0x123456789>();
    testing::set_contract_address(alice);

    underlying.mint(alice, 100.into());
    underlying.approve(vault.contract_address, 100.into());

    let pre_deposit_bal = underlying.balance_of(alice);
    vault.deposit(100.into(), alice);

    assert(vault.convert_to_assets(100.into()) == 100.into(), 'convert_to_assets failed');
    assert(vault.total_strategy_holdings() == 0.into(), 'total_strategy_holdings failed');
    assert(vault.total_assets() == 100.into(), 'total_assets failed');
    assert(vault.total_float() == 100.into(), 'total_float failed');
    assert(vault.balance_of(alice) == 100.into(), 'balance_of failed');
    assert(
        vault.convert_to_assets(vault.balance_of(alice)) == 100.into(), 'convert_to_assets failed'
    );
    assert(
        underlying.balance_of(alice) == pre_deposit_bal - 100.into(), 'underlying.balance_of failed'
    );

    vault.withdraw(100.into(), alice, alice);

    assert(vault.convert_to_assets(100.into()) == 100.into(), 'convert_to_assets failed');
    assert(vault.total_strategy_holdings() == 0.into(), 'total_strategy_holdings failed');
    assert(vault.total_assets() == 0.into(), 'total_assets failed');
    assert(vault.total_float() == 0.into(), 'total_float failed');
    assert(vault.balance_of(alice) == 0.into(), 'balance_of failed');
    assert(
        vault.convert_to_assets(vault.balance_of(alice)) == 0.into(), 'convert_to_assets failed'
    );
    assert(underlying.balance_of(alice) == pre_deposit_bal, 'underlying.balance_of failed');
}
#[test]
#[available_gas(2000000000000)]
fn test_deposit_redeem() {
    let (underlying, vault, _) = setup();
    let alice = contract_address_const::<0x123456789>();
    testing::set_contract_address(alice);

    underlying.mint(alice, 100.into());
    underlying.approve(vault.contract_address, 100.into());

    let pre_deposit_bal = underlying.balance_of(alice);
    vault.deposit(100.into(), alice);

    assert(vault.convert_to_assets(100.into()) == 100.into(), 'convert_to_assets failed');
    assert(vault.total_strategy_holdings() == 0.into(), 'total_strategy_holdings failed');
    assert(vault.total_assets() == 100.into(), 'total_assets failed');
    assert(vault.total_float() == 100.into(), 'total_float failed');
    assert(vault.balance_of(alice) == 100.into(), 'balance_of failed');
    assert(
        vault.convert_to_assets(vault.balance_of(alice)) == 100.into(), 'convert_to_assets failed'
    );
    assert(
        underlying.balance_of(alice) == pre_deposit_bal - 100.into(), 'underlying.balance_of failed'
    );

    vault.redeem(100.into(), alice, alice);

    assert(vault.convert_to_assets(100.into()) == 100.into(), 'convert_to_assets failed');
    assert(vault.total_strategy_holdings() == 0.into(), 'total_strategy_holdings failed');
    assert(vault.total_assets() == 0.into(), 'total_assets failed');
    assert(vault.total_float() == 0.into(), 'total_float failed');
    assert(vault.balance_of(alice) == 0.into(), 'balance_of failed');
    assert(
        vault.convert_to_assets(vault.balance_of(alice)) == 0.into(), 'convert_to_assets failed'
    );
    assert(underlying.balance_of(alice) == pre_deposit_bal, 'underlying.balance_of failed');
}
//////////////////////////////////////////
// DEPOSIT/WITHDRAWAL SANITY CHECKS TESTS. //
//////////////////////////////////////////

#[test]
#[available_gas(200000000)]
#[should_panic]
fn test_fail_deposit_with_not_enough_approval() {
    let (underlying, vault, _) = setup();
    let alice = contract_address_const::<0x123456789>();
    testing::set_contract_address(alice);
    let amount: u256 = 100.into();
    underlying.mint(alice, amount / 2.into());
    underlying.approve(vault.contract_address, amount / 2.into());

    vault.deposit(amount, alice);
}
#[test]
#[available_gas(20000000)]
#[should_panic]
fn test_fail_withdraw_not_enough_balance() {
    let (underlying, vault, _) = setup();
    let alice = contract_address_const::<0x123456789>();
    testing::set_contract_address(alice);
    let amount: u256 = 100.into();
    let half_amount = amount / 2.into();
    underlying.mint(alice, half_amount);
    underlying.approve(vault.contract_address, half_amount);

    vault.deposit(half_amount, alice);
    vault.withdraw(amount, alice, alice);
}
#[test]
#[available_gas(20000000)]
#[should_panic]
fn test_fail_redeem_with_not_enough_balance() {
    let (underlying, vault, _) = setup();
    let alice = contract_address_const::<0x123456789>();
    testing::set_contract_address(alice);
    let amount: u256 = 100.into();
    let half_amount = amount / 2.into();
    underlying.mint(alice, half_amount);
    underlying.approve(vault.contract_address, half_amount);

    vault.deposit(half_amount, alice);
    vault.redeem(amount, alice, alice);
}
// //TODO continue sanity tests

//////////////////////////////////////////
//          ACCESS TESTS                //
//////////////////////////////////////////

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('caller not owner', 'ENTRYPOINT_FAILED'))]
fn test_deposit_strategy_non_owner() {
    let (underlying, vault, strategy) = setup();
    let bob = contract_address_const::<0x987654321>();
    testing::set_contract_address(bob);
    vault.deposit_into_strategy(1.into());
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('caller not owner', 'ENTRYPOINT_FAILED'))]
fn test_withdraw_strategy_non_owner() {
    let (underlying, vault, strategy) = setup();
    let bob = contract_address_const::<0x987654321>();
    testing::set_contract_address(bob);
    vault.withdraw_from_strategy(1.into());
}
// //////////////////////////////////////////
// // STRATEGY DEPOSIT / WITHDRAWALS test //
// //////////////////////////////////////////

//TODO test runner can't start these tests post-ownable implementation
#[test]
#[available_gas(20000000)]
fn test_atomic_enter_exit_strategy() {
    let (underlying, vault, strategy) = setup();
    let alice = contract_address_const::<0x123456789>();
    testing::set_contract_address(alice);
    let amount: u256 = 100.into();
    let half_amount = amount / 2.into();

    underlying.mint(alice, amount);
    underlying.approve(vault.contract_address, amount);
    vault.deposit(amount, alice);
    vault.deposit_into_strategy(amount);

    assert(vault.convert_to_assets(100.into()) == 100.into(), 'convert_to_assets failed');
    assert(vault.total_strategy_holdings() == 100.into(), 'total_strategy_holdings failed');
    assert(vault.total_assets() == amount, 'total_assets failed');
    assert(vault.total_float() == 0.into(), 'total_float failed');
    assert(vault.balance_of(alice) == amount, 'balance_of failed');
    assert(vault.convert_to_assets(vault.balance_of(alice)) == amount, 'convert_to_assets failed');

    vault.withdraw_from_strategy(half_amount);

    assert(vault.convert_to_assets(100.into()) == 100.into(), '2 - convert_to_assets failed');
    assert(vault.total_strategy_holdings() == 50.into(), '2 total_strategy_holding failed');
    assert(vault.total_assets() == amount, '2 - total_assets failed');
    assert(vault.total_float() == amount / 2.into(), '2 - total_float failed');
    assert(vault.balance_of(alice) == amount, '2 - balance_of failed');
    assert(
        vault.convert_to_assets(vault.balance_of(alice)) == amount, '2 - convert_to_assets failed'
    );
}
#[test]
#[available_gas(20000000)]
fn test_atomic_enter_exit_strategy_with_profit() {
    let (underlying, vault, strategy) = setup();
    let alice = contract_address_const::<0x123456789>();
    testing::set_contract_address(alice);
    let amount: u256 = 100.into();
    let half_amount = amount / 2.into();

    underlying.mint(alice, amount);
    underlying.approve(vault.contract_address, amount);
    vault.deposit(amount, alice);
    vault.deposit_into_strategy(amount);

    assert(vault.convert_to_assets(100.into()) == 100.into(), 'convert_to_assets failed');
    assert(vault.total_strategy_holdings() == 100.into(), 'total_strategy_holdings failed');
    assert(vault.total_assets() == amount, 'total_assets failed');
    assert(vault.total_float() == 0.into(), 'total_float failed');
    assert(vault.balance_of(alice) == amount, 'balance_of failed');
    assert(vault.convert_to_assets(vault.balance_of(alice)) == amount, 'convert_to_assets failed');

    // Simulate a 20% yield - we deposited 100 tokens and now the strategy hold 120
    strategy.simulate_underlying_amount_change(20.into(), true);
    assert(
        strategy.balance_of_underlying(vault.contract_address) == 120.into(),
        'balance_of_underlying not 120'
    );

    vault.withdraw_from_strategy(half_amount);

    assert(vault.convert_to_assets(100.into()) == 120.into(), '2 - convert_to_assets failed');
    assert(vault.total_strategy_holdings() == 70.into(), '2 total_strategy_holding failed');
    assert(vault.total_assets() == 120.into(), '2 - total_assets failed');
    assert(vault.total_float() == 50.into(), '2 - total_float failed');
    assert(
        vault.balance_of(alice) == amount, '2 - balance_of failed'
    ); // alice still has 100 shares
    assert(
        vault
            .convert_to_assets(vault.balance_of(alice)) == 120
            .into(), // and these 100 shares are worth 120 tokens
        '2 - convert_to_assets failed'
    );
}
#[test]
#[available_gas(20000000)]
fn test_atomic_enter_exit_strategy_with_loss() {
    let (underlying, vault, strategy) = setup();
    let alice = contract_address_const::<0x123456789>();
    testing::set_contract_address(alice);
    let amount: u256 = 100.into();
    let half_amount = amount / 2.into();

    underlying.mint(alice, amount);
    underlying.approve(vault.contract_address, amount);
    vault.deposit(amount, alice);
    vault.deposit_into_strategy(amount);

    assert(vault.convert_to_assets(100.into()) == 100.into(), 'convert_to_assets failed');
    assert(vault.total_strategy_holdings() == 100.into(), 'total_strategy_holdings failed');
    assert(vault.total_assets() == amount, 'total_assets failed');
    assert(vault.total_float() == 0.into(), 'total_float failed');
    assert(vault.balance_of(alice) == amount, 'balance_of failed');
    assert(vault.convert_to_assets(vault.balance_of(alice)) == amount, 'convert_to_assets failed');

    // Simulate a 20% loss - we deposited 100 tokens and now the strategy holds 80
    strategy.simulate_underlying_amount_change(20.into(), false);
    assert(
        strategy.balance_of_underlying(vault.contract_address) == 80.into(),
        'balance_of_underlying not 120'
    );

    vault.withdraw_from_strategy(half_amount);

    assert(vault.convert_to_assets(100.into()) == 80.into(), '2 - convert_to_assets failed');
    assert(vault.total_strategy_holdings() == 30.into(), '2 total_strategy_holding failed');
    assert(vault.total_assets() == 80.into(), '2 - total_assets failed');
    assert(vault.total_float() == 50.into(), '2 - total_float failed');
    assert(
        vault.balance_of(alice) == amount, '2 - balance_of failed'
    ); // alice still has 100 shares
    assert(
        vault
            .convert_to_assets(vault.balance_of(alice)) == 80
            .into(), // and these 100 shares are worth 80 tokens
        '2 - convert_to_assets failed'
    );
}

