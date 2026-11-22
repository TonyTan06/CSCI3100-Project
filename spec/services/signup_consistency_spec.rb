
require 'rails_helper'

RSpec.describe "Signup data consistency" do
  # ==================================================
  # 公共测试数据
  # ==================================================

  let(:organization) do
    Organization.create!(
      name: "CUHK Volunteer Team"
    )
  end

  let(:activity) do
    Activity.create!(
      title: "Campus Cleaning",
      description: "Campus cleaning volunteer activity",
      location: "CUHK Campus",
      organization: organization
    )
  end

  let(:organizer) do
    User.create!(
      email_address: "organizer@example.com",
      password: "password123",
      role: "organizer",
      organization: organization
    )
  end

  let(:volunteer_a) do
    create_volunteer("volunteer_a@example.com")
  end

  let(:volunteer_b) do
    create_volunteer("volunteer_b@example.com")
  end

  let(:start_time) do
    Time.current.change(usec: 0) + 1.day
  end

  let(:shift) do
    Shift.create!(
      activity: activity,
      start_time: start_time,
      end_time: start_time + 3.hours,
      capacity: 2
    )
  end

  let(:other_shift) do
    Shift.create!(
      activity: activity,
      start_time: start_time + 4.hours,
      end_time: start_time + 7.hours,
      capacity: 10
    )
  end

  # ==================================================
  # 辅助方法
  # ==================================================

  def create_volunteer(email)
    User.create!(
      email_address: email,
      password: "password123",
      role: "volunteer"
    )
  end

  # ==================================================
  # 数据一致性测试
  # ==================================================

  # Test 1: 使用过期容量不能导致超额报名
  it "uses the latest capacity when signing up with a stale shift object" do
    # 1. Volunteer A 占用一个正式名额
    Signup.create!(
      user: volunteer_a,
      shift: shift,
      status: "confirmed"
    )

    # 2. 模拟另一个请求读取班次
    stale_shift = Shift.find(shift.id)

    expect(stale_shift.capacity).to eq(2)

    # 3. Organizer 将容量从 2 降低至 1
    result = ShiftUpdateService.call(
      user: organizer,
      shift: shift,
      attributes: {
        capacity: 1
      }
    )

    expect(result.errors).to be_empty
    expect(shift.reload.capacity).to eq(1)

    # 4. 旧对象仍然保存原来的容量
    expect(stale_shift.capacity).to eq(2)

    # 5. Volunteer B 使用旧对象尝试报名
    signup = SignupService.call(
      user: volunteer_b,
      shift: stale_shift
    )

    # 6. 系统必须按照最新容量分配状态
    expect(signup).to be_persisted
    expect(signup.errors).to be_empty

    expect(signup.reload.status).to eq(
      "waitlisted"
    )

    # 7. 检查班次没有超额报名
    expect(shift.reload.confirmed_count).to eq(1)
    expect(shift.available_slots).to eq(0)
    expect(shift.waitlist_queue.count).to eq(1)
  end

  # Test 2: 使用过期容量不能错误分配候补状态
  it "confirms a signup when the latest capacity has available slots" do
    # 1. 将初始容量设置为 1
    shift.update!(capacity: 1)

    # 2. Volunteer A 占用唯一正式名额
    Signup.create!(
      user: volunteer_a,
      shift: shift,
      status: "confirmed"
    )

    # 3. 模拟另一个请求读取班次
    stale_shift = Shift.find(shift.id)

    expect(stale_shift.full?).to be true

    # 4. Organizer 将容量增加至 2
    result = ShiftUpdateService.call(
      user: organizer,
      shift: shift,
      attributes: {
        capacity: 2
      }
    )

    expect(result.errors).to be_empty
    expect(shift.reload.available_slots).to eq(1)

    # 5. 旧对象仍然认为班次满员
    expect(stale_shift.capacity).to eq(1)
    expect(stale_shift.full?).to be true

    # 6. Volunteer B 使用旧对象尝试报名
    signup = SignupService.call(
      user: volunteer_b,
      shift: stale_shift
    )

    # 7. 系统必须根据最新容量确认报名
    expect(signup).to be_persisted
    expect(signup.errors).to be_empty

    expect(signup.reload.status).to eq(
      "confirmed"
    )

    expect(signup.waitlisted_at).to be_nil

    # 8. 检查班次已经满员
    expect(shift.reload.confirmed_count).to eq(2)
    expect(shift.available_slots).to eq(0)
    expect(shift.waitlist_queue).to be_empty
  end

  # Test 3: 必须使用最新班次时间检查报名冲突
  it "uses the latest shift times when checking signup conflicts" do
    # 1. Volunteer A 已经报名另一个班次
    Signup.create!(
      user: volunteer_a,
      shift: other_shift,
      status: "confirmed"
    )

    # 2. 模拟另一个请求读取当前班次
    stale_shift = Shift.find(shift.id)

    original_end_time = stale_shift.end_time

    # 3. Organizer 修改当前班次时间
    # 修改后与 Volunteer A 的已有报名产生冲突
    result = ShiftUpdateService.call(
      user: organizer,
      shift: shift,
      attributes: {
        start_time: start_time + 2.hours,
        end_time: start_time + 5.hours
      }
    )

    expect(result.errors).to be_empty

    # 4. 检查数据库中的新时间
    expect(shift.reload.end_time).to eq(
      start_time + 5.hours
    )

    # 5. 检查旧对象仍然保留原来的时间
    expect(stale_shift.end_time).to eq(
      original_end_time
    )

    # 6. 尝试使用旧对象报名
    signup = nil

    expect {
      signup = SignupService.call(
        user: volunteer_a,
        shift: stale_shift
      )
    }.not_to change(Signup, :count)

    # 7. 系统必须拒绝存在时间冲突的报名
    expect(signup).not_to be_persisted

    expect(signup.errors[:shift]).to include(
      "overlaps with another confirmed signup"
    )

    # 8. 当前班次没有新增正式报名
    expect(shift.confirmed_count).to eq(0)
  end

  # Test 4: 在读取班次数据之前开启数据库事务
  it "opens a transaction before reading shift data" do
    # 1. 提前创建测试数据
    shift
    volunteer_a

    connection = ActiveRecord::Base.lease_connection

    # 2. 记录调用 Service 之前的事务层数
    original_transaction_count =
      connection.open_transactions

    # 3. 检查重新读取班次时是否已经开启事务
    expect(shift)
      .to receive(:reload)
      .and_wrap_original do |original|
        expect(
          connection.open_transactions
        ).to be > original_transaction_count

        # 执行原有 reload 方法
        original.call
      end

    # 4. 执行报名
    signup = SignupService.call(
      user: volunteer_a,
      shift: shift
    )

    # 5. 检查报名成功
    expect(signup).to be_persisted
    expect(signup.errors).to be_empty
    expect(signup.reload.status).to eq("confirmed")

    # 6. 检查 Service 已结束自己的事务
    expect(
      connection.open_transactions
    ).to eq(original_transaction_count)
  end

  # Test 5: 报名保存后发生异常时回滚数据库
  it "rolls back signup creation when an error occurs after saving" do
    # 1. 创建尚未保存的报名对象
    signup = Signup.new(
      user: volunteer_a,
      shift: shift,
      status: "confirmed"
    )

    # 2. 保存原有报名数量
    original_signup_count = Signup.count

    # 3. 让 Service 使用指定的报名对象
    allow(Signup).to receive(:new).and_call_original

    allow(Signup)
      .to receive(:new)
      .with(
        user: volunteer_a,
        shift: shift,
        status: "confirmed"
      )
      .and_return(signup)

    # 4. 模拟保存成功后发生系统异常
    allow(signup)
      .to receive(:save)
      .and_wrap_original do |original|
        # 执行真正的数据库保存
        expect(original.call).to be true

        # 模拟保存之后发生异常
        raise StandardError, "Simulated signup failure"
      end

    # 5. 执行报名并检查系统异常
    expect {
      SignupService.call(
        user: volunteer_a,
        shift: shift
      )
    }.to raise_error(
      StandardError,
      "Simulated signup failure"
    )

    # 6. 检查报名记录已被回滚
    expect(Signup.count).to eq(
      original_signup_count
    )

    # 7. 检查不存在新增的报名记录
    expect(
      Signup.exists?(
        user: volunteer_a,
        shift: shift
      )
    ).to be false

    # 8. 检查班次名额保持不变
    expect(shift.reload.confirmed_count).to eq(0)
    expect(shift.available_slots).to eq(2)
  end
end
