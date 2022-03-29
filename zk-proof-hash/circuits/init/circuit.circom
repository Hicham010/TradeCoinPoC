pragma circom 2.0.0;

// include "../../node_modules/circomlib/circuits/mimcsponge.circom";
include "/Users/blocklab/Desktop/Solidity/TradeCoinPoC/node_modules/circomlib/circuits/mimcsponge.circom";
template Main() {
  signal input x;
  signal input hash;

  signal output out;

  component mimc = MiMCSponge(1, 220, 1);
  mimc.ins[0] <== x;
  mimc.k <== 0;

  out <== mimc.outs[0];

  out === hash;
}

component main {public [hash]} = Main();

// pragma circom 2.0.0;

// include "../../node_modules/circomlib/circuits/mimcsponge.circom";

// template Main() {
//   signal input commodity;
//   signal input weight;
//   signal input money;

//   signal input hash;

//   signal output out;

//   var commodityProps = [commodity, weight, money]

//   component mimc = MiMCSponge(3, 220, 1); 
//   for (var i = 0; i < 3; i++){
//     mimc.ins[i] <== commodityProps[i];
//     mimc.k <== 0;
//   }
//   out <== mimc.outs[0];
//   out === hash;
// }

// component main {public [commodity, weight, hash]} = Main();