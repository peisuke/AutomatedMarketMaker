# Automated Market Maker 

## テスト

```
$ npx hardhat test
```

## コンソールでの実行

```
$ npx hardhat run --network localhost scripts/deploy.js
FirstToken deployed to: 0x5FbDB2315678afecb367f032d93F642f64180aa3
SecondToken deployed to: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
AMM deployed to: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
```

```
$ npx hardhat console --network localhost
Welcome to Node.js v16.15.0.
Type ".help" for more information.
> 
```

```
> let alice = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
> let FirstTokenAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3"
> let SecondTokenAddress = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"
> let AMMAddress = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"
```

```
> const FirstToken = await ethers.getContractFactory("FirstToken")
> const SecondToken = await ethers.getContractFactory("SecondToken")
> const AMM = await ethers.getContractFactory("AMM")
```

```
> const firstToken = await FirstToken.attach(FirstTokenAddress)
> const secondToken = await SecondToken.attach(SecondTokenAddress)
> const amm = await AMM.attach(AMMAddress)
```

```
> await firstToken.mint(alice, "100000000000000")
> await secondToken.mint(alice, "100000000000000")
```

```
> let singer = await ethers.getSigner(alice)
> let firstTokenInstance = await firstToken.connect(singer)
> let secondTokenInstance = await secondToken.connect(singer)
```

```
> await firstTokenInstance.approve(AMMAddress, "10000")
> await secondTokenInstance.approve(AMMAddress, "40000")
```

```
> await firstToken.balanceOf(alice)
BigNumber { value: "100000000000000" }

> await secondToken.balanceOf(alice)
BigNumber { value: "100000000000000" }
```

```
> await amm.provide("10000", "40000", alice)
```

```
> await amm.getTotalSupply()
BigNumber { value: "20000" }

> await amm.getShareOf(alice)
BigNumber { value: "19000" }
```

```
> await firstToken.balanceOf(alice)
BigNumber { value: "99999999990000" }

> await secondToken.balanceOf(alice)
BigNumber { value: "99999999960000" }
```

```
> await firstTokenInstance.approve(AMMAddress, "1000")
> await amm.swap(FirstTokenAddress, SecondTokenAddress, "1000", alice)
```

```
> await firstToken.balanceOf(alice)
BigNumber { value: "99999999989000" }

> await secondToken.balanceOf(alice)
BigNumber { value: "99999999963636" }
```

```
> await amm.withdraw("19000", alice)
```

```
> await amm.getTotalSupply()
BigNumber { value: "1000" }

> await amm.getShareOf(alice)
BigNumber { value: "0" }
```

```
> await firstToken.balanceOf(alice)
BigNumber { value: "99999999999450" }

> await secondToken.balanceOf(alice)
BigNumber { value: "99999999998181" }
```