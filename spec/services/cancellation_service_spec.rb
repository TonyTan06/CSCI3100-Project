
require 'rails_helper'

RSpec.describe CancellationService do
  include ActiveSupport::Testing::TimeHelpers

  # ==================================================
  # 公共测试数据
  # ==================================================

  # 创建活动所属的 Organization
  let(:organization) do
    Organization.create!(
      name: "CUHK Volunteer Team"
    )
  end

  # 创建班次所属的 Activity
  let(:activity) do
    Activity.create!(
      title: "Campus Cleaning",
      description: "Campus cleaning volunteer activity",
      location: "CUHK Campus",
      organization: organization
    )
  end

  # 设置测试初始时间
  let(:initial_time) do
    Time.current.change(usec: 0)
  end

  # 设置班次开始时间
  let(:start_time) do
    initial_time + 1.day
  end

  # 创建主要测试班次
  let(:shift) do
    Shift.create!(
      activity: activity,
      start_time: start_time,
      end_time: start_time + 3.hours,
      capacity: 1
    )
  end

  # 创建存在时间冲突的班次
  let(:conflicting_shift) do
    Shift.create!(
      activity: activity,
      start_time: start_time + 2.hours,
      end_time: start_time + 5.hours,
      capacity: 20
    )
  end

  # 创建不存在时间冲突的班次
  let(:other_shift) do
    Shift.create!(
      activity: activity,
      start_time: start_time + 4.hours,
      end_time: start_time + 7.hours,
      capacity: 1
    )
  end

  # 创建 Volunteer A
  let(:volunteer_a) do
    create_volunteer("volunteer_a@example.com")
  end

  # 创建 Volunteer B
  let(:volunteer_b) do
    create_volunteer("volunteer_b@example.com")
  end

  # 创建 Volunteer C
  let(:volunteer_c) do
    create_volunteer("volunteer_c@example.com")
  end

  # 创建 Volunteer D
  let(:volunteer_d) do
    create_volunteer("volunteer_d@example.com")
  end

  # 创建 Organizer
  let(:organizer) do
    User.create!(
      email_address: "organizer@example.com",
      password: "password123",
      role: "organizer",
      organization: organization
    )
  end

  # ==================================================
  # 辅助方法
  # ==================================================

  # 创建合法的 Volunteer
  def create_volunteer(email)
    User.create!(
      email_address: email,
      password: "password123",
      role: "volunteer"
    )
  end

  # 创建正式报名记录
  def create_confirmed_signup(user:, shift:)
    Signup.create!(
      user: user,
      shift: shift,
      status: "confirmed"
    )
  end

  # 在指定时间创建候补报名记录
  def create_waitlisted_signup(user:, shift:, time:)
    travel_to(time) do
      Signup.create!(
        user: user,
        shift: shift,
        status: "waitlisted"
      )
    end
  end

  # ==================================================
  # 取消报名测试
  # ==================================================

  describe ".call" do
    # Test 1: 允许 Volunteer 取消自己的正式报名
    it "allows a volunteer to cancel their confirmed signup" do
      # 1. 创建正式报名记录
      signup = create_confirmed_signup(
        user: volunteer_a,
        shift: shift
      )

      # 2. 保存原有报名记录的信息
      original_id = signup.id
      original_created_at = signup.created_at

      # 3. 检查班次已经满员
      expect(shift.full?).to be true

      # 4. 初始化取消结果
      result = nil

      # 5. 执行取消报名且不删除原有记录
      expect {
        result = CancellationService.call(
          user: volunteer_a,
          signup: signup
        )
      }.not_to change(Signup, :count)

      # 6. 检查 Service 返回结果
      expect(result).to be_a(Signup)
      expect(result).to be_persisted
      expect(result.errors).to be_empty

      # 7. 检查数据库中的报名状态
      expect(result.reload.status).to eq("cancelled")

      # 8. 检查原有 ID 和创建时间保持不变
      expect(result.id).to eq(original_id)
      expect(result.created_at).to eq(original_created_at)

      # 9. 检查班次名额已经释放
      expect(shift.confirmed_count).to eq(0)
      expect(shift.available_slots).to eq(1)
      expect(shift.full?).to be false
    end

    # Test 2: 取消正式报名后自动触发递补
    it "automatically promotes the first waitlisted signup after cancellation" do
      # 1. 让 Volunteer A 占用正式名额
      signup_a = create_confirmed_signup(
        user: volunteer_a,
        shift: shift
      )

      # 2. 创建 Volunteer B 的候补报名
      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time
      )

      # 3. 创建 Volunteer C 的候补报名
      signup_c = create_waitlisted_signup(
        user: volunteer_c,
        shift: shift,
        time: initial_time + 10.minutes
      )

      # 4. 检查原有候补顺序
      expect(shift.waitlist_queue.to_a).to eq(
        [ signup_b, signup_c ]
      )

      # 5. 取消 Volunteer A 的正式报名
      result = CancellationService.call(
        user: volunteer_a,
        signup: signup_a
      )

      # 6. 检查取消操作成功
      expect(result.errors).to be_empty
      expect(signup_a.reload.status).to eq("cancelled")

      # 7. 检查 Volunteer B 自动转正
      expect(signup_b.reload.status).to eq("confirmed")
      expect(signup_b.waitlisted_at).to be_nil

      # 8. 检查 Volunteer C 保持候补状态
      expect(signup_c.reload.status).to eq("waitlisted")

      # 9. 检查剩余候补队列
      expect(shift.waitlist_queue.to_a).to eq(
        [ signup_c ]
      )

      # 10. 检查班次重新满员
      expect(shift.confirmed_count).to eq(1)
      expect(shift.available_slots).to eq(0)
      expect(shift.full?).to be true

      # 11. 检查报名记录总数保持不变
      expect(shift.signups.count).to eq(3)
    end

    # Test 3: 递补时跳过存在时间冲突的用户
    it "skips conflicting waitlisted volunteers after cancellation" do
      # 1. 创建 Volunteer A 的正式报名
      signup_a = create_confirmed_signup(
        user: volunteer_a,
        shift: shift
      )

      # 2. 为 Volunteer B 创建存在时间冲突的正式报名
      conflicting_signup = create_confirmed_signup(
        user: volunteer_b,
        shift: conflicting_shift
      )

      # 3. 创建 Volunteer B 的候补报名
      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time
      )

      # 4. 创建 Volunteer C 的候补报名
      signup_c = create_waitlisted_signup(
        user: volunteer_c,
        shift: shift,
        time: initial_time + 10.minutes
      )

      # 5. 保存 Volunteer B 的原有候补时间
      original_waitlisted_at = signup_b.waitlisted_at

      # 6. 取消 Volunteer A 的正式报名
      result = CancellationService.call(
        user: volunteer_a,
        signup: signup_a
      )

      # 7. 检查取消操作成功
      expect(result.errors).to be_empty
      expect(signup_a.reload.status).to eq("cancelled")

      # 8. 检查 Volunteer B 因时间冲突保持候补
      expect(signup_b.reload.status).to eq("waitlisted")
      expect(signup_b.waitlisted_at).to eq(
        original_waitlisted_at
      )

      # 9. 检查 Volunteer C 自动转正
      expect(signup_c.reload.status).to eq("confirmed")
      expect(signup_c.waitlisted_at).to be_nil

      # 10. 检查冲突班次的报名保持不变
      expect(conflicting_signup.reload.status).to eq(
        "confirmed"
      )

      # 11. 检查班次重新满员
      expect(shift.full?).to be true

      # 12. 检查剩余候补队列
      expect(shift.waitlist_queue.to_a).to eq(
        [ signup_b ]
      )
    end

    # Test 4: 没有合格候补用户时保留空余名额
    it "keeps a slot available when no waitlisted volunteer is eligible" do
      # 1. 创建 Volunteer A 的正式报名
      signup_a = create_confirmed_signup(
        user: volunteer_a,
        shift: shift
      )

      # 2. 为 Volunteer B 创建时间冲突的正式报名
      create_confirmed_signup(
        user: volunteer_b,
        shift: conflicting_shift
      )

      # 3. 创建 Volunteer B 的候补报名
      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time
      )

      # 4. 取消 Volunteer A 的正式报名
      result = CancellationService.call(
        user: volunteer_a,
        signup: signup_a
      )

      # 5. 检查取消操作成功
      expect(result.errors).to be_empty
      expect(signup_a.reload.status).to eq("cancelled")

      # 6. 检查 Volunteer B 仍然候补
      expect(signup_b.reload.status).to eq("waitlisted")
      expect(signup_b.waitlisted_at).to eq(initial_time)

      # 7. 检查班次保留空余名额
      expect(shift.confirmed_count).to eq(0)
      expect(shift.available_slots).to eq(1)
      expect(shift.full?).to be false

      # 8. 检查候补队列保持不变
      expect(shift.waitlist_queue.to_a).to eq(
        [ signup_b ]
      )
    end

    # Test 5: 允许 Volunteer 取消自己的候补报名
    it "allows a volunteer to cancel their waitlisted signup" do
      # 1. 创建 Volunteer A 的正式报名
      signup_a = create_confirmed_signup(
        user: volunteer_a,
        shift: shift
      )

      # 2. 创建 Volunteer B 的候补报名
      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time
      )

      # 3. 保存原有报名记录的 ID
      original_id = signup_b.id

      # 4. 初始化取消结果
      result = nil

      # 5. 取消候补报名且不删除原有记录
      expect {
        result = CancellationService.call(
          user: volunteer_b,
          signup: signup_b
        )
      }.not_to change(Signup, :count)

      # 6. 检查取消操作成功
      expect(result.errors).to be_empty
      expect(signup_b.reload.status).to eq("cancelled")

      # 7. 检查候补时间已清空
      expect(signup_b.waitlisted_at).to be_nil

      # 8. 检查原有报名 ID 保持不变
      expect(signup_b.id).to eq(original_id)

      # 9. 检查原有正式报名不受影响
      expect(signup_a.reload.status).to eq("confirmed")

      # 10. 检查班次仍然满员且候补队列为空
      expect(shift.full?).to be true
      expect(shift.waitlist_queue).to be_empty
    end

    # Test 6: 取消候补报名时不触发递补
    it "does not trigger automatic promotion when cancelling a waitlisted signup" do
      # 1. 创建第一位候补用户
      signup_a = create_waitlisted_signup(
        user: volunteer_a,
        shift: shift,
        time: initial_time
      )

      # 2. 创建第二位候补用户
      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time + 10.minutes
      )

      # 3. 检查班次拥有空余名额
      expect(shift.available_slots).to eq(1)

      # 4. 检查取消候补时不会调用 WaitlistService
      expect(WaitlistService).not_to receive(:call)

      # 5. 取消 Volunteer A 的候补报名
      result = CancellationService.call(
        user: volunteer_a,
        signup: signup_a
      )

      # 6. 检查取消操作成功
      expect(result.errors).to be_empty
      expect(signup_a.reload.status).to eq("cancelled")

      # 7. 检查 Volunteer B 保持候补状态
      expect(signup_b.reload.status).to eq("waitlisted")

      # 8. 检查剩余名额保持不变
      expect(shift.available_slots).to eq(1)

      # 9. 检查剩余候补队列
      expect(shift.waitlist_queue.to_a).to eq(
        [ signup_b ]
      )
    end

    # Test 7: 禁止重复取消报名
    it "rejects cancellation of an already cancelled signup" do
      # 1. 创建已取消的报名记录
      signup = Signup.create!(
        user: volunteer_a,
        shift: shift,
        status: "cancelled"
      )

      # 2. 保存原有更新时间
      original_updated_at = signup.updated_at

      # 3. 检查不会触发自动递补
      expect(WaitlistService).not_to receive(:call)

      # 4. 尝试重复取消报名
      result = CancellationService.call(
        user: volunteer_a,
        signup: signup
      )

      # 5. 检查返回重复取消错误
      expect(result.errors[:status]).to include(
        "has already been cancelled"
      )

      # 6. 检查数据库记录保持不变
      expect(signup.reload.status).to eq("cancelled")
      expect(signup.updated_at).to eq(original_updated_at)

      # 7. 检查报名记录未被删除
      expect(signup).to be_persisted
    end

    # Test 8: 禁止取消其他 Volunteer 的报名
    it "rejects cancellation of another volunteer's signup" do
      # 1. 创建 Volunteer A 的正式报名
      signup = create_confirmed_signup(
        user: volunteer_a,
        shift: shift
      )

      # 2. 保存原有更新时间
      original_updated_at = signup.updated_at

      # 3. 检查非法取消不会触发自动递补
      expect(WaitlistService).not_to receive(:call)

      # 4. 尝试由 Volunteer B 取消 A 的报名
      result = CancellationService.call(
        user: volunteer_b,
        signup: signup
      )

      # 5. 检查返回报名归属错误
      expect(result.errors[:user]).to include(
        "can only cancel their own signups"
      )

      # 6. 检查原有报名保持不变
      expect(signup.reload.status).to eq("confirmed")
      expect(signup.updated_at).to eq(original_updated_at)

      # 7. 检查班次仍然满员
      expect(shift.confirmed_count).to eq(1)
      expect(shift.full?).to be true
    end

    # Test 9: 禁止 Organizer 通过此接口取消报名
    it "rejects cancellation requests from organizers" do
      # 1. 创建 Volunteer 的正式报名
      signup = create_confirmed_signup(
        user: volunteer_a,
        shift: shift
      )

      # 2. 保存原有更新时间
      original_updated_at = signup.updated_at

      # 3. 检查非法取消不会触发自动递补
      expect(WaitlistService).not_to receive(:call)

      # 4. 尝试由 Organizer 取消报名
      result = CancellationService.call(
        user: organizer,
        signup: signup
      )

      # 5. 检查返回用户角色错误
      expect(result.errors[:user]).to include(
        "must be a volunteer"
      )

      # 6. 检查原有报名保持不变
      expect(signup.reload.status).to eq("confirmed")
      expect(signup.updated_at).to eq(original_updated_at)

      # 7. 检查班次仍然满员
      expect(shift.full?).to be true
    end

    # Test 10: 取消报名后允许重新报名
    it "allows a volunteer to sign up again after successful cancellation" do
      # 1. 通过 SignupService 创建正式报名
      signup = SignupService.call(
        user: volunteer_a,
        shift: shift
      )

      # 2. 检查第一次报名成功
      expect(signup).to be_persisted
      expect(signup.reload.status).to eq("confirmed")

      # 3. 保存原有报名 ID
      original_id = signup.id

      # 4. 通过 CancellationService 取消报名
      result = CancellationService.call(
        user: volunteer_a,
        signup: signup
      )

      # 5. 检查取消操作成功
      expect(result.errors).to be_empty
      expect(signup.reload.status).to eq("cancelled")

      # 6. 检查班次名额已释放
      expect(shift.available_slots).to eq(1)

      # 7. 初始化重新报名结果
      returning_signup = nil

      # 8. 通过 SignupService 重新报名
      expect {
        returning_signup = SignupService.call(
          user: volunteer_a,
          shift: shift
        )
      }.not_to change(Signup, :count)

      # 9. 检查重新报名成功
      expect(returning_signup.errors).to be_empty
      expect(returning_signup.reload.status).to eq(
        "confirmed"
      )

      # 10. 检查重新报名复用了原有记录
      expect(returning_signup.id).to eq(original_id)

      # 11. 检查班次重新满员
      expect(shift.full?).to be true
    end

    # Test 11: 不影响其他班次的报名记录
    it "does not modify waitlisted signups belonging to other shifts" do
      # 1. 创建当前班次的正式报名
      signup_a = create_confirmed_signup(
        user: volunteer_a,
        shift: shift
      )

      # 2. 创建当前班次的候补报名
      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time + 10.minutes
      )

      # 3. 创建另一个班次的候补报名
      signup_c = create_waitlisted_signup(
        user: volunteer_c,
        shift: other_shift,
        time: initial_time
      )

      # 4. 保存另一个班次候补记录的原有时间
      original_waitlisted_at = signup_c.waitlisted_at
      original_updated_at = signup_c.updated_at

      # 5. 取消当前班次的正式报名
      result = CancellationService.call(
        user: volunteer_a,
        signup: signup_a
      )

      # 6. 检查取消操作成功
      expect(result.errors).to be_empty
      expect(signup_a.reload.status).to eq("cancelled")

      # 7. 检查仅当前班次的候补用户成功转正
      expect(signup_b.reload.status).to eq("confirmed")

      # 8. 检查其他班次的候补状态保持不变
      expect(signup_c.reload.status).to eq("waitlisted")

      # 9. 检查其他班次的候补时间保持不变
      expect(signup_c.waitlisted_at).to eq(
        original_waitlisted_at
      )

      expect(signup_c.updated_at).to eq(
        original_updated_at
      )

      # 10. 检查其他班次的候补队列不受影响
      expect(other_shift.waitlist_queue.to_a).to eq(
        [ signup_c ]
      )
    end

    # Test 12: 递补异常时回滚取消操作
    it "rolls back cancellation and promotion when automatic promotion raises an error" do
      # 1. 创建正式报名记录
      signup_a = create_confirmed_signup(
        user: volunteer_a,
        shift: shift
      )

      # 2. 创建候补报名记录
      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time
      )

      # 3. 保存原有时间信息
      original_updated_at = signup_a.updated_at
      original_waitlisted_at = signup_b.waitlisted_at
      original_waitlisted_updated_at = signup_b.updated_at

      # 4. 模拟递补成功写入数据库后发生系统异常
      allow(WaitlistService)
        .to receive(:call)
        .with(shift: shift) do
          # 模拟已经执行了一次候补转正
          signup_b.update!(status: "confirmed")

          # 模拟后续发生异常
          raise StandardError, "Simulated promotion failure"
        end

      # 5. 执行取消报名并检查系统异常
      expect {
        CancellationService.call(
          user: volunteer_a,
          signup: signup_a
        )
      }.to raise_error(
        StandardError,
        "Simulated promotion failure"
      )

      # 6. 检查取消操作已被回滚
      expect(signup_a.reload.status).to eq("confirmed")

      # 7. 检查递补操作也已被回滚
      expect(signup_b.reload.status).to eq("waitlisted")

      # 8. 检查正式报名的更新时间保持不变
      expect(signup_a.updated_at).to eq(
        original_updated_at
      )

      # 9. 检查候补时间及更新时间已经恢复
      expect(signup_b.waitlisted_at).to eq(
        original_waitlisted_at
      )

      expect(signup_b.updated_at).to eq(
        original_waitlisted_updated_at
      )

      # 10. 检查班次人数保持不变
      expect(shift.confirmed_count).to eq(1)
      expect(shift.waitlist_queue.count).to eq(1)
      expect(shift.full?).to be true
    end
  end
end
