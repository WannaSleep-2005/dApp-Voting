import { expect } from "chai";
import { network } from "hardhat";

describe("Kiểm thử Smart Contract - dApp Voting", function () {
  let voting;
  let owner, voter1, voter2;
  let ethers;

  beforeEach(async function () {
    const connection = await network.connect();
    ethers = connection.ethers;

    [owner, voter1, voter2] = await ethers.getSigners();
    
    const Voting = await ethers.getContractFactory("Voting");
    voting = await Voting.deploy();
  });

  // A. KIỂM THỬ CÁC YÊU CẦU CƠ BẢN (Theo mục 3.4 của đề bài)

  it("1. Kiểm tra contract khởi tạo đúng số lượng ứng cử viên", async function () {
    // Contract của nhóm đang có 5 ứng cử viên trong constructor
    const count = await voting.candidatesCount();
    expect(count).to.equal(5n); 
  });

  it("2. Kiểm tra thông tin của từng ứng cử viên (id, name, voteCount ban đầu = 0)", async function () {
    const candidate1 = await voting.getCandidate(1);
    expect(candidate1.id).to.equal(1n);
    expect(candidate1.name).to.equal("Dinh Manh Duc");
    expect(candidate1.voteCount).to.equal(0n);
    expect(candidate1.exists).to.be.true;
  });

  it("3. Kiểm tra một tài khoản có thể bỏ phiếu thành công và voteCount tăng lên 1", async function () {
    await voting.connect(voter1).vote(1);
    
    // Kiểm tra trạng thái đã vote của tài khoản
    const hasVoted = await voting.checkHasVoted(voter1.address);
    expect(hasVoted).to.be.true;

    // Kiểm tra voteCount của ứng cử viên tăng lên 1
    const candidate = await voting.getCandidate(1);
    expect(candidate.voteCount).to.equal(1n);
  });

  it("4. Kiểm tra từ chối bỏ phiếu cho ứng cử viên không hợp lệ (id không tồn tại)", async function () {
    // Cố tình vote cho ứng cử viên số 99 (không tồn tại)
    await expect(
      voting.connect(voter1).vote(99)
    ).to.be.revertedWith("Voting: id ung vien khong hop le");
  });

  it("5. Kiểm tra từ chối bỏ phiếu hai lần từ cùng một tài khoản", async function () {
    // Lần 1: Thành công
    await voting.connect(voter1).vote(1);
    
    // Lần 2: Bị revert
    await expect(
      voting.connect(voter1).vote(1)
    ).to.be.revertedWith("Voting: ban da bo phieu roi");
  });

  it("6. Kiểm tra event votedEvent được phát ra đúng với candidateId", async function () {
    await expect(voting.connect(voter1).vote(1))
      .to.emit(voting, "votedEvent")
      .withArgs(1n);
  });

  // KIỂM THỬ CÁC YÊU CẦU MỞ RỘNG (Theo mục 2.2 của đề bài)

  it("7. Yêu cầu mở rộng (Admin/Owner): Chỉ owner mới có quyền thêm ứng cử viên", async function () {
    // Owner thực hiện thêm ứng viên -> Thành công
    await voting.connect(owner).addCandidate("Ung vien mo rong");
    expect(await voting.candidatesCount()).to.equal(6n);

    // Tài khoản thường thực hiện thêm ứng viên -> Bị revert
    await expect(
      voting.connect(voter1).addCandidate("Ung vien khong hop le")
    ).to.be.revertedWith("Voting: chi owner moi duoc thuc hien");
  });

  it("8. Yêu cầu mở rộng (Whitelist): Chỉ danh sách cử tri được ủy quyền mới được bỏ phiếu", async function () {
    // Bật tính năng whitelist
    await voting.connect(owner).setWhitelistEnabled(true);

    // Tài khoản chưa được cấp quyền cố tình bỏ phiếu -> Bị revert
    await expect(
      voting.connect(voter1).vote(1)
    ).to.be.revertedWith("Voting: ban khong co trong danh sach cu tri");

    // Owner cấp quyền (add to whitelist) cho voter1
    await voting.connect(owner).addToWhitelist(voter1.address);
    
    // Voter1 tiến hành bỏ phiếu sau khi được cấp quyền -> Thành công
    await voting.connect(voter1).vote(1);
    expect(await voting.checkHasVoted(voter1.address)).to.be.true;
  });

  it("9. Yêu cầu mở rộng (Thời gian bầu cử): Contract chỉ cho phép bỏ phiếu trong khoảng thời gian startTime - endTime", async function () {
    // Thiết lập thời gian bầu cử trong tương lai (bắt đầu sau 1 tiếng)
    const startTime = Math.floor(Date.now() / 1000) + 3600; 
    const endTime = startTime + 3600;
    
    await voting.connect(owner).setVotingTime(startTime, endTime);
    
    // Kiểm tra trạng thái hệ thống
    expect(await voting.timingEnabled()).to.be.true;
    expect(await voting.startTime()).to.equal(BigInt(startTime));

    // Cố tình bỏ phiếu khi chưa đến giờ -> Bị revert
    await expect(
      voting.connect(voter1).vote(1)
    ).to.be.revertedWith("Voting: chua den thoi gian bo phieu");
  });
});