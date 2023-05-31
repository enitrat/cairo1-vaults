use starknet::ContractAddress;


#[abi]
trait IOwnable {
    fn owner() -> ContractAddress;
    fn transfer_ownership(new_owner: ContractAddress);
    fn renounce_ownership();
}

//TODO perhaps a better name would be `OwnableLibrary` given that
// the "contract" has no entrypoints and is not meant to be deployed alone.
// It is only meant to be used as a library in other contracts.
// We still need to annotate it with `#[contract]` for the Starknet plugin.
#[contract]
mod Ownable {
    use super::IOwnable;
    use starknet::ContractAddress;
    use starknet::contract_address::{ContractAddressZeroable, contract_address_const};
    use starknet::get_caller_address;
    use traits::Into;
    use debug::PrintTrait;

    struct Storage {
        _owner: ContractAddress
    }

    #[event]
    fn OwnershipTransferred(preview_owner: ContractAddress, new_owner: ContractAddress) {}

    impl OwnableImpl of IOwnable {
        fn owner() -> ContractAddress {
            _owner::read()
        }

        fn transfer_ownership(new_owner: ContractAddress) {
            assert(new_owner != contract_address_const::<0>(), 'new owner is zero address');
            assert_only_owner();
            _transfer_ownership(new_owner);
        }

        fn renounce_ownership() {
            assert_only_owner();
            _transfer_ownership(contract_address_const::<0>());
        }
    }

    fn _transfer_ownership(new_owner: ContractAddress) {
        let previous_owner = OwnableImpl::owner();
        _owner::write(new_owner);
        OwnershipTransferred(previous_owner, new_owner);
    }

    fn assert_only_owner() {
        let caller = get_caller_address();
        assert(caller != contract_address_const::<0>(), 'caller is zero address');
        assert(caller == OwnableImpl::owner(), 'caller not owner')
    }

    fn initializer(owner: ContractAddress) {
        _transfer_ownership(owner);
    }
}
