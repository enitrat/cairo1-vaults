## What was implemented

- [x] Implementation of the ERC4626 standard in Cairo.
- [x] Implementation of an ERC4626-based Vault in Cairo. This Vault is a smart contract that allows users to deposit
      an underlying token and receive vault shares. The Vault will invest the funds into Strategies(for now, 1 Vault = 1 Strategy). These strategies share the same interface allowing to invest and withdraw funds. They can be anything from lending protocols to yield farming strategies.
      A user can withdraw from the vault at any time. If the vault doesn't enough funds,
      it will withdraw from the strategies to fulfill the withdrawal request.
- [x] Implementation of a Mock Strategy to test the vaults. This Mock strategy is a simple Strategy that has
      minting rights over a mock token to simulate profits/loss.

## What would've been nice

- [] Implementing a Vault factory contract so that we can deploy vaults for multiple strategies easily
- [] Supporting multiple strategies in a single vault
- [] Implementing a real yield-bearing lending strategy instead of a mock one
- [] Improve the Vault by adding more complex features such as a fee system, a timelock, a floating token target,
  emitting more events, etc.

## Problems encountered

- There is currently no efficient and scalable way of writing composable contracts in Cairo. A Vault follows the ERC4626
  standard, which itself follows the ERC20 standard. Each layer of composability requires re-defining _all_ the functions
  of the underlying contract. This is not only tedious, but also error-prone. It took me a while to figure out that since I re-defined the behavior of the `total_assets()` function in the `Vault` contract, I had to recursively change the implementation of all ERC4626 functions depending on `total_assets()`. This is very likely to introduce new errors, and demonstrates the current limitations of the contract syntax.
- While the cairo-test runner is very useful, it was at first not very useful as any test failing would only return the `ENTRYPOINT_FAILED` error. This was [fixed](https://github.com/starkware-libs/cairo/pull/3007) and now returns all error messages in the execution stack.
- The cairo-test runner sometimes fails with a `Error: Failed setting up runner.` message. The reason behind this
  is unclear, as it seems to be non-deterministic and happens randomly in some cases, but all the time for some tests.
  As a consequence, a lot of test cases that previously passed had to be commented after refactoring the code.
- The StarknetJS + devnet was not satisfying either, being too slow for it to be valuable for fast iterations.
