# Audit Of The BetterAuction Smart Contract

* Amir requested for an audit of an auction contract 
* Steve wrote the inital smart contract
* There were several cycles of my review, my recommendations, Steve's changes, Amir and Steve's changes to functionality
* I wrote the test scripts with the main script in [test/00_test1.sh] and the generated results in [test/test1results.txt]
* Following is a check on the finalised code


## Comments On The Source Code

My comments in the following code are marked in the lines beginning with `//CHECK: `

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
        if (auctionClosed) throw;
        auctionClosed = true;
        AuctionClosed(highestBidder, highestBid);
        if (!beneficiary.send(highestBid)) throw;
    }
 
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