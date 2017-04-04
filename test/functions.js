var accounts = [];
var accountNames = {};

addAccount(eth.accounts[0], "Account #0 - Miner");
addAccount(eth.accounts[1], "Account #1 - Owner / Beneficiary");
addAccount(eth.accounts[2], "Account #2 - Bidder #1");
addAccount(eth.accounts[3], "Account #3 - Bidder #2");
addAccount(eth.accounts[4], "Account #4 - Bidder #3");

var ownerAccount = eth.accounts[1];
var bidder1 = eth.accounts[2];
var bidder2 = eth.accounts[3];
var bidder3 = eth.accounts[4];

var contractAddress = null;
var contractABI = null;
function addContractAddressAndABI(address, abi) {
  contractAddress = address;
  contractABI = abi;
}

function printContractStaticDetails() {
  var contract = eth.contract(contractABI).at(contractAddress);
  var beneficiary = contract.beneficiary();
  console.log("RESULT: contract.beneficiary=" + beneficiary);
  var auctionStart = contract.auctionStart();
  console.log("RESULT: contract.auctionStart=" + auctionStart + " " + new Date(auctionStart * 1000));
  var biddingPeriod = contract.biddingPeriod();
  console.log("RESULT: contract.biddingPeriod=" + biddingPeriod + " biddingPeriodAt=" + auctionStart.plus(biddingPeriod) + " " +
    new Date(auctionStart.plus(biddingPeriod) * 1000));
  var auctionEndTime = contract.auctionEndTime();
  console.log("RESULT: contract.auctionEndTime=" + auctionEndTime + " " + new Date(auctionEndTime * 1000));
  var recoveryAfterPeriod = contract.recoveryAfterPeriod();
  console.log("RESULT: contract.recoveryAfterPeriod=" + recoveryAfterPeriod + " recoveryAfterPeriodAt=" +
    auctionStart.plus(recoveryAfterPeriod) + " " + new Date(auctionStart.plus(recoveryAfterPeriod) * 1000));
  var withdrawalTriggerAmount = contract.WITHDRAWAL_TRIGGER_AMOUNT();
  console.log("RESULT: contract.withdrawalTriggerAmount=" + web3.fromWei(withdrawalTriggerAmount, "ether") + " ETH");
}

function printContractDynamicDetails() {
  var contract = eth.contract(contractABI).at(contractAddress);
  var highestBidder = contract.highestBidder();
  console.log("RESULT: contract.highestBidder=" + highestBidder);
  var highestBid = contract.highestBid();
  console.log("RESULT: contract.highestBid=" + web3.fromWei(highestBid, "ether") + " ETH");

  var i;
  for (i = 2; i < 5; i++) {
    var bid = contract.getBid(eth.accounts[i]);
    console.log("RESULT: bid by " + eth.accounts[i] + " is " + web3.fromWei(bid, "ether") + " ETH");
  }

  var highestBidIncreasedEvent = contract.HighestBidIncreased({}, { fromBlock: 0, toBlock: "latest" });
  i = 0;
  highestBidIncreasedEvent.watch(function (error, result) {
    // console.log("RESULT: highestBidIncreasedEvent " + i++ + ": " + JSON.stringify(result));
    // RESULT: highestBidIncreasedEvent 0: {"address":"0x03d47b0d78f8dee3089037dffd5c9a1f7e7282af",
    //   "args":{"amount":"10000000000000000000","bidder":"0x0020017ba4c67f76c76b1af8c41821ee54f37171"},
    //   "blockHash":"0x6ae4a839e63f80dfd15b785335788b9cfd3b0b5710403cc2b0c120f67dac1f6e","blockNumber":2388,"event":"HighestBidIncreased",
    //   "logIndex":0,"removed":false,"transactionHash":"0xccd8c1ada9d94f819fcb19aa75f59020e33cf2b22ef78417faad4deea64d3700","transactionIndex":0}
    console.log("RESULT: HighestBidIncreased Event " + i++ + ": " + result.args.bidder + " " + web3.fromWei(result.args.amount, "ether") +
      " block " + result.blockNumber);
  });
  highestBidIncreasedEvent.stopWatching();

  var auctionClosedEvent = contract.AuctionClosed({}, { fromBlock: 0, toBlock: "latest" });
  i = 0;
  auctionClosedEvent.watch(function (error, result) {
    // console.log("RESULT: auctionClosedEvent " + i++ + ": " + JSON.stringify(result));
    // auctionClosedEvent 0: {"address":"0x30da52ef30bdaec61b43317cc045e4f267eaf779",
    // "args":{"amount":"13000000000000000000","winner":"0x004e64833635cd1056b948b57286b7c91e62731c"},
    // "blockHash":"0xa56f76fbe51ab19a0a1f6b485683b4164d5da2bfc48d0f7d072272bd20bbeb88","blockNumber":99,"event":"AuctionClosed",
    // "logIndex":0,"removed":false,"transactionHash":"0x8ab2549a38f734f681ddabb1c719ee337e2b35b2cc82fb3ae872b78dad80d002","transactionIndex":0}
    console.log("RESULT: AuctionClosed Event " + i++ + ": " + result.args.winner + " " + web3.fromWei(result.args.amount, "ether") +
      " block " + result.blockNumber);
  });
  auctionClosedEvent.stopWatching();
}

function unlockAccounts(password) {
  for (var i = 0; i < 5; i++) {
    personal.unlockAccount(eth.accounts[i], password, 100000);
  }
}

function addAccount(account, accountName) {
  accounts.push(account);
  accountNames[account] = accountName;
}

function printBalances() {
  var i = 0;
  console.log("RESULT: # Account                                                   EtherBalance Name");
  accounts.forEach(function(e) {
    i++;
    var etherBalance = web3.fromWei(eth.getBalance(e), "ether");
    console.log("RESULT: " + i + " " + e  + " " + pad(etherBalance) + " " + accountNames[e]);
  });
}

function pad(s) {
  var o = s.toFixed(18);
  while (o.length < 27) {
    o = " " + o;
  }
  return o;
}

function printTxData(name, txId) {
  var tx = eth.getTransaction(txId);
  var txReceipt = eth.getTransactionReceipt(txId);
  console.log("RESULT: " + name + " gas=" + tx.gas + " gasUsed=" + txReceipt.gasUsed + " cost=" + tx.gasPrice.mul(txReceipt.gasUsed).div(1e18) +
    " block=" + txReceipt.blockNumber + " txId=" + txId);
}

function assertEtherBalance(account, expectedBalance) {
  var etherBalance = web3.fromWei(eth.getBalance(account), "ether");
  if (etherBalance == expectedBalance) {
    console.log("RESULT: OK " + account + " has expected balance " + expectedBalance);
  } else {
    console.log("RESULT: FAILURE " + account + " has balance " + etherBalance + " <> expected " + expectedBalance);
  }
}

function gasEqualsGasUsed(tx) {
  var gas = eth.getTransaction(tx).gas;
  var gasUsed = eth.getTransactionReceipt(tx).gasUsed;
  if (gas == gasUsed) {
    return true;
  } else {
    return false;
  }
}
