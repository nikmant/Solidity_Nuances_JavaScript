// play_with_contract.js
// Это скрипт для игр со смарт контрактом
const hre = require("hardhat");

// определяю, чтобы путь к подбиблиотеке был короче
const ethers = hre.ethers;

// подключаю описание тестируемого контракта
const TransferArtifact = require('../artifacts/contracts/Transfers.sol/Transfers.json')

// моя функция для вывода балансов любых адресов
async function currentBalance(address, msg = '')
{
    const rawBalance = await ethers.provider.getBalance(address);
    console.log(msg, ethers.utils.formatEther(rawBalance));
}

// Главная выполняемая фуцнкия
async function main()
{
    // Получаю список счетов доступных в тестовом кошельке
    const [acc0,acc1,acc2,acc3] = (await hre.ethers.getSigners());

    // Адрес смарт-контракта
    const contractAddr = '0x5FC8d32690cc91D4c39d9d3abcBD16989F875707';
    // Объект смарт-контракта, со своим ABI, подключенный
    // для вызовов по-умолчанию из под указанного счёта
    const myContract = new ethers.Contract(
        contractAddr,
        TransferArtifact.abi,
        acc0
    );

    // Просто (ВНЕ контракта) отправляем 1 эфир с одного счёта на другой
    // При этом счётом получателя в нашем примере является счёт контракта
    const tx = 
    {
        to: contractAddr,
        value: ethers.utils.parseEther('1')
    }
    const txSend = await acc2.sendTransaction(tx);
    await txSend.wait();

    // Вывожу балансы счёта отправителя и счёта получателя (контракта)
    await currentBalance(acc2.address, 'Account 2 balance: ');
    await currentBalance(contractAddr, 'Contract balance: ');

    // Вызывая ФУНЦИЮ КОНТРАКТА,
    // ... вывожу значение простейшей pure функции
    console.log('function Say18: ', await myContract.Say18() );
    // ...вывожу кол-во полученных контрактом трансферов
    console.log( await myContract.GetCountCurrentTransfers() );
    // ...вывожу кол-во полученных контрактом эфиров в рамках 0-го трансфера,
    //    а также от кого этот эфир был прислан
    //    (работа с полями результата)
    const result = await myContract.getTransfer(0);
    console.log('in the contract we have ', ethers.utils.formatEther(result['amount']), ' ethers from address ', result['sender']);

    // (из под адреса 0) Вывожу весь баланс контракта на адрес 3
    console.log(await myContract.connect(acc1).withdrawTo(acc3.address));

    // вывожу балансы всех счетов
    await currentBalance(acc0.address, 'acc0 balance: ');
    await currentBalance(acc1.address, 'acc1 balance: ');
    await currentBalance(acc2.address, 'acc2 balance: ');
    await currentBalance(acc3.address, 'acc3 balance: ');

}

main().catch((error) => {
    console.log(error);
    process.exitCode = 1;
});