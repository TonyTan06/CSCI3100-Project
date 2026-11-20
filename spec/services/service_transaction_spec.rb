
require 'rails_helper'

RSpec.describe "Service transaction consistency" do

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

  # ==================================================
  # 辅助方法
  # ==================================================

  # 创建 Volunteer
  def create_volunteer(email)
    User.create!(
      email_address: email,
      password: "password123",
      role: "volunteer"
    )
  end

  # 创建报名记录
  def create_signup(user:, status:)
    Signup.create!(
      user: user,
      shift: shift,
      status: status
    )
  end

  # 检查 reload 是否在新的业务事务内部执行
  def expect_reload_inside_transaction(record)

    connection = ActiveRecord::Base.lease_connection

    original_transaction_count =
      connection.open_transactions

    expect(record)
      .to receive(:reload)
      .and_wrap_original do |original|

        # 新的业务事务必须已经开启
        expect(
          connection.open_transactions
        ).to be > original_transaction_count

        # 执行原有 reload 方法
        original.call
      end
  end

  # ==================================================
  # 事务边界测试
  # ==================================================

  # Test 1: CancellationService 在事务内读取数据
  it "opens a transaction before reloading a signup for cancellation" do

    signup = create_signup(
      user: volunteer_a,
      status: "confirmed"
    )

    expect_reload_inside_transaction(signup)

    result = CancellationService.call(
      user: volunteer_a,
      signup: signup
    )

    expect(result.errors).to be_empty

    expect(
      Signup.find(signup.id).status
    ).to eq("cancelled")
  end

  # Test 2: ShiftUpdateService 在事务内读取数据
  it "opens a transaction before reloading a shift for updates" do

    organizer
    shift

    expect_reload_inside_transaction(shift)

    result = ShiftUpdateService.call(
      user: organizer,
      shift: shift,
      attributes: {
        capacity: 1
      }
    )

    expect(result.errors).to be_empty

    expect(
      Shift.find(shift.id).capacity
    ).to eq(1)
  end

  # Test 3: AttendanceService 在事务内读取数据
  it "opens a transaction before reloading a signup for attendance updates" do

    signup = create_signup(
      user: volunteer_a,
      status: "confirmed"
    )

    organizer

    expect_reload_inside_transaction(signup)

    result = AttendanceService.call(
      user: organizer,
      signup: signup,
      attendance_status: "present"
    )

    expect(result.errors).to be_empty

    expect(
      Signup.find(signup.id).attendance_status
    ).to eq("present")
  end

  # Test 4: WaitlistService 在事务内读取数据
  it "opens a transaction before reloading a shift for promotion" do

    shift

    expect_reload_inside_transaction(shift)

    result = WaitlistService.call(
      shift: shift
    )

    expect(result).to eq([])
  end

  # ==================================================
  # 数据一致性测试
  # ==================================================

  # Test 5: WaitlistService 必须使用最新容量
  it "uses the latest capacity when promoting with a stale shift object" do

    # 1. 将班次容量设置为 1
    shift.update!(capacity: 1)

    # 2. Volunteer A 占用唯一名额
    create_signup(
      user: volunteer_a,
      status: "confirmed"
    )

    # 3. Volunteer B 进入候补队列
    signup_b = create_signup(
      user: volunteer_b,
      status: "waitlisted"
    )

    # 4. 模拟另一个请求读取班次
    stale_shift = Shift.find(shift.id)

    expect(stale_shift.full?).to be true

    # 5. 直接修改容量
    # 此处绕过 ShiftUpdateService，
    # 单独测试 WaitlistService 的数据一致性
    shift.update!(capacity: 2)

    expect(shift.available_slots).to eq(1)

    # 6. 旧对象仍然认为班次已经满员
    expect(stale_shift.capacity).to eq(1)
    expect(stale_shift.full?).to be true

    # 7. 使用旧对象执行递补
    promoted_signups = WaitlistService.call(
      shift: stale_shift
    )

    # 8. 系统应该根据最新容量完成递补
    expect(promoted_signups).to eq(
      [signup_b]
    )

    expect(signup_b.reload.status).to eq(
      "confirmed"
    )

    expect(signup_b.waitlisted_at).to be_nil

    expect(shift.reload.confirmed_count).to eq(2)
    expect(shift.available_slots).to eq(0)
  end

  # ==================================================
  # 事务回滚测试
  # ==================================================

  # Test 6: 多人递补过程中发生异常时全部回滚
  it "rolls back all promotions when an unexpected error occurs" do

    # 1. 创建两位候补用户
    signup_a = create_signup(
      user: volunteer_a,
      status: "waitlisted"
    )

    signup_b = create_signup(
      user: volunteer_b,
      status: "waitlisted"
    )

    # 2. 保存原有候补时间
    original_waitlisted_at_a =
      signup_a.waitlisted_at

    original_waitlisted_at_b =
      signup_b.waitlisted_at

    original_updated_at_a =
      signup_a.updated_at

    original_updated_at_b =
      signup_b.updated_at

    expect(shift.available_slots).to eq(2)

    # 3. 固定测试中的候补对象
    # 方便对第二次递补模拟系统异常
    allow(shift)
      .to receive(:waitlist_queue)
      .and_return([signup_a, signup_b])

    # 4. 模拟第二位用户递补时发生异常
    allow(signup_b)
      .to receive(:update)
      .with(status: "confirmed") do

        # 确认第一位用户已经成功写入数据库
        expect(
          Signup.find(signup_a.id).status
        ).to eq("confirmed")

        raise StandardError,
              "Simulated waitlist transaction failure"
      end

    # 5. 执行自动递补并检查异常
    expect {
      WaitlistService.call(
        shift: shift
      )
    }.to raise_error(
      StandardError,
      "Simulated waitlist transaction failure"
    )

    # 6. 检查两个报名记录是否恢复原有状态
    expect(signup_a.reload.status).to eq(
      "waitlisted"
    )

    expect(signup_b.reload.status).to eq(
      "waitlisted"
    )

    # 7. 检查候补时间是否恢复
    expect(signup_a.waitlisted_at).to eq(
      original_waitlisted_at_a
    )

    expect(signup_b.waitlisted_at).to eq(
      original_waitlisted_at_b
    )

    # 8. 检查更新时间是否恢复
    expect(signup_a.updated_at).to eq(
      original_updated_at_a
    )

    expect(signup_b.updated_at).to eq(
      original_updated_at_b
    )

    # 9. 检查班次容量及候补人数
    expect(shift.reload.confirmed_count).to eq(0)
    expect(shift.available_slots).to eq(2)

    expect(
      shift.signups.where(status: "waitlisted").count
    ).to eq(2)
  end
end
