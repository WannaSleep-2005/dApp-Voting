// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Voting {

    struct Candidate {
        uint id;
        string name;
        uint voteCount;
        bool exists;
    }

    address public owner;
    uint public candidatesCount;
    mapping(uint => Candidate) public candidates;
    mapping(address => bool) public hasVoted;

    uint public startTime;
    uint public endTime;
    bool public timingEnabled;

    mapping(address => bool) public isWhitelisted;
    bool public whitelistEnabled;

    event votedEvent(uint indexed _candidateId);
    event CandidateAdded(uint indexed id, string name);
    event CandidateRemoved(uint indexed id, string name);
    event VotingTimeSet(uint startTime, uint endTime);
    event VoterWhitelisted(address indexed voter);
    event VoterRemovedFromWhitelist(address indexed voter);

    modifier onlyOwner() {
        require(msg.sender == owner, "Voting: chi owner moi duoc thuc hien");
        _;
    }

    modifier votingOpen() {
        if (timingEnabled) {
            require(block.timestamp >= startTime, "Voting: chua den thoi gian bo phieu");
            require(block.timestamp <= endTime, "Voting: da het thoi gian bo phieu");
        }
        _;
    }

    modifier onlyWhitelisted() {
        if (whitelistEnabled) {
            require(isWhitelisted[msg.sender], "Voting: ban khong co trong danh sach cu tri");
        }
        _;
    }

    constructor() {
        owner = msg.sender;
        _addCandidate("Nguyen Van An");
        _addCandidate("Tran Thi Bich");
        _addCandidate("Le Van Cuong");
    }

    function _addCandidate(string memory _name) internal {
        candidatesCount++;
        candidates[candidatesCount] = Candidate({
            id: candidatesCount,
            name: _name,
            voteCount: 0,
            exists: true
        });
        emit CandidateAdded(candidatesCount, _name);
    }

    function addCandidate(string memory _name) external onlyOwner {
        require(bytes(_name).length > 0, "Voting: ten ung vien khong duoc rong");
        if (timingEnabled && block.timestamp >= startTime && block.timestamp <= endTime) {
            revert("Voting: khong the them ung vien khi dang trong ky bau cu");
        }
        _addCandidate(_name);
    }

    function removeCandidate(uint _candidateId) external onlyOwner {
        require(_candidateId > 0 && _candidateId <= candidatesCount, "Voting: id ung vien khong hop le");
        require(candidates[_candidateId].exists, "Voting: ung vien da bi xoa truoc do");
        if (timingEnabled && block.timestamp >= startTime && block.timestamp <= endTime) {
            revert("Voting: khong the xoa ung vien khi dang trong ky bau cu");
        }
        string memory removedName = candidates[_candidateId].name;
        candidates[_candidateId].exists = false;
        emit CandidateRemoved(_candidateId, removedName);
    }

    function setVotingTime(uint _startTime, uint _endTime) external onlyOwner {
        require(_startTime < _endTime, "Voting: startTime phai truoc endTime");
        require(_endTime > block.timestamp, "Voting: endTime phai trong tuong lai");
        startTime = _startTime;
        endTime = _endTime;
        timingEnabled = true;
        emit VotingTimeSet(_startTime, _endTime);
    }

    function setTimingEnabled(bool _enabled) external onlyOwner {
        timingEnabled = _enabled;
    }

    function setWhitelistEnabled(bool _enabled) external onlyOwner {
        whitelistEnabled = _enabled;
    }

    function addToWhitelist(address _voter) external onlyOwner {
        require(_voter != address(0), "Voting: dia chi khong hop le");
        isWhitelisted[_voter] = true;
        emit VoterWhitelisted(_voter);
    }

    function addBatchToWhitelist(address[] calldata _voters) external onlyOwner {
        for (uint i = 0; i < _voters.length; i++) {
            require(_voters[i] != address(0), "Voting: dia chi trong mang khong hop le");
            isWhitelisted[_voters[i]] = true;
            emit VoterWhitelisted(_voters[i]);
        }
    }

    function removeFromWhitelist(address _voter) external onlyOwner {
        isWhitelisted[_voter] = false;
        emit VoterRemovedFromWhitelist(_voter);
    }

    function vote(uint _candidateId) external votingOpen onlyWhitelisted {
        require(!hasVoted[msg.sender], "Voting: ban da bo phieu roi");
        require(_candidateId > 0 && _candidateId <= candidatesCount, "Voting: id ung vien khong hop le");
        require(candidates[_candidateId].exists, "Voting: ung vien nay khong ton tai");

        hasVoted[msg.sender] = true;
        candidates[_candidateId].voteCount++;

        emit votedEvent(_candidateId);
    }

    function getVotingStatus() external view returns (string memory) {
        if (!timingEnabled) return "KHONG_GIOI_HAN";
        if (block.timestamp < startTime) return "CHUA_MO";
        if (block.timestamp <= endTime) return "DANG_MO";
        return "DA_KET_THUC";
    }

    function isVotingOpen() external view returns (bool) {
        if (!timingEnabled) return true;
        return (block.timestamp >= startTime && block.timestamp <= endTime);
    }

    function getCandidate(uint _candidateId) external view returns (uint id, string memory name, uint voteCount, bool exists) {
        require(_candidateId > 0 && _candidateId <= candidatesCount, "Voting: id khong hop le");
        Candidate storage c = candidates[_candidateId];
        return (c.id, c.name, c.voteCount, c.exists);
    }

    function getAllCandidates() external view returns (Candidate[] memory) {
        uint activeCount = 0;
        for (uint i = 1; i <= candidatesCount; i++) {
            if (candidates[i].exists) activeCount++;
        }

        Candidate[] memory result = new Candidate[](activeCount);
        uint idx = 0;
        for (uint i = 1; i <= candidatesCount; i++) {
            if (candidates[i].exists) {
                result[idx] = candidates[i];
                idx++;
            }
        }
        return result;
    }

    function getVoteCount(uint _candidateId) external view returns (uint) {
        require(_candidateId > 0 && _candidateId <= candidatesCount, "Voting: id khong hop le");
        require(candidates[_candidateId].exists, "Voting: ung vien khong ton tai");
        return candidates[_candidateId].voteCount;
    }

    function checkHasVoted(address _voter) external view returns (bool) {
        return hasVoted[_voter];
    }

    function getContractInfo() external view returns (address _owner, uint _candidatesCount, bool _timingEnabled, uint _startTime, uint _endTime, bool _whitelistEnabled, string memory _votingStatus) {
        string memory status;
        if (!timingEnabled) status = "KHONG_GIOI_HAN";
        else if (block.timestamp < startTime) status = "CHUA_MO";
        else if (block.timestamp <= endTime) status = "DANG_MO";
        else status = "DA_KET_THUC";

        return (owner, candidatesCount, timingEnabled, startTime, endTime, whitelistEnabled, status);
    }
}