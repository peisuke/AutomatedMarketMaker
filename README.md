# Automated Market Maker 

*注意: 勉強用に作ったサンプルなので、このまま利用するのはお止めください。また、本プログラム及びその派生物を利用した事により生じたいかなる損害に関しても一切責任を負いません。*

## テスト

```
$ npx hardhat test
```

## コンソールでの実行

ローカルでノードを立ち上げて実験します。まずはノードの立ち上げ。Accountのアドレスをコピーしておく。

```
$ npx hardhat node
Started HTTP and WebSocket JSON-RPC server at http://0.0.0.0:8545/

Accounts
========

WARNING: These accounts, and their private keys, are publicly known.
Any funds sent to them on Mainnet or any other live network WILL BE LOST.

Account #0: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 (10000 ETH)
Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

Account #1: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 (10000 ETH)
Private Key: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
.
.
.
```

先程立ち上げてたノードに、別のターミナルからAMMをデプロイする。アドレスは後ほど利用する。

```
$ npx hardhat run --network localhost scripts/deploy.js
FirstToken deployed to: 0x5FbDB2315678afecb367f032d93F642f64180aa3
SecondToken deployed to: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
AMM deployed to: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
```

今回は、コンソールに入って、流動性プールにトークンのペアを入れ、トークンの交換を行う。まずはコンソールの立ち上げ。

```
$ npx hardhat console --network localhost
Welcome to Node.js v16.15.0.
Type ".help" for more information.
> 
```

まずはアドレスを変数に入れておく。

```
> let alice = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
> let FirstTokenAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3"
> let SecondTokenAddress = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"
> let AMMAddress = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"
```

各コントラクトに接続する。

```
> const FirstToken = await ethers.getContractFactory("FirstToken")
> const SecondToken = await ethers.getContractFactory("SecondToken")
> const AMM = await ethers.getContractFactory("AMM")
> const firstToken = await FirstToken.attach(FirstTokenAddress)
> const secondToken = await SecondToken.attach(SecondTokenAddress)
> const amm = await AMM.attach(AMMAddress)
```

2つのトークンをミントして、aliceに送る。

```
> await firstToken.mint(alice, "100000000000000")
> await secondToken.mint(alice, "100000000000000")
```

現在のaliceの保有トークンは以下。

```
> await firstToken.balanceOf(alice)
BigNumber { value: "100000000000000" }

> await secondToken.balanceOf(alice)
BigNumber { value: "100000000000000" }
```

aliceはAMMがトークンを引き出すことを許可する。

```
> let singer = await ethers.getSigner(alice)
> let firstTokenInstance = await firstToken.connect(singer)
> let secondTokenInstance = await secondToken.connect(singer)
> await firstTokenInstance.approve(AMMAddress, "10000")
> await secondTokenInstance.approve(AMMAddress, "40000")
```

流動性プールにトークンのペアを投入する。

```
> await amm.provide("10000", "40000", alice)
```

全てのLPトークンと、aliceが得たLPトークン。uniswapと同様、ゼロ割を割けるために最初の1000トークンはロックする。

```
> await amm.getTotalSupply()
BigNumber { value: "20000" }

> await amm.getShareOf(alice)
BigNumber { value: "19000" }
```

LPトークン取得後の、aliceの保有トークン。

```
> await firstToken.balanceOf(alice)
BigNumber { value: "99999999990000" }

> await secondToken.balanceOf(alice)
BigNumber { value: "99999999960000" }
```

aliceは1000トークンを交換。

```
> await firstTokenInstance.approve(AMMAddress, "1000")
> await amm.swap(FirstTokenAddress, SecondTokenAddress, "1000", alice)
```

トークン交換後の保有量。

```
> await firstToken.balanceOf(alice)
BigNumber { value: "99999999989000" }

> await secondToken.balanceOf(alice)
BigNumber { value: "99999999963636" }
```

LPトークンを焼却して、トークンを引き出し。

```
> await amm.withdraw("19000", alice)
```

ロックしたLPトークンは残り、aliceの保有するLPトークンは0になる。

```
> await amm.getTotalSupply()
BigNumber { value: "1000" }

> await amm.getShareOf(alice)
BigNumber { value: "0" }
```

最終的な保有トークン。

```
> await firstToken.balanceOf(alice)
BigNumber { value: "99999999999450" }

> await secondToken.balanceOf(alice)
BigNumber { value: "99999999998181" }
```
