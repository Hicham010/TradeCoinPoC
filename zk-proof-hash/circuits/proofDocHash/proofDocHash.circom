pragma circom 2.0.0;

include "/Users/blocklab/Desktop/Solidity/TradeCoinPoC/node_modules/circomlib/circuits/mimcsponge.circom";

template Main() {
  signal input commodity;
  signal input weight;
  signal input dollar;
  signal input randomness;

  signal input hash;

  signal output out;

  assert(dollar > 10);

  var commodityProps[4] = [commodity, weight, dollar, randomness];

  component mimc = MiMCSponge(4, 220, 1); 
  for (var i = 0; i < 4; i++){
    mimc.ins[i] <== commodityProps[i];
  }
  mimc.k <== 0;

  out <== mimc.outs[0];
  out === hash;
}

component main {public [commodity, weight, hash]} = Main();

// node generate_witness.js multiplier2.wasm input.json witness.wtns
// snarkjs groth16 prove multiplier2_0001.zkey witness.wtns proof.json public.json
// snarkjs groth16 verify verification_key.json public.json proof.json