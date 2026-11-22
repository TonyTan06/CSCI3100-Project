
require 'rails_helper'

RSpec.describe WaitlistService do
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

  # 创建与主要班次存在时间冲突的班次
  let(:conflicting_shift) do
    Shift.create!(
      activity: activity,
      start_time: start_time + 2.hours,
      end_time: start_time + 5.hours,
      capacity: 20
    )
  end

  # 创建与主要班次不存在时间冲突的班次
  let(:other_shift) do
    Shift.create!(
      activity: activity,
      start_time: start_time + 4.hours,
      end_time: start_time + 7.hours,
      capacity: 1
    )
  end

  # 创建测试 Volunteer
  let(:volunteer_a) do
    create_volunteer("volunteer_a@example.com")
  end

  let(:volunteer_b) do
    create_volunteer("volunteer_b@example.com")
  end

  let(:volunteer_c) do
    create_volunteer("volunteer_c@example.com")
  end

  let(:volunteer_d) do
    create_volunteer("volunteer_d@example.com")
  end

  # ==================================================
  # 辅助方法
  # ==================================================

  # 创建合法的 Volunteer 用户
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
  # 自动递补测试
  # ==================================================

  describe ".call" do
    # Test 1: 没有候补用户时不执行递补
    it "does nothing when there are no waitlisted signups" do
      # 1. 检查班次拥有一个空余名额
      expect(shift.available_slots).to eq(1)

      # 2. 检查候补队列是否为空
      expect(shift.waitlist_queue).to be_empty

      # 3. 调用自动递补 Service
      promoted_signups = WaitlistService.call(
        shift: shift
      )

      # 4. 检查是否返回空数组
      expect(promoted_signups).to eq([])

      # 5. 检查班次没有新增正式报名
      expect(shift.confirmed_count).to eq(0)

      # 6. 检查剩余名额是否保持不变
      expect(shift.available_slots).to eq(1)

      # 7. 检查班次没有新增报名记录
      expect(shift.signups.count).to eq(0)
    end

    # Test 2: 班次满员时不执行递补
    it "does not promote any signup when the shift is full" do
      # 1. 让 Volunteer A 占用唯一正式名额
      confirmed_signup = create_confirmed_signup(
        user: volunteer_a,
        shift: shift
      )

      # 2. 创建 Volunteer B 的候补报名
      waitlisted_signup = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time
      )

      # 3. 保存原有候补时间
      original_waitlisted_at =
        waitlisted_signup.waitlisted_at

      # 4. 检查班次是否已经满员
      expect(shift.full?).to be true

      # 5. 调用自动递补 Service
      promoted_signups = WaitlistService.call(
        shift: shift
      )

      # 6. 检查没有任何用户成功递补
      expect(promoted_signups).to eq([])

      # 7. 检查原有正式报名是否保持不变
      expect(confirmed_signup.reload.status).to eq(
        "confirmed"
      )

      # 8. 检查候补报名是否保持不变
      expect(waitlisted_signup.reload.status).to eq(
        "waitlisted"
      )

      # 9. 检查原有候补时间是否保持不变
      expect(waitlisted_signup.waitlisted_at).to eq(
        original_waitlisted_at
      )

      # 10. 检查班次人数是否保持不变
      expect(shift.confirmed_count).to eq(1)
      expect(shift.waitlist_queue.count).to eq(1)
      expect(shift.available_slots).to eq(0)
    end

    # Test 3: 有一个空余名额时递补第一位用户
    it "promotes the first waitlisted signup when a slot is available" do
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

      # 3. 检查班次拥有一个空余名额
      expect(shift.available_slots).to eq(1)

      # 4. 初始化递补结果
      promoted_signups = nil

      # 5. 执行递补且不创建新的报名记录
      expect {
        promoted_signups = WaitlistService.call(
          shift: shift
        )
      }.not_to change(Signup, :count)

      # 6. 检查第一位候补用户是否成功递补
      expect(promoted_signups).to eq([ signup_a ])

      # 7. 检查第一位用户的数据库状态
      expect(signup_a.reload.status).to eq(
        "confirmed"
      )

      # 8. 检查第二位用户是否仍然候补
      expect(signup_b.reload.status).to eq(
        "waitlisted"
      )

      # 9. 检查候补队列是否已经更新
      expect(shift.waitlist_queue.to_a).to eq(
        [ signup_b ]
      )

      # 10. 检查班次是否已经满员
      expect(shift.confirmed_count).to eq(1)
      expect(shift.available_slots).to eq(0)
      expect(shift.full?).to be true
    end

    # Test 4: 按照 FIFO 顺序执行递补
    it "promotes signups according to FIFO waitlist order" do
      # 1. 首先创建候补时间最晚的记录
      signup_c = create_waitlisted_signup(
        user: volunteer_c,
        shift: shift,
        time: initial_time + 20.minutes
      )

      # 2. 创建候补时间最早的记录
      signup_a = create_waitlisted_signup(
        user: volunteer_a,
        shift: shift,
        time: initial_time
      )

      # 3. 创建候补时间居中的记录
      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time + 10.minutes
      )

      # 4. 检查原有候补队列顺序
      expect(shift.waitlist_queue.to_a).to eq(
        [ signup_a, signup_b, signup_c ]
      )

      # 5. 调用自动递补 Service
      promoted_signups = WaitlistService.call(
        shift: shift
      )

      # 6. 检查递补的是候补时间最早的用户
      expect(promoted_signups).to eq([ signup_a ])

      # 7. 检查三个报名记录的状态
      expect(signup_a.reload.status).to eq(
        "confirmed"
      )

      expect(signup_b.reload.status).to eq(
        "waitlisted"
      )

      expect(signup_c.reload.status).to eq(
        "waitlisted"
      )

      # 8. 检查剩余候补队列的顺序
      expect(shift.waitlist_queue.to_a).to eq(
        [ signup_b, signup_c ]
      )
    end

    # Test 5: 递补成功后自动清空候补时间
    it "clears waitlisted_at after successful promotion" do
      # 1. 创建候补报名记录
      signup = create_waitlisted_signup(
        user: volunteer_a,
        shift: shift,
        time: initial_time
      )

      # 2. 保存原有报名记录的信息
      original_id = signup.id
      original_created_at = signup.created_at

      # 3. 检查原有候补时间
      expect(signup.waitlisted_at).to eq(
        initial_time
      )

      # 4. 调用自动递补 Service
      promoted_signups = WaitlistService.call(
        shift: shift
      )

      # 5. 检查是否成功递补
      expect(promoted_signups).to eq([ signup ])

      # 6. 从数据库重新读取报名记录
      signup.reload

      # 7. 检查报名状态是否为 confirmed
      expect(signup.status).to eq("confirmed")

      # 8. 检查候补时间是否已清空
      expect(signup.waitlisted_at).to be_nil

      # 9. 检查出勤状态仍然为 pending
      expect(signup.attendance_status).to eq(
        "pending"
      )

      # 10. 检查记录 ID 和创建时间是否保持不变
      expect(signup.id).to eq(original_id)
      expect(signup.created_at).to eq(
        original_created_at
      )

      # 11. 检查候补队列是否为空
      expect(shift.waitlist_queue).to be_empty
    end

    # Test 6: 跳过存在时间冲突的候补用户
    it "skips a conflicting signup and promotes the next eligible signup" do
      # 1. 让 Volunteer A 报名一个时间冲突的班次
      conflicting_signup = create_confirmed_signup(
        user: volunteer_a,
        shift: conflicting_shift
      )

      # 2. 创建 Volunteer A 的候补报名
      signup_a = create_waitlisted_signup(
        user: volunteer_a,
        shift: shift,
        time: initial_time
      )

      # 3. 创建没有时间冲突的 Volunteer B 的候补报名
      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time + 10.minutes
      )

      # 4. 保存 Volunteer A 的原有候补信息
      original_waitlisted_at = signup_a.waitlisted_at
      original_updated_at = signup_a.updated_at

      # 5. 检查候补队列顺序
      expect(shift.waitlist_queue.to_a).to eq(
        [ signup_a, signup_b ]
      )

      # 6. 调用自动递补 Service
      promoted_signups = WaitlistService.call(
        shift: shift
      )

      # 7. 检查是否跳过 A 并成功递补 B
      expect(promoted_signups).to eq([ signup_b ])

      # 8. 检查 Volunteer A 是否仍然处于候补状态
      expect(signup_a.reload.status).to eq(
        "waitlisted"
      )

      # 9. 检查 Volunteer A 的候补时间是否保持不变
      expect(signup_a.waitlisted_at).to eq(
        original_waitlisted_at
      )

      # 10. 检查递补失败没有修改数据库记录
      expect(signup_a.updated_at).to eq(
        original_updated_at
      )

      # 11. 检查 Volunteer B 是否成功转正
      expect(signup_b.reload.status).to eq(
        "confirmed"
      )

      # 12. 检查原有冲突班次报名是否保持不变
      expect(conflicting_signup.reload.status).to eq(
        "confirmed"
      )

      # 13. 检查候补队列仅剩 Volunteer A
      expect(shift.waitlist_queue.to_a).to eq(
        [ signup_a ]
      )

      # 14. 检查班次是否已经满员
      expect(shift.confirmed_count).to eq(1)
      expect(shift.available_slots).to eq(0)
    end

    # Test 7: 所有候补用户均存在冲突时保留空余名额
    it "keeps slots available when all waitlisted signups have time conflicts" do
      # 1. 为 Volunteer A 创建时间冲突的正式报名
      create_confirmed_signup(
        user: volunteer_a,
        shift: conflicting_shift
      )

      # 2. 为 Volunteer B 创建时间冲突的正式报名
      create_confirmed_signup(
        user: volunteer_b,
        shift: conflicting_shift
      )

      # 3. 创建 Volunteer A 的候补报名
      signup_a = create_waitlisted_signup(
        user: volunteer_a,
        shift: shift,
        time: initial_time
      )

      # 4. 创建 Volunteer B 的候补报名
      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time + 10.minutes
      )

      # 5. 检查班次拥有一个空余名额
      expect(shift.available_slots).to eq(1)

      # 6. 调用自动递补 Service
      promoted_signups = WaitlistService.call(
        shift: shift
      )

      # 7. 检查没有任何用户成功递补
      expect(promoted_signups).to eq([])

      # 8. 检查两个用户均保持候补状态
      expect(signup_a.reload.status).to eq(
        "waitlisted"
      )

      expect(signup_b.reload.status).to eq(
        "waitlisted"
      )

      # 9. 检查原有候补时间没有发生改变
      expect(signup_a.waitlisted_at).to eq(
        initial_time
      )

      expect(signup_b.waitlisted_at).to eq(
        initial_time + 10.minutes
      )

      # 10. 检查原有候补顺序保持不变
      expect(shift.waitlist_queue.to_a).to eq(
        [ signup_a, signup_b ]
      )

      # 11. 检查班次仍然保留空余名额
      expect(shift.confirmed_count).to eq(0)
      expect(shift.available_slots).to eq(1)
      expect(shift.full?).to be false
    end

    # Test 8: 存在多个空余名额时连续递补
    it "promotes multiple eligible signups until capacity is reached" do
      # 1. 将班次容量设置为 2
      shift.update!(capacity: 2)

      # 2. 创建第一位候补用户
      signup_a = create_waitlisted_signup(
        user: volunteer_a,
        shift: shift,
        time: initial_time
      )

      # 3. 创建第二位候补用户
      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time + 10.minutes
      )

      # 4. 创建第三位候补用户
      signup_c = create_waitlisted_signup(
        user: volunteer_c,
        shift: shift,
        time: initial_time + 20.minutes
      )

      # 5. 检查班次拥有两个空余名额
      expect(shift.available_slots).to eq(2)

      # 6. 调用自动递补 Service
      promoted_signups = WaitlistService.call(
        shift: shift
      )

      # 7. 检查前两位候补用户是否成功递补
      expect(promoted_signups).to eq(
        [ signup_a, signup_b ]
      )

      # 8. 检查报名状态
      expect(signup_a.reload.status).to eq(
        "confirmed"
      )

      expect(signup_b.reload.status).to eq(
        "confirmed"
      )

      expect(signup_c.reload.status).to eq(
        "waitlisted"
      )

      # 9. 检查成功递补用户的候补时间
      expect(signup_a.waitlisted_at).to be_nil
      expect(signup_b.waitlisted_at).to be_nil

      # 10. 检查剩余候补队列
      expect(shift.waitlist_queue.to_a).to eq(
        [ signup_c ]
      )

      # 11. 检查班次没有超过容量上限
      expect(shift.confirmed_count).to eq(2)
      expect(shift.available_slots).to eq(0)
      expect(shift.full?).to be true

      # 12. 检查报名记录总数保持不变
      expect(shift.signups.count).to eq(3)
    end

    # Test 9: 候补人数少于剩余名额时全部递补
    it "promotes all eligible signups when enough slots remain" do
      # 1. 将班次容量设置为 5
      shift.update!(capacity: 5)

      # 2. 创建第一位候补用户
      signup_a = create_waitlisted_signup(
        user: volunteer_a,
        shift: shift,
        time: initial_time
      )

      # 3. 创建第二位候补用户
      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time + 10.minutes
      )

      # 4. 调用自动递补 Service
      promoted_signups = WaitlistService.call(
        shift: shift
      )

      # 5. 检查所有候补用户是否成功递补
      expect(promoted_signups).to eq(
        [ signup_a, signup_b ]
      )

      # 6. 检查两个报名是否均为 confirmed
      expect(signup_a.reload.status).to eq(
        "confirmed"
      )

      expect(signup_b.reload.status).to eq(
        "confirmed"
      )

      # 7. 检查候补队列是否为空
      expect(shift.waitlist_queue).to be_empty

      # 8. 检查已确认人数和剩余容量
      expect(shift.confirmed_count).to eq(2)
      expect(shift.available_slots).to eq(3)
      expect(shift.full?).to be false

      # 9. 再次调用 Service 不应产生新的递补
      expect(
        WaitlistService.call(shift: shift)
      ).to eq([])

      # 10. 检查已确认人数是否保持不变
      expect(shift.confirmed_count).to eq(2)
    end

    # Test 10: 不影响其他班次的候补记录
    it "does not promote or modify signups belonging to other shifts" do
      # 1. 创建当前班次的候补报名
      signup_a = create_waitlisted_signup(
        user: volunteer_a,
        shift: shift,
        time: initial_time + 10.minutes
      )

      # 2. 创建另一个班次中更早的候补报名
      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: other_shift,
        time: initial_time
      )

      # 3. 保存其他班次候补记录的时间信息
      original_waitlisted_at = signup_b.waitlisted_at
      original_updated_at = signup_b.updated_at

      # 4. 仅对当前班次执行自动递补
      promoted_signups = WaitlistService.call(
        shift: shift
      )

      # 5. 检查仅当前班次的用户成功递补
      expect(promoted_signups).to eq([ signup_a ])

      # 6. 检查当前班次的报名状态
      expect(signup_a.reload.status).to eq(
        "confirmed"
      )

      # 7. 检查其他班次的报名状态
      expect(signup_b.reload.status).to eq(
        "waitlisted"
      )

      # 8. 检查其他班次的候补时间没有变化
      expect(signup_b.waitlisted_at).to eq(
        original_waitlisted_at
      )

      # 9. 检查其他班次的更新时间没有变化
      expect(signup_b.updated_at).to eq(
        original_updated_at
      )

      # 10. 检查当前班次已成功完成递补
      expect(shift.confirmed_count).to eq(1)
      expect(shift.waitlist_queue).to be_empty

      # 11. 检查另一个班次完全不受影响
      expect(other_shift.confirmed_count).to eq(0)
      expect(other_shift.available_slots).to eq(1)

      expect(other_shift.waitlist_queue.to_a).to eq(
        [ signup_b ]
      )
    end
  end
end
