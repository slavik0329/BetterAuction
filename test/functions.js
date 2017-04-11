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
    console.log("RESULT: HighestBidIncreased Event " + i++ + ": " + result.args.bidder + " " + web3.fromWei(result.args.amount, "ether") +
      " block " + result.blockNumber);
  });
  highestBidIncreasedEvent.stopWatching();

  var auctionClosedEvent = contract.AuctionClosed({}, { fromBlock: 0, toBlock: "latest" });
  i = 0;
  auctionClosedEvent.watch(function (error, result) {
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
