#!/bin/sh
# --------------------------------------------------------------------
# Testing BetterAuction Contracts
#
# (c) Bok Consulting Pty Ltd, Amir & Steve 2017. The MIT licence.
# --------------------------------------------------------------------

GETHATTACHPOINT=`grep ^IPCFILE= settings.txt | sed "s/^.*=//"`
PASSWORD=`grep ^PASSWORD= settings.txt | sed "s/^.*=//"`
BETTERAUCTIONSOL=`grep ^BETTERAUCTIONSOL= settings.txt | sed "s/^.*=//"`
INCLUDEJS=`grep ^INCLUDEJS= settings.txt | sed "s/^.*=//"`
TEST1OUTPUT=`grep ^TEST1OUTPUT= settings.txt | sed "s/^.*=//"`
TEST1RESULTS=`grep ^TEST1RESULTS= settings.txt | sed "s/^.*=//"`

CURRENTTIME=`date +%s`
CURRENTTIMES=`date -r $CURRENTTIME -u`
BIDDINGPERIOD=`echo "60*4" | bc`
RECOVERYPERIOD=`echo "60*5" | bc`
CURRENTTIMEP10M=`echo "$CURRENTTIME+60*10" | bc`
CURRENTTIMEP10MS=`date -r $CURRENTTIMEP10M -u`

printf "GETHATTACHPOINT              = '$GETHATTACHPOINT'\n"
printf "PASSWORD                     = '$PASSWORD'\n"
printf "BETTERAUCTIONSOL             = '$BETTERAUCTIONSOL'\n"
printf "INCLUDEJS                    = '$INCLUDEJS'\n"
printf "TEST1OUTPUT                  = '$TEST1OUTPUT'\n"
printf "TEST1RESULTS                 = '$TEST1RESULTS'\n"
printf "CURRENTTIME                  = '$CURRENTTIME' '$CURRENTTIMES'\n"
printf "BIDDINGPERIOD                = '$BIDDINGPERIOD' s\n"
printf "RECOVERYPERIOD               = '$RECOVERYPERIOD' s\n"
printf "CURRENTTIMEP10M              = '$CURRENTTIMEP10M' '$CURRENTTIMEP10MS'\n"

FLATTENEDSOL=`./stripCrLf $BETTERAUCTIONSOL | tr -s ' '`
printf "var betterAuctionSource = \"$FLATTENEDSOL\"" > $INCLUDEJS

geth --verbosity 3 attach $GETHATTACHPOINT << EOF | tee $TEST1OUTPUT
loadScript("functions.js");
unlockAccounts("$PASSWORD");
printBalances();

// Load source code
loadScript("$INCLUDEJS");
console.log("betterAuctionSource=" + betterAuctionSource);
// Compile source code
var betterAuctionCompiled = web3.eth.compile.solidity(betterAuctionSource);
console.log("----------v betterAuctionCompiled v----------");
betterAuctionCompiled;
console.log("----------^ betterAuctionCompiled ^----------");
console.log("DATA: betterAuctionABI=" + JSON.stringify(betterAuctionCompiled["<stdin>:BetterAuction"].info.abiDefinition));

var skipCompletedTests = false;
var betterAuctionContract = web3.eth.contract(betterAuctionCompiled["<stdin>:BetterAuction"].info.abiDefinition);

if (!skipCompletedTests) {
  console.log("RESULT: --------------------------------------------------------------------------------------");
  console.log("RESULT: Test 1.1 - Incorrect parameters (0x0, BIDDINGPERIOD, RECOVERYPERIOD) - fail deployment");
  var betterAuction11Address = null;
  var betterAuction11Tx = null;
  var better11Auction = betterAuctionContract.new("0x0000000000000000000000000000000000000000", $BIDDINGPERIOD, $RECOVERYPERIOD,
    {from: ownerAccount, data: betterAuctionCompiled["<stdin>:BetterAuction"].code, gas: 800000},
    function(e, contract) {
      if (!e) {
        if (!contract.address) {
          betterAuction11Tx = contract.transactionHash;
          console.log("betterAuction11Tx=" + betterAuction11Tx);
        } else {
          betterAuction11Address = contract.address;
          addAccount(betterAuction11Address, "BetterAuction Contract");
          console.log("DATA: betterAuction11Address=" + betterAuction11Address);
          printTxData("betterAuction11Address=" + betterAuction11Address, betterAuction11Tx);
        }
      }
    }
  );
  while (txpool.status.pending > 0) {
  }
  printTxData("betterAuction11Address=" + betterAuction11Address, betterAuction11Tx);
  printBalances();
  if (betterAuction11Address == null || gasEqualsGasUsed(betterAuction11Tx)) {
    console.log("RESULT: PASS Test 1.1 - Incorrect parameters (0x0, BIDDINGPERIOD, RECOVERYPERIOD) - fail deployment");
  } else {
    console.log("RESULT: FAIL Test 1.1 - Incorrect parameters (0x0, BIDDINGPERIOD, RECOVERYPERIOD) - fail deployment");
  }
 console.log("RESULT: ");
}

if (!skipCompletedTests) {
  console.log("RESULT: --------------------------------------------------------------------------------------");
  console.log("RESULT: Test 1.2 - Incorrect parameters (owner, RECOVERYPERIOD, BIDDINGPERIOD) - fail deployment");
  var betterAuction12Address = null;
  var betterAuction12Tx = null;
  var better12Auction = betterAuctionContract.new(ownerAccount, $RECOVERYPERIOD, $BIDDINGPERIOD,
    {from: ownerAccount, data: betterAuctionCompiled["<stdin>:BetterAuction"].code, gas: 800000},
    function(e, contract) {
      if (!e) {
        if (!contract.address) {
          betterAuction12Tx = contract.transactionHash;
          console.log("betterAuction12Tx=" + betterAuction12Tx);
        } else {
          betterAuction12Address = contract.address;
          addAccount(betterAuction12Address, "BetterAuction Contract");
          console.log("DATA: betterAuction12Address=" + betterAuction12Address);
          printTxData("betterAuction12Address=" + betterAuction12Address, betterAuction12Tx);
        }
      }
    }
  );
  while (txpool.status.pending > 0) {
  }
  printTxData("betterAuction12Address=" + betterAuction12Address, betterAuction12Tx);
  printBalances();
  if (betterAuction12Address == null || gasEqualsGasUsed(betterAuction12Tx)) {
    console.log("RESULT: PASS Test 1.2 - Incorrect parameters (owner, RECOVERYPERIOD, BIDDINGPERIOD) - fail deployment");
  } else {
    console.log("RESULT: FAIL Test 1.2 - Incorrect parameters (owner, RECOVERYPERIOD, BIDDINGPERIOD) - fail deployment");
  }
 console.log("RESULT: ");
}

console.log("RESULT: --------------------------------------------------------------------------------------");
console.log("RESULT: Test 1.3 - Correct parameters (owner, BIDDINGPERIOD, RECOVERYPERIOD) - pass deployment");
var betterAuctionAddress = null;
var betterAuction13Tx = null;
var better13Auction = betterAuctionContract.new(ownerAccount, $BIDDINGPERIOD, $RECOVERYPERIOD,
  {from: ownerAccount, data: betterAuctionCompiled["<stdin>:BetterAuction"].code, gas: 800000},
  function(e, contract) {
    if (!e) {
      if (!contract.address) {
        betterAuction13Tx = contract.transactionHash;
        console.log("betterAuction13Tx=" + betterAuction13Tx);
      } else {
        betterAuctionAddress = contract.address;
        addAccount(betterAuctionAddress, "BetterAuction Contract");
        console.log("DATA: betterAuctionAddress=" + betterAuctionAddress);
        printTxData("betterAuctionAddress=" + betterAuctionAddress, betterAuction13Tx);
        addContractAddressAndABI(betterAuctionAddress, betterAuctionCompiled["<stdin>:BetterAuction"].info.abiDefinition);
      }
    }
  }
);
while (txpool.status.pending > 0) {
}
printBalances();
printContractStaticDetails();
printContractDynamicDetails();
if (betterAuctionAddress == null || gasEqualsGasUsed(betterAuction13Tx)) {
  console.log("RESULT: FAIL Test 1.3 - Correct parameters (owner, BIDDINGPERIOD, RECOVERYPERIOD) - pass deployment");
} else {
  console.log("RESULT: PASS Test 1.3 - Correct parameters (owner, BIDDINGPERIOD, RECOVERYPERIOD) - pass deployment");
}
console.log("RESULT: ");

var betterAuction = eth.contract(betterAuctionCompiled["<stdin>:BetterAuction"].info.abiDefinition).at(betterAuctionAddress);

console.log("RESULT: --------------------------------------------------------------------------------------");
console.log("RESULT: Test 2.1 - Bidder #1 bids 10 ETH - successful bid");
var betterAuction21Tx = eth.sendTransaction({from: bidder1, to: betterAuctionAddress, value: web3.toWei(10, "ether"), gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("betterAuction21Tx", betterAuction21Tx);
printBalances();
printContractDynamicDetails();
if (gasEqualsGasUsed(betterAuction21Tx)) {
  console.log("RESULT: FAIL Test 2.1 - Bidder #1 bids 10 ETH - successful bid");
} else {
  console.log("RESULT: PASS Test 2.1 - Bidder #1 bids 10 ETH - successful bid");
}
console.log("RESULT:   CHECK 1. Auction contract has 10 ETH");
console.log("RESULT:   CHECK 2. Highest bid is 10 ETH");
console.log("RESULT:   CHECK 3. Bidder #1 balance is reduced by 10 ETH");
console.log("RESULT: ");

console.log("RESULT: --------------------------------------------------------------------------------------");
console.log("RESULT: Test 2.2 - Bidder #2 bids 5 ETH - failed bid");
var betterAuction22Tx = eth.sendTransaction({from: bidder2, to: betterAuctionAddress, value: web3.toWei(5, "ether"), gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("betterAuction22Tx", betterAuction22Tx);
printBalances();
printContractDynamicDetails();
if (gasEqualsGasUsed(betterAuction22Tx)) {
  console.log("RESULT: PASS Test 2.2 - Bidder #2 bids 5 ETH - failed bid");
} else {
  console.log("RESULT: FAIL Test 2.2 - Bidder #2 bids 5 ETH - failed bid");
}
console.log("RESULT:   CHECK 1. Auction contract has 10 ETH");
console.log("RESULT:   CHECK 2. Highest bid is 10 ETH");
console.log("RESULT:   CHECK 3. Bidder #2 balance remains the same");
console.log("RESULT: ");

console.log("RESULT: --------------------------------------------------------------------------------------");
console.log("RESULT: Test 2.3 - Bidder #2 bids 10 ETH - bid failed");
var betterAuction23Tx = eth.sendTransaction({from: bidder2, to: betterAuctionAddress, value: web3.toWei(10, "ether"), gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("betterAuction23Tx", betterAuction23Tx);
printBalances();
printContractDynamicDetails();
if (gasEqualsGasUsed(betterAuction23Tx)) {
  console.log("RESULT: PASS Test 2.3 - Bidder #2 bids 10 ETH - failed bid");
} else {
  console.log("RESULT: FAIL Test 2.3 - Bidder #2 bids 10 ETH - failed bid");
}
console.log("RESULT:   CHECK 1. Auction contract has 10 ETH");
console.log("RESULT:   CHECK 2. Highest bid is 10 ETH");
console.log("RESULT:   CHECK 3. Bidder #2 balance remains the same");
console.log("RESULT: ");

console.log("RESULT: --------------------------------------------------------------------------------------");
console.log("RESULT: Test 2.4 - Bidder #2 bids 10.01 ETH - successful bid");
var betterAuction24Tx = eth.sendTransaction({from: bidder2, to: betterAuctionAddress, value: web3.toWei(10.01, "ether"), gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("betterAuction24Tx", betterAuction24Tx);
printBalances();
printContractDynamicDetails();
if (gasEqualsGasUsed(betterAuction24Tx)) {
  console.log("RESULT: FAIL Test 2.4 - Bidder #2 bids 10.01 ETH - successful bid");
} else {
  console.log("RESULT: PASS Test 2.4 - Bidder #2 bids 10.01 ETH - successful bid");
}
console.log("RESULT:   CHECK 1. Auction contract has 20.01 ETH");
console.log("RESULT:   CHECK 2. Highest bid is 10.01 ETH");
console.log("RESULT:   CHECK 3. Bidder #2 balance is reduced by 10.01 ETH");
console.log("RESULT: ");

console.log("RESULT: --------------------------------------------------------------------------------------");
console.log("RESULT: Test 2.5 - Bidder #1 tops up bid by 0.01 ETH - failed bid");
var betterAuction25Tx = eth.sendTransaction({from: bidder1, to: betterAuctionAddress, value: web3.toWei(0.01, "ether"), gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("betterAuction25Tx", betterAuction25Tx);
printBalances();
printContractDynamicDetails();
if (gasEqualsGasUsed(betterAuction25Tx)) {
  console.log("RESULT: PASS Test 2.5 - Bidder #1 tops up bid by 0.01 ETH - failed bid");
} else {
  console.log("RESULT: FAIL Test 2.5 - Bidder #1 tops up bid by 0.01 ETH - failed bid");
}
console.log("RESULT:   CHECK 1. Auction contract has 20.01 ETH");
console.log("RESULT:   CHECK 2. Highest bid is 10.01 ETH");
console.log("RESULT:   CHECK 3. Bidder #1 balance remains the same");
console.log("RESULT: ");

console.log("RESULT: --------------------------------------------------------------------------------------");
console.log("RESULT: Test 2.6 - Bidder #1 tops up bid by 1 ETH - successful bid");
var betterAuction26Tx = eth.sendTransaction({from: bidder1, to: betterAuctionAddress, value: web3.toWei(1, "ether"), gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("betterAuction26Tx", betterAuction26Tx);
printBalances();
printContractDynamicDetails();
if (gasEqualsGasUsed(betterAuction26Tx)) {
  console.log("RESULT: FAIL Test 2.6 - Bidder #1 tops up bid by 1 ETH - successful bid");
} else {
  console.log("RESULT: PASS Test 2.6 - Bidder #1 tops up bid by 1 ETH - successful bid");
}
console.log("RESULT:   CHECK 1. Auction contract has 21.01 ETH");
console.log("RESULT:   CHECK 2. Highest bid is 11 ETH");
console.log("RESULT:   CHECK 3. Bidder #1 balance is reduced by 1 ETH");
console.log("RESULT: ");

console.log("RESULT: --------------------------------------------------------------------------------------");
console.log("RESULT: Test 2.7 - Bidder #3 bids 13 ETH - successful bid");
var betterAuction27Tx = eth.sendTransaction({from: bidder3, to: betterAuctionAddress, value: web3.toWei(13, "ether"), gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("betterAuction27Tx", betterAuction27Tx);
printBalances();
printContractDynamicDetails();
if (gasEqualsGasUsed(betterAuction27Tx)) {
  console.log("RESULT: FAIL Test 2.7 - Bidder #3 bids 13 ETH - successful bid");
} else {
  console.log("RESULT: PASS Test 2.7 - Bidder #3 bids 13 ETH - successful bid");
}
console.log("RESULT:   CHECK 1. Auction contract has 34.01 ETH");
console.log("RESULT:   CHECK 2. Highest bid is 13 ETH");
console.log("RESULT:   CHECK 3. Bidder #3 balance is reduced by 13 ETH");
console.log("RESULT: ");

console.log("RESULT: --------------------------------------------------------------------------------------");
console.log("RESULT: Test 2.8 - Bidder #3 withdraws funds - unsuccessful withdrawal");
var betterAuction28Tx = eth.sendTransaction({from: bidder3, to: betterAuctionAddress, value: web3.toWei(0.0001, "ether"), gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("betterAuction28Tx", betterAuction28Tx);
printBalances();
printContractDynamicDetails();
if (gasEqualsGasUsed(betterAuction28Tx)) {
  console.log("RESULT: PASS Test 2.8 - Bidder #3 withdraws funds - unsuccessful withdrawal");
} else {
  console.log("RESULT: FAIL Test 2.8 - Bidder #3 withdraws funds - unsuccessful withdrawal");
}
console.log("RESULT:   CHECK 1. Auction contract has 34.01 ETH");
console.log("RESULT:   CHECK 2. Highest bid is 13 ETH");
console.log("RESULT:   CHECK 3. Bidder #3 balance remains the same");
console.log("RESULT: ");

console.log("RESULT: --------------------------------------------------------------------------------------");
console.log("RESULT: Test 2.9 - Bidder #1 withdraws funds - successful withdrawal");
var betterAuction29Tx = eth.sendTransaction({from: bidder1, to: betterAuctionAddress, value: web3.toWei(0.0001, "ether"), gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("betterAuction29Tx", betterAuction29Tx);
printBalances();
printContractDynamicDetails();
if (gasEqualsGasUsed(betterAuction29Tx)) {
  console.log("RESULT: FAIL Test 2.9 - Bidder #1 withdraws funds - successful withdrawal");
} else {
  console.log("RESULT: PASS Test 2.9 - Bidder #1 withdraws funds - successful withdrawal");
}
console.log("RESULT:   CHECK 1. Auction contract has 23.01 ETH");
console.log("RESULT:   CHECK 2. Highest bid is 13 ETH");
console.log("RESULT:   CHECK 3. Bidder #1 balance increases by 11 ETH");
console.log("RESULT: ");

console.log("RESULT: --------------------------------------------------------------------------------------");
console.log("RESULT: Test 2.10 - Bidder #2 withdraws funds by calling nonHighestBidderRefund() with 0 ETH - successful withdrawal");
var betterAuction210Tx = betterAuction.nonHighestBidderRefund({from: bidder2, value: 0, gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("betterAuction210Tx", betterAuction210Tx);
printBalances();
printContractDynamicDetails();
if (gasEqualsGasUsed(betterAuction210Tx)) {
  console.log("RESULT: FAIL Test 2.10 - Bidder #2 withdraws funds by calling nonHighestBidderRefund() with 0 ETH - successful withdrawal");
} else {
  console.log("RESULT: PASS Test 2.10 - Bidder #2 withdraws funds by calling nonHighestBidderRefund() with 0 ETH - successful withdrawal");
}
console.log("RESULT:   CHECK 1. Auction contract has 13 ETH");
console.log("RESULT:   CHECK 2. Highest bid is 13 ETH");
console.log("RESULT:   CHECK 3. Bidder #2 balance increases by 10.01 ETH");
console.log("RESULT: ");

console.log("RESULT: --------------------------------------------------------------------------------------");
console.log("RESULT: Test 2.11 - Bidder #3 calls the internal BidderUpdateBid function with 20 ETH - unsuccessful call");
// The following ABI includes the internal function bidderUpdateBid() which should not be callable
var contractABIIncludingBidderUpdateBid = [{"constant":true,"inputs":[],"name":"recoveryAfterPeriod","outputs":[{"name":"","type":"uint256"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"beneficiary","outputs":[{"name":"","type":"address"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"auctionEndTime","outputs":[{"name":"","type":"uint256"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"WITHDRAWAL_TRIGGER_AMOUNT","outputs":[{"name":"","type":"uint256"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"auctionStart","outputs":[{"name":"","type":"uint256"}],"payable":false,"type":"function"},{"constant":false,"inputs":[],"name":"beneficiaryCloseAuction","outputs":[],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"biddingPeriod","outputs":[{"name":"","type":"uint256"}],"payable":false,"type":"function"},{"constant":false,"inputs":[],"name":"nonHighestBidderRefund","outputs":[],"payable":true,"type":"function"},{"constant":false,"inputs":[],"name":"bidderPlaceBid","outputs":[],"payable":true,"type":"function"},{"constant":true,"inputs":[],"name":"highestBidder","outputs":[{"name":"","type":"address"}],"payable":false,"type":"function"},{"constant":false,"inputs":[],"name":"beneficiaryRecoverFunds","outputs":[],"payable":false,"type":"function"},{"constant":false,"inputs":[],"name":"bidderUpdateBid","outputs":[],"payable":false,"type":"function"},{"constant":true,"inputs":[{"name":"_address","type":"address"}],"name":"getBid","outputs":[{"name":"","type":"uint256"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"highestBid","outputs":[{"name":"","type":"uint256"}],"payable":false,"type":"function"},{"inputs":[{"name":"_beneficiary","type":"address"},{"name":"_biddingPeriod","type":"uint256"},{"name":"_recoveryAfterPeriod","type":"uint256"}],"payable":false,"type":"constructor"},{"payable":true,"type":"fallback"},{"anonymous":false,"inputs":[{"indexed":false,"name":"bidder","type":"address"},{"indexed":false,"name":"amount","type":"uint256"}],"name":"HighestBidIncreased","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"winner","type":"address"},{"indexed":false,"name":"amount","type":"uint256"}],"name":"AuctionClosed","type":"event"}];
var contractIncludingBidderUpdateBid = eth.contract(contractABIIncludingBidderUpdateBid).at(betterAuctionAddress);
var betterAuction211Tx = contractIncludingBidderUpdateBid.bidderUpdateBid({from: bidder3, to: betterAuctionAddress, value: web3.toWei(20, "ether"), gas: 100000});
while (txpool.status.pending > 0) {
}
if (betterAuction211Tx != null) {
  printTxData("betterAuction211Tx", betterAuction211Tx);
}
printBalances();
printContractDynamicDetails();
if (betterAuction211Tx == null || gasEqualsGasUsed(betterAuction211Tx)) {
  console.log("RESULT: PASS Test 2.11 - Bidder #3 calls the internal BidderUpdateBid function with 20 ETH - unsuccessful call");
} else {
  console.log("RESULT: FAIL Test 2.11 - Bidder #3 calls the internal BidderUpdateBid function with 20 ETH - unsuccessful call");
}
console.log("RESULT:   CHECK 1. Auction contract has 13 ETH");
console.log("RESULT:   CHECK 2. Highest bid is 13 ETH");
console.log("RESULT:   CHECK 3. Bidder #3 balance remains the same");
console.log("RESULT: ");

console.log("RESULT: --------------------------------------------------------------------------------------");
console.log("RESULT: Test 2.12 - Owner calls beneficiaryCloseAuction() before auction closes - unsuccessful");
var betterAuction212Tx = betterAuction.beneficiaryCloseAuction({from: ownerAccount, value: 0, gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("betterAuction212Tx", betterAuction212Tx);
printBalances();
printContractDynamicDetails();
if (gasEqualsGasUsed(betterAuction212Tx)) {
  console.log("RESULT: PASS Test 2.12 - Owner calls beneficiaryCloseAuction() before auction closes - unsuccessful");
} else {
  console.log("RESULT: FAIL Test 2.12 - Owner calls beneficiaryCloseAuction() before auction closes - unsuccessful");
}
console.log("RESULT:   CHECK 1. Auction contract has 13 ETH");
console.log("RESULT:   CHECK 2. Highest bid is 13 ETH");
console.log("RESULT: ");

console.log("RESULT: --------------------------------------------------------------------------------------");
console.log("RESULT: Test 2.13 - Owner calls beneficiaryRecoverFunds() before recovery period is active - unsuccessful");
var betterAuction213Tx = betterAuction.beneficiaryRecoverFunds({from: ownerAccount, value: 0, gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("betterAuction213Tx", betterAuction213Tx);
printBalances();
printContractDynamicDetails();
if (gasEqualsGasUsed(betterAuction213Tx)) {
  console.log("RESULT: PASS Test 2.13 - Owner calls beneficiaryRecoverFunds() before recovery period is active - unsuccessful");
} else {
  console.log("RESULT: FAIL Test 2.13 - Owner calls beneficiaryRecoverFunds() before recovery period is active - unsuccessful");
}
console.log("RESULT:   CHECK 1. Auction contract has 13 ETH");
console.log("RESULT:   CHECK 2. Highest bid is 13 ETH");
console.log("RESULT: ");

console.log("RESULT: --------------------------------------------------------------------------------------");
console.log("RESULT: Test 2.14 - Bidder #2 bids 50 ETH - successful bid");
var betterAuction214Tx = eth.sendTransaction({from: bidder2, to: betterAuctionAddress, value: web3.toWei(50, "ether"), gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("betterAuction214Tx", betterAuction214Tx);
printBalances();
printContractDynamicDetails();
if (gasEqualsGasUsed(betterAuction214Tx)) {
  console.log("RESULT: FAIL Test 2.14 - Bidder #2 bids 50 ETH - successful bid");
} else {
  console.log("RESULT: PASS Test 2.14 - Bidder #2 bids 50 ETH - successful bid");
}
console.log("RESULT:   CHECK 1. Auction contract has 63 ETH");
console.log("RESULT:   CHECK 2. Highest bid is 50 ETH");
console.log("RESULT:   CHECK 3. Bidder #2 balance is reduced by 50 ETH");
console.log("RESULT: ");

console.log("RESULT: --------------------------------------------------------------------------------------");
console.log("RESULT: Test 2.15 - Bidder #1 bids 100 ETH - successful bid");
var betterAuction215Tx = eth.sendTransaction({from: bidder1, to: betterAuctionAddress, value: web3.toWei(100, "ether"), gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("betterAuction215Tx", betterAuction215Tx);
printBalances();
printContractDynamicDetails();
if (gasEqualsGasUsed(betterAuction215Tx)) {
  console.log("RESULT: FAIL Test 2.15 - Bidder #1 bids 100 ETH - successful bid");
} else {
  console.log("RESULT: PASS Test 2.15 - Bidder #1 bids 100 ETH - successful bid");
}
console.log("RESULT:   CHECK 1. Auction contract has 163 ETH");
console.log("RESULT:   CHECK 2. Highest bid is 100 ETH");
console.log("RESULT:   CHECK 3. Bidder #1 balance is reduced by 100 ETH");
console.log("RESULT: ");

console.log("RESULT: --------------------------------------------------------------------------------------");
console.log("RESULT: Test 3.1 - Owner calls beneficiaryCloseAuction() after auction closes - successful");
var auctionEndTime = betterAuction.auctionEndTime();
var auctionEndDate = new Date(auctionEndTime * 1000);
console.log("RESULT: Waiting until auction closes at " + auctionEndTime + " " + auctionEndDate + " currentDate=" + new Date());
while ((new Date()).getTime() < auctionEndDate.getTime()) {
}
console.log("RESULT: Waited until auction closed at " + auctionEndTime + " " + auctionEndDate + " currentDate=" + new Date());
var betterAuction31Tx = betterAuction.beneficiaryCloseAuction({from: ownerAccount, value: 0, gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("betterAuction31Tx", betterAuction31Tx);
printBalances();
printContractDynamicDetails();
if (gasEqualsGasUsed(betterAuction31Tx)) {
  console.log("RESULT: FAIL Test 3.1 - Owner calls beneficiaryCloseAuction() after auction closes - successful");
} else {
  console.log("RESULT: PASS Test 3.1 - Owner calls beneficiaryCloseAuction() after auction closes - successful");
}
console.log("RESULT:   CHECK 1. Auction contract has 63 ETH");
console.log("RESULT:   CHECK 2. Owner balance is increased by 100 ETH");
console.log("RESULT: ");

console.log("RESULT: --------------------------------------------------------------------------------------");
console.log("RESULT: Test 3.2 - Bidder #2 withdraws funds - successful withdrawal");
var betterAuction32Tx = eth.sendTransaction({from: bidder2, to: betterAuctionAddress, value: web3.toWei(0.0001, "ether"), gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("betterAuction32Tx", betterAuction32Tx);
printBalances();
printContractDynamicDetails();
if (gasEqualsGasUsed(betterAuction32Tx)) {
  console.log("RESULT: FAIL Test 3.2 - Bidder #2 withdraws funds - successful withdrawal");
} else {
  console.log("RESULT: PASS Test 3.2 - Bidder #2 withdraws funds - successful withdrawal");
}
console.log("RESULT:   CHECK 1. Auction contract has 13 ETH");
console.log("RESULT:   CHECK 3. Bidder #2 balance increases by 50 ETH");
console.log("RESULT: ");

console.log("RESULT: --------------------------------------------------------------------------------------");
console.log("RESULT: Test 3.3 - Owner calls beneficiaryRecoverFunds() when auction recovery period is active - successful");
var recoveryStartTime = betterAuction.auctionStart().plus(betterAuction.recoveryAfterPeriod());
var recoveryStartDate = new Date(recoveryStartTime * 1000);
console.log("RESULT: Waiting until recovery period is active at " + recoveryStartTime + " " + recoveryStartDate + " currentDate=" + new Date());
while ((new Date()).getTime() < recoveryStartDate.getTime()) {
}
console.log("RESULT: Waited until recovery period is active at " + recoveryStartTime + " " + recoveryStartDate + " currentDate=" + new Date());
var betterAuction33Tx = betterAuction.beneficiaryRecoverFunds({from: ownerAccount, value: 0, gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("betterAuction33Tx", betterAuction33Tx);
printBalances();
printContractDynamicDetails();
if (gasEqualsGasUsed(betterAuction33Tx)) {
  console.log("RESULT: FAIL Test 3.3 - Owner calls beneficiaryRecoverFunds() when auction recovery period is active - successful");
} else {
  console.log("RESULT: PASS Test 3.3 - Owner calls beneficiaryRecoverFunds() when auction recovery period is active - successful");
}
console.log("RESULT:   CHECK 1. Auction contract has 0 ETH");
console.log("RESULT:   CHECK 2. Owner balance is increased by 13 ETH");
console.log("RESULT: ");

EOF
grep "RESULT: " $TEST1OUTPUT | sed "s/RESULT: //" > $TEST1RESULTS
cat $TEST1RESULTS
