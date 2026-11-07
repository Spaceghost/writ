# Nix JavaScript check for cb54600

At exact source `cb546006dafa8c5ea20e4ee98300295a5e89d875`,
`nix build --no-link --print-out-paths .#checks.x86_64-linux.tests-js`
exited zero. The output
`/nix/store/s2af5md2xbny1kmx07xx1wcasx0jr229-writ-tests-js` contains 2,261
PASS lines and has SHA-256
`012c789f9761c050961adcdde8ef4f689e3d1d3096cb272c359d5d5ff30cdf9b`, matching
the Node capture in this directory. Its derivation is
`/nix/store/14ayv32whz1c5pm07qzf3g3zfmw7iby2-writ-tests-js.drv`.
This verifies the Nix JavaScript check only; it is not a full flake check,
Nix-native run, GPU result, authenticated planner integration, or protected-host
qualification.
