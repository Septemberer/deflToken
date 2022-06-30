const { BigNumber } = require('ethers');
const { ethers } = require('hardhat');

require('dotenv').config();

const {
    ROUTER_ADDRESS
} = process.env;


const ONE = BigNumber.from(1);
const DECIMALS = BigNumber.from(18);
const ONE_TOKEN = ONE.pow(DECIMALS);

let token;
let dtoken;

async function main() {
    const LToken = await ethers.getContractFactory("LToken")
    const dfERC20 = await ethers.getContractFactory("dfERC20")


    token = await LToken.deploy(ONE_TOKEN.mul(100000))
    dtoken = await dfERC20.deploy(token.address, ROUTER_ADDRESS)

    await token.deployed()
    await dtoken.deployed()

    console.log("Token deployed to:", token.address);
    console.log("DFToken deployed to:", dtoken.address);

    await token.transfer(dtoken.address, ONE_TOKEN.mul(1000))
    await dtoken.transfer(dtoken.address, ONE_TOKEN.mul(1000))
    await dtoken.setLandS(ONE_TOKEN.mul(100));

    try {
        await verifyToken(token, "contracts/mocks/LToken.sol:testPayment", utils.parseEther("100000"));
        console.log("Verify LToken succees");
    }
    catch {
        console.log("Verify LToken failed");
    }

    try {
        await verifyDToken(dtoken,
            ROUTER_ADDRESS, token.address);
        console.log("Verify dtoken success");
    }
    catch {
        console.log("Verify dtoken failed");
    }

}

async function verifyToken(token, path, AMOUNT) {
    await hre.run("verify:verify", {
        address: token.address,
        contract: path,
        constructorArguments: [
            AMOUNT
        ]
    })
}

async function verifyDToken(
    dtoken,
    routerAddess,
    tokenAddress
) {
  await hre.run("verify:verify", {
    address: dtoken.address,
    constructorArguments: [
        routerAddess,
        tokenAddress
    ]
  })
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });