# Security Audit Of The BetterAuction Smart Contract

Document status: work in progress

## Background And History
* Mar 20 2017 - Amir requested for an audit of an auction contract 
* Mar 21 2017 - Steve wrote the initial smart contract
* Mar 21 to Apr 5 2017 - There were several iterative cycles of:
  * My review and recommended code changes, including:
    * Moving magic numbers into constants
    * Moving some logic into modifiers
    * Code and comment formatting
    * Logic consistency
  * Steve's update to the source code
  * Amir and Steve's changes to functionality
  * The versions of code follow:
    * [Steve's initial version](https://gist.github.com/slavik0329/857458d42d3c57d7ef2c1e686c2c650d)
    * [Lots of changes from my recommendation](https://gist.github.com/slavik0329/c61aed6596bde40a3c382bb3a3dff0d1)
    * [SimpleAuction renamed to BetterAuction](https://gist.github.com/slavik0329/58f1944d61d00575476ee47937c3486c)
    * [Adding missing event log](https://gist.github.com/slavik0329/c8523d41e05ff69907e42811be8cb1a2)
    * [Check of 0x0 beneficiary in constructor, throw for bids with 0 values](https://gist.github.com/slavik0329/a46faaddd029e4adf5f8b29d969a9bbf)
    * [Removing unnecessary +=, tidy](https://gist.github.com/slavik0329/e91516a12d9229fc0828dbda6a76a08e)
    * [Update 0.4.0 to 0.4.8, removing unnecessary +=](https://gist.github.com/slavik0329/66c34a07ea9ed075d99cb2f8648a4ddf)
    * [Addition of header comment](https://github.com/slavik0329/BetterAuction/blob/1c0161fbb288dcdb19906c85538e2a6d5861f82b/betterauction.sol)
* Apr 11 2017 I completed the test scripts with the main script in [test/00_test1.sh](test/00_test1.sh) and the generated results in [test/test1results.txt](test/test1results.txt)
* Apr 16 2017 I completed this security audit report

<br />

## Security Overview Of The BetterAuction
* The smart contract has been kept relatively simple
* The code has been tested for the normal use cases, and around the boundary use cases
* The testing has been done using geth 1.5.9-stable and solc 0.4.9+commit.364da425.Darwin.appleclang instead of one of the testing frameworks and JavaScript VMs to simulate the live environment as closely as possible
* Only the `send(...)` call has been used instead of `call.value()()` for transferring funds with limited gas to minimise reentrancy attacks
* The `send(...)` calls are the last statements in the control flow to prevent the hijacking of the control flow
* The return status from `send(...)` calls are all checked and invalid results will **throw** 
* Funds are transferred from this auction contract by account holds "pulling" their funds
  * Only the beneficiary can call beneficiaryRecoverFunds(...) to receive the beneficiary's funds
  * Only the beneficiary can call beneficiaryCloseAuction(...) to receive the winning bidder's funds
  * Non-highest bidders retrieve their funds by calling nonHighestBidderRefund(...)
* There is no logic with potential division by zero errors
* There is no logic with potential overflow errors, as the numbers added are taken from the value of ethers sent in each transaction, and this value is validated as part of the sent transactions
  * [ ] Check this statement that the VM / Ethereum system prevents false `msg.value` being sent
* There is no logic with potential underflow errors, as the numbers are taken from the actual value of ethers sent in each transaction, and this value is validated as part of the sent transactions
* Function and event names are differentiated by case - function names begin with a lowercase character and event names begin with an uppercase character

<br />

## Comments On The Source Code

My comments in the following code are marked in the lines beginning with `//CHECK: ` and `//NOTE: `

```javascript
// ------------------------------------------------------------------------
// BetterAuction
//
// Decentralised open auction on the Ethereum blockchain
//
// Note: When a bidder is outbid they can top up their bid by sending more
// ether to the contract or they can get their outbid funds back by calling 
// nonHighestBidderRefund directly or by simply sending exactly 0.0001 ETH  
// to the contract.
//
// (c) Steve Dakh & BokkyPooBah 2017.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
// ------------------------------------------------------------------------
pragma solidity ^0.4.8;

contract BetterAuction {
    // Auction beneficiary
    address public beneficiary;
    // Auction start time, seconds from 1970-01-01
    uint256 public auctionStart;
    // Auction bidding period in seconds, relative to auctionStart
    uint256 public biddingPeriod;
    // Period after auction ends when the beneficiary can withdraw all funds, relative to auctionStart
    uint256 public recoveryAfterPeriod;
    // User sends this amount to the contract to withdraw funds, 0.0001 ETH
    uint256 public constant WITHDRAWAL_TRIGGER_AMOUNT = 100000000000000;
    // Address of the highest bidder
    address public highestBidder;
    // Highest bid amount
    uint256 public highestBid;
    // Allowed withdrawals of previous bids
    mapping(address => uint256) pendingReturns;
    // Set to true at the end, disallows any change
    bool auctionClosed;
 
    // CHECK: Ok. Used in beneficiaryRecoverFunds(...) and beneficiaryCloseAuction(...)
    modifier isBeneficiary {
        if (msg.sender != beneficiary) throw;
        _;
    }
 
    // CHECK: Ok. Used in bidderPlaceBid(...)
    modifier isAuctionActive {
        if (now < auctionStart || now > (auctionStart + biddingPeriod)) throw;
        _;
    }
 
    // CHECK: Ok. Used in beneficiaryCloseAuction(...)
    modifier isAuctionEnded {
        if (now < (auctionStart + biddingPeriod)) throw;
        _;
    }
 
    // CHECK: Ok. Used in beneficiaryRecoverFunds(...)
    modifier isRecoveryActive {
        if (now < (auctionStart + recoveryAfterPeriod)) throw;
        _;
    }

    // CHECK: Ok
    event HighestBidIncreased(address bidder, uint256 amount);
    // CHECK: Ok
    event AuctionClosed(address winner, uint256 amount);
    
    // CHECK: Ok. Only called by (normally) the beneficiary
    // Auction starts at deployment, runs for _biddingPeriod (seconds from 
    // auction start), and funds can be recovered after _recoverPeriod 
    // (seconds from auction start)
    function BetterAuction(
        address _beneficiary,
        uint256 _biddingPeriod,
        uint256 _recoveryAfterPeriod
    ) {
        if (_beneficiary == 0) throw;
        beneficiary = _beneficiary;
        auctionStart = now;
        if (_biddingPeriod > _recoveryAfterPeriod) throw;
        biddingPeriod = _biddingPeriod;
        recoveryAfterPeriod = _recoveryAfterPeriod;
    }
 
    // CHECK: Ok. Constant function for information only and returning variables set by (normally) the beneficiary
    // Users want to know when the auction ends, seconds from 1970-01-01
    function auctionEndTime() constant returns (uint256) {
        return auctionStart + biddingPeriod;
    }

    // CHECK: Ok. Constant function for information only
    // Users want to know theirs or someones current bid
    function getBid(address _address) constant returns (uint256) {
        if (_address == highestBidder) {
            return highestBid;
        } else {
            return pendingReturns[_address];
        }
    }

    // Update highest bid or top up previous bid
    function bidderUpdateBid() internal {
        if (msg.sender == highestBidder) {
            highestBid += msg.value;
            HighestBidIncreased(msg.sender, highestBid);
        } else if (pendingReturns[msg.sender] + msg.value > highestBid) {
            var amount = pendingReturns[msg.sender] + msg.value;
            pendingReturns[msg.sender] = 0;
            // Save previous highest bidders funds
            pendingReturns[highestBidder] = highestBid;
            // Record the highest bid
            highestBid = amount;
            highestBidder = msg.sender;
            HighestBidIncreased(msg.sender, amount);
        } else {
            throw;
        }
    }
 
    // Bidders can only place bid while the auction is active 
    function bidderPlaceBid() isAuctionActive payable {
        if ((pendingReturns[msg.sender] > 0 || msg.sender == highestBidder) && msg.value > 0) {
            bidderUpdateBid();
        } else {
            // Reject bids below the highest bid
            if (msg.value <= highestBid) throw;
            // Save previous highest bidders funds
            if (highestBidder != 0) {
                pendingReturns[highestBidder] = highestBid;
            }
            // Record the highest bid
            highestBidder = msg.sender;
            highestBid = msg.value;
            HighestBidIncreased(msg.sender, msg.value);
        }
    }

    // CHECK: Ok. Can only be called by (normally) the beneficiary when recovery is active
    // Recover any ethers accidentally sent to contract
    function beneficiaryRecoverFunds() isBeneficiary isRecoveryActive {
        // CHECK: Ok. The safer send(...) function with enough gas to log an event is used instead of call.value()() 
        // CHECK: Ok. A false return value will result in a throw
        if (!beneficiary.send(this.balance)) throw;
    }
 
    // NOTE: The non-highest bidder may call this function after the beneficiary has recovered the funds in the recovery
    //       period. The ether balance of this contract will be 0 and the send(...) will fail.
    // NOTE: This function can be called at any time, but the non-highest bidder needs to already be stored in the 
    //       pendingReturns data structure.
    // Withdraw a bid that was overbid.
    function nonHighestBidderRefund() payable {
        var amount = pendingReturns[msg.sender];
        // CHECK: Ok. The account's balance is checked before trying to send back the refund
        if (amount > 0) {
            pendingReturns[msg.sender] = 0;
            // CHECK: Ok. The safer send(...) function with enough gas to log an event is used instead of call.value()()
            // CHECK: Ok. A false return value will result in a throw
            // CHECK: Ok. The trigger amount is sent back with the amounts contributed
            if (!msg.sender.send(amount + msg.value)) throw;
        } else {
            throw;
        }
    }
 
    // Close the auction and receive the highest bid amount
    function beneficiaryCloseAuction() isBeneficiary isAuctionEnded {
        // CHECK: Can only be called once
        if (auctionClosed) throw;
        auctionClosed = true;
        AuctionClosed(highestBidder, highestBid);
        // CHECK: Ok. The safer send(...) function with enough gas to log an event is used instead of call.value()()
        if (!beneficiary.send(highestBid)) throw;
    }
 
    // CHECK: Ok. The bidder can only place their bids when the auction is active.
    // CHECK: Ok. Non-highest bidders can retrieve their funds by sending the trigger amount
    // Bidders send their bids to the contract. If this is the trigger amount
    // allow non-highest bidders to withdraw their funds
    function () payable {
        if (msg.value == WITHDRAWAL_TRIGGER_AMOUNT) {
            nonHighestBidderRefund();
        } else {
            bidderPlaceBid();
        }
    }
}
```

<br />

## Other Note

* While the smart contract logic has been checked, there are still possibilities of errors in Solidity compilation, the execution of the VM code, or even in the Ethereum blockchain security, that could compromise the security of this contract.
  * For example see [Security Alert – Solidity – Variables can be overwritten in storage](https://blog.ethereum.org/2016/11/01/security-alert-solidity-variables-can-overwritten-storage/)
* There is the possibility that this miner mining this transaction can skew the 'now' time. This is not so important as it can result in a bidder being allowed to bid after the auction is closed, or a bidders valid bid being rejected due to the skew in the time stamp. However, the skewing of the timestamp should only be valid for -14s to +14s as the timestamp being out of this range would result in the block being invalid if it has to fit between the timestamps of the previous and next miners (out of probability).

References:

* [Ethereum Contract Security Techniques and Tips](https://github.com/ConsenSys/smart-contract-best-practices)


BokkyPooBah / Bok Consulting Pty Ltd 2017