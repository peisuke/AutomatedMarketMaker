const hre = require("hardhat");
const { expect } = require("chai");

let firstToken;
let secondToken;
let amm;
let alice;

function BigNumber(x) {
    return hre.ethers.BigNumber.from(x);
}

function expandTo18Decimals(n) {
    return BigNumber(n).mul(BigNumber(10).pow(18))
}

beforeEach(async function () {
    const FirstToken = await hre.ethers.getContractFactory("FakeJPYC");
    const SecondToken = await hre.ethers.getContractFactory("MyToken");

    firstToken = await FirstToken.deploy();
    secondToken = await SecondToken.deploy();

    await firstToken.deployed();
    await secondToken.deployed();

    const AMM = await hre.ethers.getContractFactory("AMM");
    amm = await AMM.deploy(firstToken.address, secondToken.address);

    await amm.deployed();

    console.log("FirstToken deployed to:", firstToken.address);
    console.log("SecondToken deployed to:", secondToken.address);
    console.log("AMM deployed to:", amm.address);

    [owner, addr1, addr2, ...addrs] = await hre.ethers.getSigners();
    alice = addr1.address;

    await firstToken.mint(alice, BigNumber(100000))
    await secondToken.mint(alice, BigNumber(100000))

    instance1 = firstToken.connect(addr1)
    instance2 = secondToken.connect(addr1);
    await instance1.approve(amm.address, BigNumber(100000));
    await instance2.approve(amm.address, BigNumber(100000));
});

describe("AMM", function () {
    it("computeLiquidityProvide", async () => {
        //  sqrt(10000 * 40000) - 1000
        [amount1, amount2] = await amm.computeLiquidityAmount(BigNumber(10000), BigNumber(40000));
        expect(await amm.computeLiquidityProvide(amount1, amount2)).to.eq(BigNumber(19000))

        //  mint liquidity is 19000
        //  total supply is 19000 + MINIMUM_LIQUIDITY
        //  balance: 10000, 40000
        amm.provide(BigNumber(10000), BigNumber(40000), alice);
        expect(await amm.getTotalSupply()).to.eq(BigNumber(20000));

        //  20000 * 200 / 10000
        [amount1, amount2] = await amm.computeLiquidityAmount(BigNumber(200), BigNumber(800));
        expect(await amm.computeLiquidityProvide(amount1, amount2)).to.eq(BigNumber(400))
    });

    it("computeLiquidityWithdraw", async () => {
        await expect(amm.computeLiquidityWithdraw(1000)).to.be.revertedWith(
            'TotalSupply cannot be zero.'
        )

        //  mint liquidity is 19000
        //  total supply is 19000 + MINIMUM_LIQUIDITY
        //  balance: 10000, 40000
        await amm.provide(BigNumber(10000), BigNumber(40000), alice)
        expect(await amm.getTotalSupply()).to.eq(BigNumber(20000));

        //  19000 * 10000 / 20000, 19000 * 40000 / 20000
        expect(await amm.computeLiquidityWithdraw(19000)).to.deep.eq(
            [BigNumber(9500), BigNumber(38000)]
        )
    });

    it("getLiquidityAmountOut", async () => {
        await expect(amm.getLiquidityAmountOut(
            0, firstToken.address, secondToken.address
        )).to.be.revertedWith('Insufficient amount.')

        await expect(amm.getLiquidityAmountOut(
            1000, firstToken.address, secondToken.address
        )).to.be.revertedWith('Insufficient liquidity.')

        //  新たな流動性を提供性を提供したい時の価格
        amm.provide(BigNumber(10000), BigNumber(30000), alice);

        expect(await amm.getLiquidityAmountOut(
            1000, firstToken.address, secondToken.address
        )).to.eq(BigNumber(3000))

    });

    it("getLiquidityAmountIn", async () => {
        await expect(amm.getLiquidityAmountIn(
            0, firstToken.address, secondToken.address
        )).to.be.revertedWith('Insufficient amount.')

        await expect(amm.getLiquidityAmountIn(
            1000, firstToken.address, secondToken.address
        )).to.be.revertedWith('Insufficient liquidity.')

        //  新たな流動性を提供性を提供したい時の価格
        amm.provide(BigNumber(10000), BigNumber(30000), alice);

        expect(await amm.getLiquidityAmountIn(
            3000, firstToken.address, secondToken.address
        )).to.eq(BigNumber(1000))
    });

    it("getAmountOut", async () => {
        await expect(amm.getAmountOut(
            0, firstToken.address, secondToken.address
        )).to.be.revertedWith('Amount must not be zero.')

        await expect(amm.getAmountOut(
            1000, firstToken.address, secondToken.address
        )).to.be.revertedWith('Insufficient liquidity.')

        amm.provide(BigNumber(10000), BigNumber(33000), alice);

        expect(await amm.getAmountOut(
            1000, firstToken.address, secondToken.address
        )).to.eq(BigNumber(3000))
    });

    it("getAmountIn", async () => {
        await expect(amm.getAmountIn(
            0, firstToken.address, secondToken.address
        )).to.be.revertedWith('Amount must not be zero.')

        await expect(amm.getAmountIn(
            3000, firstToken.address, secondToken.address
        )).to.be.revertedWith('Insufficient liquidity.')

        amm.provide(BigNumber(10000), BigNumber(33000), alice);

        expect(await amm.getAmountIn(
            3000, firstToken.address, secondToken.address
        )).to.eq(BigNumber(1000))
    });

    it("provide and withdraw", async () => {
        amm.provide(BigNumber(10000), BigNumber(40000), alice);

        expect(await amm.getShareOf(alice)).to.eq(BigNumber(19000));
        expect(await amm.getTotalSupply()).to.eq(BigNumber(20000));
        expect(await firstToken.balanceOf(alice)).to.eq(BigNumber(90000));
        expect(await secondToken.balanceOf(alice)).to.eq(BigNumber(60000));
        expect(await firstToken.balanceOf(amm.address)).to.eq(BigNumber(10000));
        expect(await secondToken.balanceOf(amm.address)).to.eq(BigNumber(40000));

        amm.withdraw(BigNumber(19000), alice);

        expect(await amm.getShareOf(alice)).to.eq(BigNumber(0));
        expect(await firstToken.balanceOf(alice)).to.eq(BigNumber(90000 + 19000 * 10000 / 20000));
        expect(await secondToken.balanceOf(alice)).to.eq(BigNumber(60000 + 19000 * 40000 / 20000));
        expect(await firstToken.balanceOf(amm.address)).to.eq(BigNumber(10000 - 19000 * 10000 / 20000));
        expect(await secondToken.balanceOf(amm.address)).to.eq(BigNumber(40000 - 19000 * 40000 / 20000));
    });

    it("swap", async () => {
        amm.provide(BigNumber(10000), BigNumber(33000), alice);
        await amm.swap(firstToken.address, secondToken.address, BigNumber(1000), alice);

        //  # swap:
        //  - In: 1000, Out: 3000
        //  - Calculate: (1000 * 33000) / (1000 + 10000) = 3000
        //
        //  # result
        //  - firstToken: 100000 - 10000 - 1000 = 89000
        //  - secondToken: 100000 - 33000 + 3000 = 70000
        expect(await firstToken.balanceOf(alice)).to.eq(BigNumber(89000));
        expect(await secondToken.balanceOf(alice)).to.eq(BigNumber(70000));
    });
});
