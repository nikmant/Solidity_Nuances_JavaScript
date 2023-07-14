// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

contract AucEngine
{
  // Владелец аукционной площадки
  address public Owner;
  // Комисия владельца аукционной площадки
  uint constant FEE = 10;
  // Задаём константу(константа) определяющую, длительность аукциона в днях по умолчанию.
  // "2 days" автоматически конвертируется в uint количества секунд в 2 сутках
  uint constant DURATION = 2 days;

  // Аукцион, идущий от большой цены, к меньшей
  // КАЖДУЮ секунду цена будет уменьшаться на величину discountRate
  struct Auction
  {
    address payable seller;
    uint startPrice;   // Начальная цена
    uint finalPrice;   // Конечная цена
    uint startAt;      // Время начала аукциона
    uint endAt;        // Время завершения аукциона
    uint discountStep; // Сколько мы будем опускать от начальной цены каждую секунду
    string item;       // Описание продаваемого предмета
    bool stopped;      // Закончился ли аукцион
  }

  Auction[] public auctions;

  event EventAuctionCreated(uint index, string itemName, uint startingPrice, uint duratin);
  event EventAuctionEnded(uint index,  uint filalPrice, address winer);

  modifier onlyOwner()
  {
    require(msg.sender==Owner);
    _;
  }

  constructor()
  {
    Owner = msg.sender;
  }

  function withdraw() external onlyOwner
  {
    //...
  }

  // calldata - НЕизменяемое временное хранилище
  // memory   -   изменяемое временное хранилище
  function createAuction(
    uint _startingPrice, 
    uint _discountStep, 
    string calldata _item,
    uint _duration)
  external
  {
    // Проверим, задали ли в качестве длительности аукциона 0
    // Унарная форма записи условия
    uint duration = (_duration==0 ? DURATION : _duration);
    // - эта строка эквивалентна этому блоку кода:
    // if (_duration==0) {duration = DURATION} else {duration = _duration};

    // Проверю, что за время аукциона Цена товара НЕ уйдёт в минус.
    require(_startingPrice > _discountStep*duration);

    // Создаю экземпляр акциона в памыти
    Auction memory newAuction = Auction({
      seller: payable(msg.sender),
      startPrice: _startingPrice,
      finalPrice: _startingPrice,
      discountStep: _discountStep,
      startAt: block.timestamp,
      endAt: block.timestamp + duration,
      item: _item,
      stopped: false
    });

    auctions.push(newAuction);

    emit EventAuctionCreated(auctions.length-1, _item, _startingPrice, _discountStep);
  }

  function getPriceFor(uint _index)
  public
  view
  returns(uint)
  {
    Auction memory cAuction = auctions[_index];
    require(!cAuction.stopped, "stopped!");
    uint elapsed = block.timestamp - cAuction.startAt;
    uint discount = cAuction.discountStep * elapsed;
    return cAuction.startPrice - discount;
  }

  function buy(uint _index)
  external
  payable
  {
    Auction storage cAuction = auctions[_index];
    require(!cAuction.stopped, "stopped!");
    require(block.timestamp < cAuction.endAt, "ended!");
    uint cPrice = getPriceFor(_index);
    require(msg.value >= cPrice, "Not enough funds!");
    cAuction.stopped = true;
    cAuction.finalPrice = cPrice;
    uint refund = msg.value - cPrice;
    if (refund > 0)
    {
      payable(msg.sender).transfer(refund);
    }
    // Обязательно нужно Сначала умножать, а потом делить!!
    cAuction.seller.transfer(cPrice - ((cPrice*FEE)/100));
    // Событие
    emit EventAuctionEnded(_index, cPrice, msg.sender);
  }

}