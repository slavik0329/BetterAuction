# Security Audit Of The BetterAuction Smart Contract

The BetterAuction smart contract allows the owner (beneficiary) to conduct an auction of a digital (or not) asset on the Ethereum blockchain. Bidders can send ethers to the smart contract and the highest bid is locked in the smart contract. Non-highest bids can deposit further ethers or withdraw their deposit ethers by sending a withdrawal trigger amount. At the end of the auction period, the beneficiary closes the auction to receive the highest bidder's ethers. The other non-highest bidders can still withdraw their bid amounts. After a period, the beneficiary can recover all funds and send the appropriate amounts to the non-highest bidders if these individuals have not claimed their non-highest bids.

<br />

<hr />

**Table of contents**
* [Background And History](#background-and-history)
* [Security Overview Of The BetterAuction](#security-overview-of-the-betterauction)
  * [Other Notes](#other-notes)
* [Comments On The Source Code](#comments-on-the-source-code)
* [References](#references)

<br />

<hr />

## Background And History
* Mar 20 2017 Amir requested for an audit of an auction contract 
* The versions of iterative code changes follow:
  * Mar 21 2017 [Steve's initial SimpleAuction](https://gist.github.com/slavik0329/857458d42d3c57d7ef2c1e686c2c650d)
  * Mar 21 2017 [Lots of changes from Bok Consulting's recommendation, removing magic numbers, modifiers for conditions, code and comment formatting](https://gist.github.com/slavik0329/c61aed6596bde40a3c382bb3a3dff0d1)
  * Mar 22 2017 [SimpleAuction renamed to BetterAuction, functions renamed, bid update logic](https://gist.github.com/slavik0329/58f1944d61d00575476ee47937c3486c)
  * Mar 22 2017 [Adding missing event log](https://gist.github.com/slavik0329/c8523d41e05ff69907e42811be8cb1a2)
  * Mar 29 2017 [Check of 0x0 beneficiary in constructor, throw for bids with 0 values](https://gist.github.com/slavik0329/a46faaddd029e4adf5f8b29d969a9bbf)
  * Apr 03 2017 [Removing unnecessary +=, tidy](https://gist.github.com/slavik0329/e91516a12d9229fc0828dbda6a76a08e)
  * Apr 03 2017 [Update 0.4.0 to 0.4.8, removing unnecessary +=](https://gist.github.com/slavik0329/66c34a07ea9ed075d99cb2f8648a4ddf)
  * Apr 05 2017 [Addition of header comment](https://github.com/slavik0329/BetterAuction/blob/1c0161fbb288dcdb19906c85538e2a6d5861f82b/betterauction.sol)
* Apr 11 2017 Bok Consulting completed the test script [test/01_test1.sh](test/01_test1.sh) with the generated result documented in [test/test1results.txt](test/test1results.txt)
* Apr 16 2017 Bok Consulting completed this security audit report

<br />

<hr />

## Security Overview Of The BetterAuction
* [x] The smart contract has been kept relatively simple
* [x] The code has been tested for the normal use cases, and around the boundary cases
* [x] The testing has been done using geth 1.5.9-stable and solc 0.4.9+commit.364da425.Darwin.appleclang instead of one of the testing frameworks and JavaScript VMs to simulate the live environment as closely as possible
* [x] Only the `send(...)` call has been used instead of `call.value()()` for transferring funds with limited gas to minimise reentrancy attacks
* [x] The `send(...)` calls are the last statements in the control flow to prevent the hijacking of the control flow
* [x] The return status from `send(...)` calls are all checked and invalid results will **throw** 
* [x] Funds are transferred from this auction contract by account holders "pulling" their funds
  * [x] Only the beneficiary can call `beneficiaryRecoverFunds(...)` to receive the beneficiary's funds
  * [x] Only the beneficiary can call `beneficiaryCloseAuction(...)` to receive the winning bidder's funds
  * [x] Non-highest bidders retrieve their funds by calling `nonHighestBidderRefund(...)`
* [x] There is no logic with potential division by zero errors
* [x] All numbers used are uint256, reducting the risk of errors from type conversions
* [x] There is no logic with potential overflow errors, as the numbers added are taken from the value of ethers sent in each transaction, this value is validated as part of the sent transactions and these values are small compared to the uint256 limits
* [x] There is no logic with potential underflow errors as there are no subtractions used in this code
* [x] Function and event names are differentiated by case - function names begin with a lowercase character and event names begin with an uppercase character

### Other Notes
* While the BetterAuction Solidity code logic has been audited, there are small possibilities of errors that could compromise the security of this contract. This includes errors in the Solidity to bytecode compilation, errors in the execution of the VM code, or security failures in the Ethereum blockchain
  * For example see [Security Alert – Solidity – Variables can be overwritten in storage](https://blog.ethereum.org/2016/11/01/security-alert-solidity-variables-can-overwritten-storage/)
* There is the possibility of a miner mining a block and skewing the `now` timestamp. This can result valid bids being rejected and invalid bids being accepted, and this would be most relevant at the end of the auction period
* If possible, run a [bug bounty program](https://github.com/ConsenSys/smart-contract-best-practices#bug-bounty-programs) on this contract code
* Some of the recommended code changes, the testing and the security audit were conducted by Bok Consulting, and this is a potential conflict of interest

<br />

<hr />

## Comments On The Source Code

My comments in the following code are marked in the lines beginning with `// NOTE: `

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
 
    // NOTE: 1. Used in beneficiaryRecoverFunds(...) and beneficiaryCloseAuction(...)
    //          to only allow the beneficiary to execute these functions
    //
    modifier isBeneficiary {
        if (msg.sender != beneficiary) throw;
        _;
    }
 
    // NOTE: 1. Used in bidderPlaceBid(...) to allow bids to be placed
    //          when the auction is active
    //
    modifier isAuctionActive {
        if (now < auctionStart || now > (auctionStart + biddingPeriod)) throw;
        _;
    }
 
    // NOTE: 1. Used in beneficiaryCloseAuction(...) to allow the beneficiary to
    //          close the auction after the auction has ended
    //
    modifier isAuctionEnded {
        if (now < (auctionStart + biddingPeriod)) throw;
        _;
    }
 
    // NOTE: 1. Used in beneficiaryRecoverFunds(...) to allow the beneficiary to
    //          retrieve all remaining funds
    //
    modifier isRecoveryActive {
        if (now < (auctionStart + recoveryAfterPeriod)) throw;
        _;
    }

    // NOTE: 1. Event starts with an uppercase character
    //
    event HighestBidIncreased(address bidder, uint256 amount);
    // NOTE: 1. Event starts with an uppercase character
    //
    event AuctionClosed(address winner, uint256 amount);
    
    // NOTE: 1. Constructor function that can only be called by (normally) the beneficiary
    // NOTE: 2. There is a check for 0x0 addresses
    // NOTE: 3. There is a check that the recovery period can only start after the auction
    //          period is over
    //
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
 
    // NOTE: 1. Constant function for information only
    // NOTE: 2. Can be called by anyone
    // NOTE: 3. Returns values from variables set by the beneficiary
    //
    // Users want to know when the auction ends, seconds from 1970-01-01
    function auctionEndTime() constant returns (uint256) {
        return auctionStart + biddingPeriod;
    }

    // NOTE: 1. Constant function for information only
    // NOTE: 2. Can be called by anyone
    // NOTE: 3. Returns information on the bidder and other bidder's information
    //
    // Users want to know theirs or someones current bid
    function getBid(address _address) constant returns (uint256) {
        if (_address == highestBidder) {
            return highestBid;
        } else {
            return pendingReturns[_address];
        }
    }

    // NOTE: 1. Highest bidder can top up their bid
    // NOTE: 2. Non-highest bidder can top up their bid if the new total exceeds the 
    //          highest bid
    // NOTE: 3. The new highest bid information is stored in the highestBid and highestBidder
    //          variables
    // NOTE: 4. The old highest bid information is stored in the pendingReturns mapping
    // NOTE: 5. Bid updates that don't result in a new highest bid results in a throw
    //
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

    // NOTE: 1. Highest bidder and non-highest bidder can top up their bids
    // NOTE: 2. New bids below the highest bid are rejected with a throw
    // NOTE: 3. The old highest bid information is saved in the pendingReturns mapping
    // NOTE: 4. The new highest bid is saved in the highestBid and highestBidder variables
    //
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

    // NOTE: 1. The beneficiary can call this function when recovery is active
    // NOTE: 2. The send(...) function with limited gas is used instead of call.value()()
    // NOTE: 3. The send(...) function is called at the end of the control flow
    // NOTE: 4. The send(...) function status is checked and will throw on errors
    //
    // Recover any ethers accidentally sent to contract
    function beneficiaryRecoverFunds() isBeneficiary isRecoveryActive {
        if (!beneficiary.send(this.balance)) throw;
    }
 
    // NOTE: 1. The non-highest bidder can call this function after they have placed a bid and
    //          their bid is not the highest bid and they have not already withdrawn their funds
    // NOTE: 2. The non-highest bidder may call this function after the beneficiary has 
    //          recovered the funds in the recovery period. The ether balance of this contract 
    //          will be 0 and the send(...) will fail with a throw
    // NOTE: 3. The send(...) function with limited gas is used instead of call.value()()
    // NOTE: 4. The send(...) function is called at the end of the control flow
    // NOTE: 5. The send(...) function status is checked and will throw on errors
    // NOTE: 6. The trigger amount is sent back to the non-highest bidder if the call was
    //          made to the default () function with the trigger amount
    // NOTE: 7. The non-highest bidder can call this function directly without supplying the
    //          trigger amount
    //
    // Withdraw a bid that was overbid.
    function nonHighestBidderRefund() payable {
        var amount = pendingReturns[msg.sender];
        if (amount > 0) {
            pendingReturns[msg.sender] = 0;
            if (!msg.sender.send(amount + msg.value)) throw;
        } else {
            throw;
        }
    }
 
    // NOTE: 1. The auction can only be closed once by the beneficiary
    // NOTE: 2. The auction can only be closed after the auction has ended
    // NOTE: 3. The send(...) function with limited gas is used instead of call.value()()
    // NOTE: 4. The send(...) function is called at the end of the control flow
    // NOTE: 5. The send(...) function status is checked and will throw on errors
    //
    // Close the auction and receive the highest bid amount
    function beneficiaryCloseAuction() isBeneficiary isAuctionEnded {
        if (auctionClosed) throw;
        auctionClosed = true;
        AuctionClosed(highestBidder, highestBid);
        if (!beneficiary.send(highestBid)) throw;
    }
 
    // NOTE: 1. The bidder can only place their bids when the auction is active
    // NOTE: 2. Non-highest bidders can retrieve their funds by sending the trigger amount after
    //          they have placed their bid and their bid is not the highest bid, and the funds 
    //          have not been recovered by the beneficiary after the auction ends and the
    //          recovery period is active
    //
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

<hr />

## References

* [Ethereum Contract Security Techniques and Tips](https://github.com/ConsenSys/smart-contract-best-practices)

<br />

(c) Bok Consulting Pty Ltd - Apr 16 2017