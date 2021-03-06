/*
This creates a Democratic Autonomous Organization. Membership is based
on ownership of custom tokens, which are used to vote on proposals.

This contract is intended for educational purposes, you are fully responsible
for compliance with present or future regulations of finance, communications
and the universal rights of digital beings.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <http://unlicense.org>

*/

import "./Crowdfunding.sol";
import "./ManagedAccount.sol";

contract DAOInterface {

    // Contract Variables and events
    Proposal[] public proposals;
    uint public numProposals; // TODO needed?

    uint public rewards;

    address public serviceProvider;
    address[] public allowedRecipients;


    //only used for splits, give DAOs without a balance the privilige to access their share of the rewards
    mapping (address => uint) public rewardRights;
    uint public totalRewardRights;
    uint totalWeiSpendInSplits;


    mapping (address => uint) public payedOut;
    // account used to manage the rewards which are to be distributed to the Token holders seperately, so they don't appear in `this.balance`
    ManagedAccount public rewardAccount;

    // deposit in Ether to be paid for each proposal
    uint public proposalDeposit;

    // contract which is able to create a new DAO (with the same code as this one), used for splits
    DAO_Creator public daoCreator;

    struct Proposal {
        // The address where the `amount` will go to if the proposal is accepted.
        address recipient;
        // The amount to transfer to `recipient` if the proposal is accepted.
        uint amount;
        // A plain text description of the proposal
        string description;
        // a Unix timestamp, denoting the end of the voting period
        uint votingDeadline;
        // True if the proposal is open for voting, false if it has already been voted for/against
        bool openToVote;
        // True if the porposal has been voted for, False if voted against
        bool proposalPassed;
        uint numberOfVotes; // TODO is this needed?
        // A hash to check validity of a proposal. Equal to sha3(_recipient, _amount, _transactionBytecode)
        bytes32 proposalHash;
        // The deposit in ether the creator puts in the proposal. Is taken as the msg.value of a newProposal call
        uint proposalDeposit;
        // True if this proposal is to assign a new service provider
        bool newServiceProvider;
        // Split data
        SplitData[] splitData;
        // Array holding all votes that have taken place on the proposal
        Vote[] votes;
        // Simple mapping to check if a shareholder has already cast a vote
        mapping (address => bool) voted;
        // Address of the shareholder who created the proposal
        address creator;
    }

    struct SplitData {
        // Used only in the case of a newServiceProvider proposal. Is the balance of the current DAO minus the deposit.
        uint splitBalance;
        // Used only in the case of a newServiceProvider proposal. Is the accumulated total wei received in the DAO.
        uint totalWeiReceived;
        // Used only in the case of a newServiceProvider proposal. Is the amount of wei the DAO has invested.
        uint investedWei;
        // Used only in the case of a newServiceProvider porposal. Represents the total amount of token in existenct at the time of split.
        uint totalSupply;
        // Used only in the case of a newServiceProvider porposal. Represents the new DAO contract.
        DAO newDAO;
    }

    struct Vote {
        // True for 'yay', False for 'nay'
        bool inSupport;
        // The address of the voter
        address voter;
    }

    modifier onlyShareholders {}

    /// @dev Constructor setting the default service provider and the address for the contract able to create another DAO
    /// @param _defaultServiceProvider The default service provider
    /// @param _daoCreator The contract able to (re)create this DAO
    //  function DAO(address _defaultServiceProvider, DAO_Creator _daoCreator);  // its commented out only because the constructor can not be overloaded

    /// @notice `msg.sender` creates a proposal to send `_amount` Wei to `_recipient` with the transaction data `_transactionBytecode`. (If this is true: `_newServiceProvider`, then this is a proposal the set `_recipient` as the new service provider)
    /// @param _recipient The address of the recipient of the proposed transaction
    /// @param _amount The amount of Wei to be sent with the proposed transaction
    /// @param _description A string describing the proposal
    /// @param _transactionBytecode The data of the proposed transaction
    /// @param _newServiceProvider A bool defining whether this proposal is about a new service provider or not
    /// @return The proposal ID. Needed for voting on the proposal
    function newProposal(address _recipient, uint _amount, string _description, bytes _transactionBytecode, bool _newServiceProvider) onlyShareholders returns (uint _proposalID);

    /// @notice Check that the proposal with the ID `_proposalID` matches a transaction which sends `_amount` with this data: `_transactionBytecode` to `_recipient`
    /// @param _proposalID The proposal ID
    /// @param _recipient The recipient of the proposed transaction
    /// @param _amount The amount of Wei to be sent with the proposed transaction
    /// @param _transactionBytecode The data of the proposed transaction
    /// @return Whether the proposal ID matches the transaction data or not
    function checkProposalCode(uint _proposalID, address _recipient, uint _amount, bytes _transactionBytecode) constant returns (bool _codeChecksOut);

    /// @notice Vote on proposal `_proposalID` with `_supportsProposal`
    /// @param _proposalID The proposal ID
    /// @param _supportsProposal Yes/No - support of the proposal
    /// @return The proposal ID.
    function vote(uint _proposalID, bool _supportsProposal) onlyShareholders returns (uint _voteID);

    /// @notice Checks whether proposal `_proposalID` with transaction data `_transactionBytecode` has been voted for or rejected, and executes the transaction in the case it has been voted for.
    /// @param _proposalID The proposal ID
    /// @param _transactionBytecode The data of the proposed transaction // TODO is this needed
    /// @return Whether the proposed transaction has been executed or not
    function executeProposal(uint _proposalID, bytes _transactionBytecode) returns (bool _success);

    /// @notice ATTENTION! I confirm to move my remaining funds to a new DAO with `_newServiceProvider` as the new service provider, as has been proposed in proposal `_proposalID`. This will burn my tokens. This can not be undone and will split the DAO into two DAO's, with two underlying tokens.
    /// @param _proposalID The proposal ID
    /// @param _newServiceProvider The new service provider of the new DAO
    /// @dev This function, when called for the first time for this proposal, will create a new DAO and send the portion of the remaining funds which can be attributed to the sender to the new DAO. It will also burn the tokens of the sender.
    function confirmNewServiceProvider(uint _proposalID, address _newServiceProvider);

    /// @notice add new possible recipient `_recipient` for transactions from the DAO (through proposals)
    /// @param _recipient New recipient address
    /// @dev Can only be called by the current service provider
    function addAllowedAddress(address _recipient) external;

    /// @notice change the deposit needed to make a proposal to `_proposalDeposit`
    /// @param _proposalDeposit New proposal deposit
    function changeProposalDeposit(uint _proposalDeposit) external;

    /// @notice get my share of the reward which has been send to `rewardAccount`
    function getMyReward() external;


    event ProposalAdded(uint proposalID, address recipient, uint amount, string description);
    event Voted(uint proposalID, bool position, address indexed voter);
    event ProposalTallied(uint proposalID, bool result, uint quorum, bool active);
    event NewServiceProvider(address _newServiceProvider);
    event AllowedRecipientAdded(address indexed _recipient);
}

// The DAO contract itself
contract DAO is DAOInterface, Token, Crowdfunding {

    // modifier that allows only shareholders to vote and create new proposals
    modifier onlyShareholders {
        if (balanceOf(msg.sender) == 0) throw;
            _
    }


    function getReward() returns(bool) {
        rewards += msg.value;
        return true;
    }

    function DAO(address _defaultServiceProvider, DAO_Creator _daoCreator, uint _minValue, uint _closingTime) Crowdfunding(_minValue, _closingTime) {
        serviceProvider = _defaultServiceProvider;
        daoCreator = _daoCreator;
        proposalDeposit = 20 ether;
        rewardAccount = new ManagedAccount(address(this));
        if (address(rewardAccount) == 0) throw;
    }


    function newProposal(address _recipient, uint _amount, string _description, bytes _transactionBytecode, bool _newServiceProvider) onlyShareholders returns (uint _proposalID) {
        // check sanity
        if (_newServiceProvider && (_amount != 0 || _transactionBytecode.length != 0 || _recipient == serviceProvider)) {
            throw;
        }
        else if (!isRecipientAllowed(_recipient)) throw;

        if (!funded || now < closingTime || msg.value < proposalDeposit) throw;

        _proposalID = proposals.length++;
        Proposal p = proposals[_proposalID];
        p.recipient = _recipient;
        p.amount = _amount;
        p.description = _description;
        p.proposalHash = sha3(_recipient, _amount, _transactionBytecode);
        p.votingDeadline = now + debatingPeriod(_newServiceProvider, _amount);
        p.openToVote = true;
        //p.proposalPassed = false; // that's default
        //p.numberOfVotes = 0;
        p.newServiceProvider = _newServiceProvider;
        if (_newServiceProvider)
            p.splitData.length++;
        p.creator = msg.sender;
        p.proposalDeposit = msg.value;
        ProposalAdded(_proposalID, _recipient, _amount, _description);
        numProposals = _proposalID + 1;
    }


    function checkProposalCode(uint _proposalID, address _recipient, uint _amount, bytes _transactionBytecode) constant returns (bool _codeChecksOut) {
        Proposal p = proposals[_proposalID];
        return p.proposalHash == sha3(_recipient, _amount, _transactionBytecode);
    }


    function vote(uint _proposalID, bool _supportsProposal) onlyShareholders returns (uint _voteID) {
        Proposal p = proposals[_proposalID];
        if (p.voted[msg.sender] == true) throw;
        if (now >= p.votingDeadline) throw;

        _voteID = p.votes.length++;
        p.votes[_voteID] = Vote({inSupport: _supportsProposal, voter: msg.sender});
        p.voted[msg.sender] = true;
        p.numberOfVotes = _voteID + 1;
        Voted(_proposalID, _supportsProposal, msg.sender);
    }


    function executeProposal(uint _proposalID, bytes _transactionBytecode) returns (bool _success) {
        Proposal p = proposals[_proposalID];
        // Check if the proposal can be executed
        if (now < p.votingDeadline  // has the voting deadline arrived?
            || !p.openToVote        // has it been already executed?
            || p.newServiceProvider // new service provider proposal get confirmed not executed
            || p.proposalHash != sha3(p.recipient, p.amount, _transactionBytecode)) // Does the transaction code match the proposal?
            throw;

        // tally the votes
        uint yea = 0;
        uint nay = 0;

        for (uint i = 0; i < p.votes.length; ++i) {
            Vote v = p.votes[i];
            uint voteWeight = balanceOf(v.voter);
            if (v.inSupport)
                yea += voteWeight;
            else
                nay += voteWeight;
        }
        uint quorum = yea + nay;

        // execute result
        if (quorum >= minQuorum(p.amount) && yea > nay) {
            if (!p.creator.send(p.proposalDeposit)) throw;
            if (!p.recipient.call.value(p.amount)(_transactionBytecode)) throw;  // Without this throw, the creator of the proposal can repeat this, and get so much fund.
            p.openToVote = false;
            p.proposalPassed = true;
            _success = true;
        } else if (quorum >= minQuorum(p.amount) && nay >= yea) {
            p.openToVote = false;
            p.proposalPassed = false;
            if (!p.creator.send(p.proposalDeposit)) throw;
        }

        // fire event
        ProposalTallied(_proposalID, _success, quorum, p.openToVote);
    }


    function confirmNewServiceProvider(uint _proposalID, address _newServiceProvider) onlyShareholders {
        Proposal p = proposals[_proposalID];
        // sanity check
        if (now < p.votingDeadline  // has the voting deadline arrived?
            || now > p.votingDeadline + 41 days
            || p.proposalHash != sha3(_newServiceProvider, 0, 0) // Does the transaction code match the proposal?
            || !p.newServiceProvider // is it a new service provider proposal
            || p.recipient != _newServiceProvider) //(not needed)
            throw;

        // if not already happened, create new DAO and store the current split data
        if (address(p.splitData[0].newDAO) == 0) {
            p.splitData[0].newDAO = createNewDAO(_newServiceProvider);
            if (address(p.splitData[0].newDAO) == 0) throw; // Call depth limit reached, etc.
            if (this.balance < p.proposalDeposit) throw;
            p.splitData[0].splitBalance = this.balance - p.proposalDeposit;
            p.splitData[0].totalWeiReceived = weiRaised + rewards;
            p.splitData[0].totalSupply = totalSupply;
            uint spentAndStored = rewardAccount.accumulatedInput() + p.splitData[0].splitBalance + totalWeiSpendInSplits;
            if (spentAndStored >= p.splitData[0].totalWeiReceived)
                p.splitData[0].investedWei = 0;
            else
                p.splitData[0].investedWei = p.splitData[0].totalWeiReceived - spentAndStored;
        }

        // refund proposal deposit
        if (msg.sender == p.creator && p.proposalDeposit > 0 && p.creator.send(p.proposalDeposit)) {
            p.proposalDeposit = 0;
        }

        // move funds and assign new Tokens
        uint fundsToBeMoved = (balances[msg.sender] * p.splitData[0].splitBalance) / p.splitData[0].totalSupply; // totalSupply represents the sum of unsplit tokens
        if (p.splitData[0].newDAO.buyTokenProxy.value(fundsToBeMoved).gas(52225)(msg.sender) == false) throw; // TODO test gas costs
        totalWeiSpendInSplits += fundsToBeMoved;

        // assign reward rights to new DAO
        uint rewardRight = (balances[msg.sender] * p.splitData[0].investedWei) / p.splitData[0].totalWeiReceived;
        rewardRights[address(p.splitData[0].newDAO)] += rewardRight;
        totalRewardRights += rewardRight;

        // burn tokens
        Transfer(msg.sender, 0, balances[msg.sender]);
        totalSupply -= balances[msg.sender];
        balances[msg.sender] = 0;
    }


    function getMyReward() external {
        uint total = totalSupply + totalRewardRights;
        uint myReward = (balanceOf(msg.sender) + rewardRights[msg.sender]) * rewardAccount.accumulatedInput() / total - payedOut[msg.sender]; // DANGER - 1024 stackdepth
        if (!rewardAccount.payOut(msg.sender, myReward)) throw;
        payedOut[msg.sender] += myReward;
    }


    function transfer(address _to, uint256 _value) returns (bool success) {
        return transferFrom(msg.sender, _to, _value);
    }


    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        uint transferPayedOut = payedOut[_from] * _value / balanceOf(_from);
        if (transferPayedOut > payedOut[_from]) throw;
        if (super.transferFrom(_from, _to, _value)){
            payedOut[_from] -= transferPayedOut;
            payedOut[_to] += transferPayedOut;
            return true;
        }
        else
            return false;
    }

    function changeProposalDeposit(uint _proposalDeposit) external {
        if (msg.sender != address(this) || _proposalDeposit > this.balance / 10) throw;
        proposalDeposit = _proposalDeposit;
    }


    function addAllowedAddress(address _recipient) external {
        if (msg.sender != serviceProvider) throw;
        allowedRecipients.push(_recipient);
    }


    function isRecipientAllowed(address _recipient) internal returns (bool _isAllowed) {
        if (_recipient == serviceProvider || _recipient == address(rewardAccount) || _recipient == address(this))
            return true;
        for (uint i = 0; i < allowedRecipients.length; ++i) {
            if (_recipient == allowedRecipients[i])
                return true;
        }
        return false;
    }


    function debatingPeriod(bool _newServiceProvider, uint _value) internal returns (uint _debatingPeriod) {
        if (_newServiceProvider)
            return 10 days;
        else
            return 2 weeks + (_value * 31 days) / (totalSupply + rewards);    // minimum of two weeks and maximum of one month and two weeks (depending on the value to be transferred)
    }


    function minQuorum(uint _value) internal returns (uint _minQuorum) {
        return totalSupply / 5 + _value / 3;     // minimum of 20% and maximum of 53.33% (depending on the value to be transferred)
    }


    function createNewDAO(address _newServiceProvider) internal returns (DAO _newDAO) {
        NewServiceProvider(_newServiceProvider);
        return daoCreator.createDAO(_newServiceProvider, 0, now + 42 days);
    }
}

contract DAO_Creator {
    function createDAO(address _defaultServiceProvider, uint _minValue, uint _closingTime) returns (DAO _newDAO) {
        return new DAO(_defaultServiceProvider, DAO_Creator(this), _minValue, _closingTime);
    }
}
