pragma circom 2.0.0;

include "/Users/blocklab/Desktop/Solidity/TradeCoinPoC/node_modules/circomlib/circuits/mimcsponge.circom";
template Main() {
  signal input x;
  signal input y;

  signal output out;

  component mimc = MiMCSponge(2, 220, 1);
  mimc.ins[0] <== x;
  mimc.ins[1] <== y;

  mimc.k <== 0;

  out <== mimc.outs[0];
}

component main {public [x]} = Main();

// node generate_witness.js multiplier2.wasm input.json witness.wtns
// snarkjs groth16 prove multiplier2_0001.zkey witness.wtns proof.json public.json
// snarkjs groth16 verify verification_key.json public.json proof.json
