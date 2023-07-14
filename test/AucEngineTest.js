const { expect } = require("chai")
const { ethers } = require("hardhat")

describe("AucEngine", function () {
  let owner
  let seller
  let buyer
  let auct

  beforeEach(async function () {
    // Беру первые 3 аккаунта тестового блокчейта
    // ...и кладу их в соотвествующие 3 переменные
    [owner, seller, buyer] = await ethers.getSigners()
    // Создаю контракт
    const AucEngine = await ethers.getContractFactory("AucEngine", owner)
    // Деплою его
    auct = await AucEngine.deploy()
    // Дожидаюсь деплоя
    await auct.deployed()
  })

  // Проверка,кто владелец контракта
  it("sets owner", async function() {
    const currentOwner = await auct.owner()
    expect(currentOwner).to.eq(owner.address)
  })

  // Получаю текущее время блока в блокчейне
  // на выходе получаю timestamp
  async function getTimestamp(bn) {
    return (
      await ethers.provider.getBlock(bn)
    ).timestamp
  }

  // Блок проверок функции создания Аукциона
  describe("createAuction", function () {
    it("creates auction correctly", async function() {
      const duration = 60
      // Создаю контракт
      const tx = await auct.connect(seller).createAuction(
        ethers.utils.parseEther("0.0001"),
        3,
        "fake item",
        duration
      )
      // Проверяю, что у созданного Аукциона поля заполнились корректно
      const cAuction = await auct.auctions(0) // Promise
      expect(cAuction.item).to.eq("fake item")
      const ts = await getTimestamp(tx.blockNumber)
      expect(cAuction.endsAt).to.eq(ts + duration)
    })
  })

  // Как сделать паузу в тесте, ожидая ms млсек
  function delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms))
  }

  // Блок проверок функции покупки
  describe("buy", function () {
    it("allows to buy", async function() {
      // Создаю контракт
      await auct.connect(seller).createAuction(
        ethers.utils.parseEther("0.0001"),
        3,
        "fake item",
        60
      )

      // Увеличиваем максимальное время прохождения теста, чтобы Mocha не отвалился от долгого теста
      this.timeout(5000) // 5 мек
      // Пауза реальная 1 сек
      await delay(1000)

      // Дёргаю функцию покупки из под 30го аккауна "покупатель"
      const buyTx = await auct.connect(buyer).
        buy(0, {value: ethers.utils.parseEther("0.0001")})
      // Это наш текущий аукцион[0]
      const cAuction = await auct.auctions(0)
      // Это цена, по которой покупатель купил товар
      const finalPrice = cAuction.finalPrice
      // expect(() => buyTx) - это передача транзакции в анонимной функции
      // это мы делаем, так как хотим проверить, что именно после ВЫПОЛНЕНИИ
      // указанной функции, баланс счёта поменяется на указанную величину
      await expect(() => buyTx).
        // Здесь проверяем, что баланс уменьшился
        to.changeEtherBalance(
          seller, finalPrice - Math.floor((finalPrice * 10) / 100)
        )

      // 
      await expect(buyTx)
        .to.emit(auct, 'AuctionEnded')
        .withArgs(0, finalPrice, buyer.address)

      await expect(
        auct.connect(buyer).
          buy(0, {value: ethers.utils.parseEther("0.0001")})
      ).to.be.revertedWith('stopped!')
    })
  })
})