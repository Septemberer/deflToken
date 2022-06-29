const { time } = require('@openzeppelin/test-helpers');
const { expect } = require("chai")
const { ethers } = require("hardhat")
const { BigNumber } = require("ethers");

require('dotenv').config();

const {
} = process.env;

const TWO = BigNumber.from(2);
const ONE_TOKEN = BigNumber.from(10).pow(18);


describe("CSFactory", function () {
  let staking;
  let crowdsale;
 

  let CrowdSale;

  let token;
  let dtoken;
  let weth;
  let factory;
  let router;

  let alice;
  let dev;
  let minter;
  let dev2;

  beforeEach(async function () {
    [alice, dev2, dev, minter] = await ethers.getSigners()
    const Token = await ethers.getContractFactory("MockERC20", minter)
    const DToken = await ethers.getContractFactory("dfERC20", dev2)
    const WETH = await ethers.getContractFactory("WETH")
    const PancakeFactory = await ethers.getContractFactory("PancakeFactory")
    const PancakeRouter = await ethers.getContractFactory("PancakeRouter")

    weth = await WETH.deploy()
    await weth.connect(dev2).deployed()

    factory = await PancakeFactory.deploy(dev2.address)
    await factory.connect(dev2).deployed()

    router = await PancakeRouter.deploy(factory.address, weth.address)
    await router.connect(dev2).deployed()


    token = await Token.deploy('LToken', 'LiqT', ONE_TOKEN.mul(100000))
    dtoken = await DToken.deploy(token.address, router.address)

    await token.deployed()
    await dtoken.deployed()

    await token.connect(minter).transfer(dev2.address, ONE_TOKEN.mul(2000))
  })

  it("Should be deployed", async function () {
    expect(dtoken.address).to.be.properAddress
  })

  it("Test swap", async function () {
    
    await token.connect(dev2).approve(router.address, ONE_TOKEN.mul(1000))
    await dtoken.connect(dev2).approve(router.address, ONE_TOKEN.mul(1000))
    console.log(await token.balanceOf(dev2.address))
    console.log(await dtoken.balanceOf(dev2.address))
    
    console.log("тык")
    await router.connect(dev2).addLiquidity(
        token.address,
        dtoken.address,
        ONE_TOKEN.mul(100),
        ONE_TOKEN.mul(100),
        0,
        0,
        dev2.address,
        9999999999
    );
    console.log("тык")
    await dtoken.transfer(alice.address, ONE_TOKEN.mul(100))
  })
}) 