const hre = require("hardhat");

async function main() {
  const FirstToken = await hre.ethers.getContractFactory("FakeJPYC");
  const firstToken = await FirstToken.deploy();
  
  const SecondToken = await hre.ethers.getContractFactory("MyToken");
  const secondToken = await SecondToken.deploy();

  await firstToken.deployed();
  await secondToken.deployed();

  console.log("FakeJPYC deployed to:", firstToken.address);
  console.log("MyToken deployed to:", secondToken.address);

  const AMM = await hre.ethers.getContractFactory("AMM");
  const amm = await AMM.deploy(firstToken.address, secondToken.address);

  await amm.deployed();
  console.log("AMM deployed to:", amm.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
