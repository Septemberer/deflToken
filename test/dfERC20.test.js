const { time } = require('@openzeppelin/test-helpers');
const { expect } = require("chai")
const { utils } = require("ethers");
const { ethers } = require("hardhat")
const { BigNumber } = require("ethers");

require('dotenv').config();

const {
} = process.env;

const TWO = BigNumber.from(2);
const ONE_TOKEN = BigNumber.from(10).pow(18);


describe("dfERC20", function () {

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

    await token.connect(dev2).transfer(dtoken.address, ONE_TOKEN.mul(1000))
    await dtoken.connect(dev2).transfer(dtoken.address, ONE_TOKEN.mul(1000))

    // await dtoken.connect(dev2).startLiquidity(ONE_TOKEN.mul(100), ONE_TOKEN.mul(100));
  })

  it("Should be deployed", async function () {
    expect(dtoken.address).to.be.properAddress
  })

  it("Test small transfer (without liquidity)", async function () {
    await dtoken.connect(dev2).transfer(alice.address, ONE_TOKEN.mul(2))
    expect(await dtoken.balanceOf(alice.address)).to.be.equal(ONE_TOKEN.mul(2))
  })

  it("Test big transfer (with liquidity)", async function () {
    let start_bal = await dtoken.totalSupply();

    await token.connect(dev2).approve(router.address, ONE_TOKEN.mul(100))
    await dtoken.connect(dev2).approve(router.address, ONE_TOKEN.mul(100))

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

    //console.log("Ручное добавление ликвидности работает")

    await dtoken.connect(dev2).setLandS(ONE_TOKEN.mul(100));

    //console.log("LandS установлен")

    await dtoken.connect(dev2).transfer(alice.address, ONE_TOKEN.mul(100))
    await dtoken.connect(dev2).transfer(dev.address, ONE_TOKEN.mul(1000))

    await dtoken.connect(dev2).transfer(dev.address, ONE_TOKEN.mul(1000))
    await dtoken.connect(dev2).transfer(dev.address, ONE_TOKEN.mul(1000))

    await dtoken.connect(dev2).transfer(dev.address, ONE_TOKEN.mul(1000))
    await dtoken.connect(dev2).transfer(dev.address, ONE_TOKEN.mul(1000))
    await dtoken.connect(dev2).transfer(dev.address, ONE_TOKEN.mul(1000))

    expect(await dtoken.balanceOf(alice.address)).to.be.equal(ONE_TOKEN.mul(100))
    expect(await dtoken.balanceOf(dev.address)).to.be.equal(ONE_TOKEN.mul(6000))

    //console.log("Переводы от специальных адресов проводятся без комиссии")

    await dtoken.connect(dev).transfer(alice.address, ONE_TOKEN.mul(5000))

    expect(await dtoken.balanceOf(alice.address)).to.be.equal(ONE_TOKEN.mul(5000).mul(95).div(100).add(ONE_TOKEN.mul(100)))

    expect(await dtoken.balanceOf(dev.address)).to.be.equal(ONE_TOKEN.mul(1000))

    //console.log("Переводы от других адресов проводятся с комиссией")

    let end_bal = await dtoken.totalSupply();

    expect(end_bal < start_bal).to.be.true;

    //console.log("totalSupply уменьшился")

  })

  it("Try to buy and sell", async function () {

    await dtoken.connect(dev2).setLandS(ONE_TOKEN.mul(100));

    //console.log("try to buy")
    await token.connect(dev2).transfer(alice.address, ONE_TOKEN.mul(100))
    await token.connect(alice).approve(router.address, ONE_TOKEN.mul(100))

    await router.connect(alice).swapExactTokensForTokens(
      utils.parseEther("10"),
      0,
      [token.address, dtoken.address],
      alice.address,
      99999999999
    );
    //console.log("success")

    let alice_bal = await dtoken.balanceOf(alice.address)
    //console.log("try to sell")
    await dtoken.connect(alice).approve(router.address, ONE_TOKEN.mul(8))
    await router.connect(alice).swapExactTokensForTokens(
      utils.parseEther("8"),
      0,
      [dtoken.address, token.address],
      alice.address,
      99999999999
    );
    //console.log("success")

    alice_bal = alice_bal.sub(await dtoken.balanceOf(alice.address))

    expect(alice_bal).to.be.equal(ONE_TOKEN.mul(8))

  })
}) 