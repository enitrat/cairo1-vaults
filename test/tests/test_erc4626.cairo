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

use simple_vault::erc4626::ERC4626;
use simple_vault::erc4626::IERC4626Dispatcher;
use simple_vault::erc4626::IERC4626DispatcherTrait;
use tests::mocks::mock_erc20::MockERC20;
use tests::mocks::mock_erc20::IMockERC20Dispatcher;
use tests::mocks::mock_erc20::IMockERC20DispatcherTrait;
use openzeppelin::token::erc20::IERC20Dispatcher;
use openzeppelin::token::erc20::IERC20DispatcherTrait;

// ERC4626 tests inspired by Solmate.

fn setup() -> (IMockERC20Dispatcher, IERC4626Dispatcher) {
    // Set up.

    // Deploy mock token.

    let user1 = contract_address_const::<0x123456789>();

    let mut calldata = ArrayTrait::new();
    let name = 'Mock Token';
    let symbol = 'TKN';
    calldata.append(name);
    calldata.append(symbol);

    let (token_address, _) = deploy_syscall(
        MockERC20::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();

    let mut calldata = ArrayTrait::<felt252>::new();
    calldata.append('Mock Token Vault');
    calldata.append('vwTKN');
    calldata.append(token_address.into());
    let (vault_address, _) = deploy_syscall(
        ERC4626::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();

    let token = IMockERC20Dispatcher { contract_address: token_address };
    let vault = IERC4626Dispatcher { contract_address: vault_address };

    (token, vault)
}

#[test]
#[available_gas(20000000)]
fn test_metadata() {
    let (underlying, vault) = setup();
    let mut calldata = ArrayTrait::new();
    calldata.append('Mock Token Vault');
    calldata.append('vwTKN');
    calldata.append(underlying.contract_address.into());
    let (vlt_address, _) = deploy_syscall(
        ERC4626::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();

    let vlt = IERC4626Dispatcher { contract_address: vlt_address };
    assert(vlt.name() == 'Mock Token Vault', 'wrong name');
    assert(vlt.symbol() == 'vwTKN', 'wrong symbol');
    assert(vlt.asset() == underlying.contract_address, 'wrong underlying');
}
//TODO it would be nice to have fuzz tests here
// in order to test different amounts - but likely not possible for a long time
#[test]
#[available_gas(20000000)]
fn test_single_deposit_withdraw() {
    let (underlying, vault) = setup();
    let amount: u256 = 1.into();

    let alice_underlying_amount = amount;
    let alice: ContractAddress = contract_address_const::<0xABCD>();

    underlying.mint(alice, alice_underlying_amount);

    //START PRANK ALICE
    testing::set_contract_address(alice);
    underlying.approve(vault.contract_address, alice_underlying_amount);
    assert(
        underlying.allowance(alice, vault.contract_address) == alice_underlying_amount,
        'wrong allowance'
    );
    let alice_pre_deposit_bal = underlying.balance_of(alice);

    let alice_share_amount: u256 = vault.deposit(alice_underlying_amount, alice);

    // Expect exchange rate to be 1:1 on initial deposit.
    assert(alice_underlying_amount == alice_share_amount, 'wrong share amount');
    assert(
        vault.preview_withdraw(alice_share_amount) == alice_underlying_amount,
        'wrong preview withdraw'
    );
    assert(
        vault.preview_deposit(alice_underlying_amount) == alice_share_amount,
        'wrong preview deposit'
    );
    assert(vault.total_supply() == alice_share_amount, 'wrong total supply');
    assert(vault.total_assets() == alice_underlying_amount, 'wrong total assets');
    assert(vault.balance_of(alice) == alice_share_amount, 'wrong balance of');
    assert(
        vault.convert_to_assets(vault.balance_of(alice)) == alice_underlying_amount,
        'wrong convert to assets'
    );
    assert(
        underlying.balance_of(alice) == alice_pre_deposit_bal - alice_underlying_amount,
        'wrong underlying balance'
    );
//TODO test runner can't start with next part
// vault.withdraw(alice_underlying_amount, alice, alice);

// assert(vault.total_assets() == 0.into(), 'wrong total assets');
// assert(vault.balance_of(alice) == 0.into(), 'wrong balance of');
// assert(vault.convert_to_assets(vault.balance_of(alice)) == 0.into(), 'wrong convert to assets');
// assert(underlying.balance_of(alice) == alice_pre_deposit_bal, 'wrong underlying balance');
}
#[test]
#[available_gas(200000000000)]
fn test_single_mint_redeem() {
    let (underlying, vault) = setup();
    let amount = 1.into();
    let alice_share_amount = amount;
    let alice: ContractAddress = contract_address_const::<0xABCD>();
    underlying.mint(alice, alice_share_amount);

    //START PRANK ALICE
    testing::set_contract_address(alice);
    underlying.approve(vault.contract_address, alice_share_amount);
    assert(
        underlying.allowance(alice, vault.contract_address) == alice_share_amount, 'wrong allowance'
    );

    let alice_pre_deposit_bal = underlying.balance_of(alice);

    let alice_underlying_amount = vault.mint(alice_share_amount, alice);

    //Expect exchange rate to be 1:1 on initial mint
    assert(alice_share_amount == alice_underlying_amount, 'wrong share amount');
    assert(
        vault.preview_withdraw(alice_share_amount) == alice_underlying_amount,
        'wrong preview withdraw'
    );
    assert(
        vault.preview_deposit(alice_underlying_amount) == alice_share_amount,
        'wrong preview deposit'
    );
    assert(vault.total_supply() == alice_share_amount, 'wrong total supply');
    assert(vault.total_assets() == alice_underlying_amount, 'wrong total assets');
    assert(vault.balance_of(alice) == alice_underlying_amount, 'wrong balance of');
    assert(
        vault.convert_to_assets(vault.balance_of(alice)) == alice_underlying_amount,
        'wrong convert to assets'
    );
    assert(
        underlying.balance_of(alice) == alice_pre_deposit_bal - alice_underlying_amount,
        'wrong underlying balance'
    );
//TODO test runner can't start with next part
// hint: This happens after I changed withdraw/redeem implementations
// to local ones in Vault.
// vault.redeem(alice_share_amount, alice, alice);

// assert(vault.total_assets() == 0.into(), 'wrong total assets');
// assert(vault.balance_of(alice) == 0.into(), 'wrong balance of');
// assert(vault.convert_to_assets(vault.balance_of(alice)) == 0.into(), 'wrong convert to assets');
// assert(underlying.balance_of(alice) == alice_pre_deposit_bal, 'wrong underlying balance');
}
// #[test]
// #[available_gas(20000000000000)]
// fn test_multiple_mint_deposit_redeem_withdraw() {
//     // Scenario:
//     // A = Alice, B = Bob
//     //  ________________________________________________________
//     // | Vault shares | A share | A assets | B share | B assets |
//     // |========================================================|
//     // | 1. Alice mints 2000 shares (costs 2000 tokens)         |
//     // |--------------|---------|----------|---------|----------|
//     // |         2000 |    2000 |     2000 |       0 |        0 |
//     // |--------------|---------|----------|---------|----------|
//     // | 2. Bob deposits 4000 tokens (mints 4000 shares)        |
//     // |--------------|---------|----------|---------|----------|
//     // |         6000 |    2000 |     2000 |    4000 |     4000 |
//     // |--------------|---------|----------|---------|----------|
//     // | 3. Vault mutates by +3000 tokens...                    |
//     // |    (simulated yield returned from strategy)...         |
//     // |--------------|---------|----------|---------|----------|
//     // |         6000 |    2000 |     3000 |    4000 |     6000 |
//     // |--------------|---------|----------|---------|----------|
//     // | 4. Alice deposits 2000 tokens (mints 1333 shares)      |
//     // |--------------|---------|----------|---------|----------|
//     // |         7333 |    3333 |     4999 |    4000 |     6000 |
//     // |--------------|---------|----------|---------|----------|
//     // | 5. Bob mints 2000 shares (costs 3001 assets)           |
//     // |    NOTE: Bob's assets spent got rounded up             |
//     // |    NOTE: Alice's vault assets got rounded up           |
//     // |--------------|---------|----------|---------|----------|
//     // |         9333 |    3333 |     5000 |    6000 |     9000 |
//     // |--------------|---------|----------|---------|----------|
//     // | 6. Vault mutates by +3000 tokens...                    |
//     // |    (simulated yield returned from strategy)            |
//     // |    NOTE: Vault holds 17001 tokens, but sum of          |
//     // |          assetsOf() is 17000.                          |
//     // |--------------|---------|----------|---------|----------|
//     // |         9333 |    3333 |     6071 |    6000 |    10929 |
//     // |--------------|---------|----------|---------|----------|
//     // | 7. Alice redeem 1333 shares (2428 assets)              |
//     // |--------------|---------|----------|---------|----------|
//     // |         8000 |    2000 |     3643 |    6000 |    10929 |
//     // |--------------|---------|----------|---------|----------|
//     // | 8. Bob withdraws 2928 assets (1608 shares)             |
//     // |--------------|---------|----------|---------|----------|
//     // |         6392 |    2000 |     3643 |    4392 |     8000 |
//     // |--------------|---------|----------|---------|----------|
//     // | 9. Alice withdraws 3643 assets (2000 shares)           |
//     // |    NOTE: Bob's assets have been rounded back up        |
//     // |--------------|---------|----------|---------|----------|
//     // |         4392 |       0 |        0 |    4392 |     8001 |
//     // |--------------|---------|----------|---------|----------|
//     // | 10. Bob redeem 4392 shares (8001 tokens)               |
//     // |--------------|---------|----------|---------|----------|
//     // |            0 |       0 |        0 |       0 |        0 |
//     // |______________|_________|__________|_________|__________|

//     let (underlying, vault) = setup();
//     let alice: ContractAddress = contract_address_const::<0xABCD>();
//     let bob: ContractAddress = contract_address_const::<0xDCBA>();

//     let mutation_underlying_amount: u256 = 3000.into();

//     underlying.mint(alice, 4000.into());

//     testing::set_contract_address(alice);
//     underlying.approve(vault.contract_address, 4000.into());

//     assert(underlying.allowance(alice, vault.contract_address) == 4000.into(), 'wrong allowance');

//     underlying.mint(bob, 7001.into());

//     testing::set_contract_address(bob);
//     underlying.approve(vault.contract_address, 7001.into());
//     assert(underlying.allowance(bob, vault.contract_address) == 7001.into(), 'wrong allowance');

//     // 1. Alice mints 2000 shares (costs 2000 tokens)
//     testing::set_contract_address(alice);
//     let alice_underlying_amount: u256 = vault.mint(2000.into(), alice);

//     let alice_share_amount: u256 = vault.preview_deposit(alice_underlying_amount);
//     // Expect to have received the requested mint amount
//     assert(alice_share_amount == 2000.into(), 'wrong share amount');
//     assert(vault.balance_of(alice) == alice_share_amount, 'wrong balance');
//     assert(
//         vault.convert_to_assets(vault.balance_of(alice)) == alice_underlying_amount,
//         'wrong assets amount'
//     );
//     assert(
//         vault.convert_to_shares(alice_underlying_amount) == vault.balance_of(alice),
//         'wrong shares amount'
//     );
//     // Expect a 1:1 ration before mutation
//     assert(alice_underlying_amount == 2000.into(), 'wrong ratio');
//     // Sanity check
//     assert(vault.total_supply() == alice_share_amount, 'wrong total supply');
//     assert(vault.total_assets() == alice_underlying_amount, 'wrong total assets');
//     // 2. Bob deposits 4000 tokens (mints 4000 shares)
//     testing::set_contract_address(bob);
//     let bob_share_amount = vault.deposit(4000.into(), bob);
//     let bob_underlying_amount = vault.preview_withdraw(bob_share_amount);
//     // Expect to have received the requested underlying amount
//     assert(bob_underlying_amount == 4000.into(), 'wrong underlying amount');
//     assert(vault.balance_of(bob) == bob_share_amount, 'wrong balance');
//     assert(
//         vault.convert_to_assets(vault.balance_of(bob)) == bob_underlying_amount,
//         'wrong assets amount'
//     );
//     assert(
//         vault.convert_to_shares(bob_underlying_amount) == vault.balance_of(bob),
//         'wrong shares amount'
//     );
//     // Expect a 1:1 ratio before mutation
//     assert(bob_share_amount == bob_underlying_amount, 'wrong ratio');
//     // Sanity check
//     let pre_mutation_share_bal = alice_share_amount + bob_share_amount;
//     let pre_mutation_bal = alice_underlying_amount + bob_underlying_amount;
//     assert(vault.total_supply() == pre_mutation_share_bal, 'wrong total supply');
//     //TODO UNCOMMENTING THIS SPECIFIC LINE MAKES THE TEST RUNNER FAIL
//     // assert(vault.total_assets() == pre_mutation_bal, 'wrong total assets');
//     assert(vault.total_supply() == 6000.into(), 'total supply should be 6000');
//     assert(vault.total_assets() == 6000.into(), 'total assets should be 6000');

//     // 3. Vault mutates by +3000 tokens...                    |
//     //    (simulated yield returned from strategy)...
//     // The Vault now contains more tokens than deposited which causes the exchange rate to change.
//     // Alice share is 33.33% of the Vault, Bob 66.66% of the Vault.
//     // Alice's share count stays the same but the underlying amount changes from 2000 to 3000.
//     // Bob's share count stays the same but the underlying amount changes from 4000 to 6000.

//     underlying.mint(vault.contract_address, mutation_underlying_amount);
//     assert(vault.total_supply() == pre_mutation_share_bal, 'wrong total supply');
//     assert(
//         vault.total_assets() == pre_mutation_bal + mutation_underlying_amount, 'wrong total assets'
//     );
//     assert(vault.balance_of(alice) == alice_share_amount, 'wrong alice share amount');
//     assert(
//         vault.convert_to_assets(vault.balance_of(alice)) == alice_underlying_amount
//             + (mutation_underlying_amount / 3.into() * 1.into()),
//         'wrong alice assets amount'
//     );
//     assert(vault.balance_of(bob) == bob_share_amount, 'wrong bob share amount');
//     //TODO UNCOMMENTING THIS SPECIFIC LINE MAKES THE TEST RUNNER FAIL - I cant continue testing this case.
//     assert(
//         vault.convert_to_assets(vault.balance_of(bob)) == bob_underlying_amount
//             + (mutation_underlying_amount / 3.into() * 2.into()),
//         'wrong bob assets amount'
//     );
// }

#[test]
#[available_gas(2000000000)]
#[should_panic]
fn test_fail_deposit_with_not_enough_approval() {
    let (underlying, vault) = setup();
    let alice: ContractAddress = contract_address_const::<0xABCD>();

    testing::set_contract_address(alice);
    underlying.mint(alice, 500.into());
    underlying.approve(vault.contract_address, 500.into());
    assert(underlying.allowance(alice, vault.contract_address) == 500.into(), 'wrong allowance');

    vault.deposit(1000.into(), alice);
}

#[test]
#[available_gas(2000000000)]
#[should_panic]
fn test_fail_withdraw_with_not_enough_underlying_amount() {
    let (underlying, vault) = setup();
    let alice: ContractAddress = contract_address_const::<0xABCD>();

    testing::set_contract_address(alice);
    underlying.mint(alice, 500.into());
    underlying.approve(vault.contract_address, 500.into());
    assert(underlying.allowance(alice, vault.contract_address) == 500.into(), 'wrong allowance');

    vault.deposit(500.into(), alice);

    vault.withdraw(1000.into(), alice, alice);
}
#[test]
#[available_gas(200000000)]
#[should_panic]
fn test_fail_redeem_with_not_enough_share_amount() {
    let (underlying, vault) = setup();
    let alice: ContractAddress = contract_address_const::<0xABCD>();

    testing::set_contract_address(alice);
    underlying.mint(alice, 500.into());
    underlying.approve(vault.contract_address, 500.into());

    vault.deposit(500.into(), alice);

    vault.redeem(1000.into(), alice, alice);
}

#[test]
#[available_gas(200000000)]
#[should_panic]
fn test_fail_withdraw_with_no_underlying_amount() {
    let (_, vault) = setup();
    let alice: ContractAddress = contract_address_const::<0xABCD>();

    testing::set_contract_address(alice);

    vault.withdraw(1000.into(), alice, alice);
}
#[test]
#[available_gas(200000000)]
#[should_panic]
fn test_fail_redeem_with_no_share_amount() {
    let (_, vault) = setup();
    let alice: ContractAddress = contract_address_const::<0xABCD>();

    testing::set_contract_address(alice);

    vault.redeem(1000.into(), alice, alice);
}
#[test]
#[available_gas(200000000)]
#[should_panic]
fn test_fail_deposit_with_no_approval() {
    let (_, vault) = setup();
    let alice: ContractAddress = contract_address_const::<0xABCD>();

    testing::set_contract_address(alice);

    vault.deposit(1000.into(), alice);
}
#[test]
#[available_gas(200000000)]
#[should_panic]
fn test_fail_mint_with_no_approval() {
    let (_, vault) = setup();
    let alice: ContractAddress = contract_address_const::<0xABCD>();

    testing::set_contract_address(alice);

    vault.mint(1000.into(), alice);
}
#[test]
#[available_gas(20000000000)]
#[should_panic]
fn test_fail_deposit_zero() {
    let (_, vault) = setup();
    let alice: ContractAddress = contract_address_const::<0xABCD>();

    testing::set_contract_address(alice);

    vault.deposit(0.into(), alice);
}
#[test]
#[available_gas(200000000)]
fn test_mint_zero() {
    let (_, vault) = setup();
    let alice: ContractAddress = contract_address_const::<0xABCD>();

    testing::set_contract_address(alice);

    vault.mint(0.into(), alice);

    assert(vault.balance_of(alice) == 0.into(), 'wrong balance');
    assert(vault.convert_to_assets(vault.balance_of(alice)) == 0.into(), 'wrong convert to assets');
    assert(vault.total_supply() == 0.into(), 'wrong total supply');
    assert(vault.total_assets() == 0.into(), 'wrong total assets');
}

#[test]
#[available_gas(200000000)]
#[should_panic]
fn test_fail_redeem_zero() {
    let (_, vault) = setup();
    let alice: ContractAddress = contract_address_const::<0xABCD>();

    testing::set_contract_address(alice);
    vault.redeem(0.into(), alice, alice);
}

#[test]
#[available_gas(200000000)]
fn test_withdraw_zero() {
    let (_, vault) = setup();
    let alice: ContractAddress = contract_address_const::<0xABCD>();

    testing::set_contract_address(alice);

    vault.withdraw(0.into(), alice, alice);

    assert(vault.balance_of(alice) == 0.into(), 'wrong balance');
    assert(vault.convert_to_assets(vault.balance_of(alice)) == 0.into(), 'wrong convert to assets');
    assert(vault.total_supply() == 0.into(), 'wrong total supply');
    assert(vault.total_assets() == 0.into(), 'wrong total assets');
}

#[test]
#[available_gas(20000000000)]
fn test_vault_interaction_for_someone_else() {
    let (mut underlying, vault) = setup();
    let alice: ContractAddress = contract_address_const::<0xABCD>();
    let bob: ContractAddress = contract_address_const::<0xDCBA>();

    underlying.mint(alice, 1000.into());
    underlying.mint(bob, 1000.into());

    testing::set_contract_address(alice);
    underlying.approve(vault.contract_address, 1000.into());

    testing::set_contract_address(bob);
    underlying.approve(vault.contract_address, 1000.into());

    // alice deposits 1000 tokens for bob
    testing::set_contract_address(alice);
    vault.deposit(1000.into(), bob);

    assert(vault.balance_of(alice) == 0.into(), 'wrong balance');
    assert(vault.balance_of(bob) == 1000.into(), 'wrong balance');
    assert(underlying.balance_of(alice) == 0.into(), 'wrong balance');

    // bob mints 1000 tokens for alice
    testing::set_contract_address(bob);
    vault.mint(1000.into(), alice);

    assert(vault.balance_of(alice) == 1000.into(), 'wrong balance');
    assert(vault.balance_of(bob) == 1000.into(), 'wrong balance');
    assert(underlying.balance_of(bob) == 0.into(), 'wrong balance');

    // alice redeem 1000 for bob
    testing::set_contract_address(alice);
    vault.redeem(1000.into(), bob, alice);

    assert(vault.balance_of(alice) == 0.into(), 'wrong balance');
    assert(vault.balance_of(bob) == 1000.into(), 'wrong balance');
    assert(underlying.balance_of(bob) == 1000.into(), 'wrong balance');

    // bob withdraw 1000 for alice
    testing::set_contract_address(bob);
    vault.withdraw(1000.into(), alice, bob);

    assert(vault.balance_of(alice) == 0.into(), 'wrong balance');
    assert(vault.balance_of(bob) == 0.into(), 'wrong balance');
    assert(underlying.balance_of(alice) == 1000.into(), 'wrong balance');
}

