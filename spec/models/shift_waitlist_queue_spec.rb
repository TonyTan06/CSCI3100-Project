
require 'rails_helper'

RSpec.describe Shift, type: :model do
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

  # 设置测试使用的初始时间
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

  # 创建另一个测试班次
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
  # 候补队列测试
  # ==================================================

  describe "#waitlist_queue" do

    # Test 1: 没有候补报名时返回空队列
    it "returns an empty queue when there are no waitlisted signups" do
      # 1. 检查班次没有任何报名记录
      expect(shift.signups.count).to eq(0)

      # 2. 检查候补队列是否为空
      expect(shift.waitlist_queue).to be_empty
    end

    # Test 2: 按照候补时间进行 FIFO 排序
    it "orders waitlisted signups by waitlisted_at in ascending order" do
      # 1. 创建候补时间最晚的报名记录
      signup_c = create_waitlisted_signup(
        user: volunteer_c,
        shift: shift,
        time: initial_time + 20.minutes
      )

      # 2. 创建候补时间最早的报名记录
      signup_a = create_waitlisted_signup(
        user: volunteer_a,
        shift: shift,
        time: initial_time
      )

      # 3. 创建候补时间居中的报名记录
      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time + 10.minutes
      )

      # 4. 检查实际候补时间
      expect(signup_a.reload.waitlisted_at).to eq(
        initial_time
      )

      expect(signup_b.reload.waitlisted_at).to eq(
        initial_time + 10.minutes
      )

      expect(signup_c.reload.waitlisted_at).to eq(
        initial_time + 20.minutes
      )

      # 5. 检查候补队列是否按照时间而不是 ID 排序
      expect(shift.waitlist_queue.to_a).to eq(
        [signup_a, signup_b, signup_c]
      )

      # 6. 检查候补队列人数
      expect(shift.waitlist_queue.count).to eq(3)
    end

    # Test 3: 排除 confirmed 和 cancelled 报名记录
    it "includes only waitlisted signups in the queue" do
      # 1. 创建正式报名记录
      confirmed_signup = Signup.create!(
        user: volunteer_a,
        shift: shift,
        status: "confirmed"
      )

      # 2. 创建已取消报名记录
      cancelled_signup = Signup.create!(
        user: volunteer_b,
        shift: shift,
        status: "cancelled"
      )

      # 3. 创建候补报名记录
      waitlisted_signup = create_waitlisted_signup(
        user: volunteer_c,
        shift: shift,
        time: initial_time
      )

      # 4. 检查班次拥有三条报名记录
      expect(shift.signups.count).to eq(3)

      # 5. 检查候补队列仅包含 waitlisted 报名
      expect(shift.waitlist_queue.to_a).to eq(
        [waitlisted_signup]
      )

      # 6. 检查正式报名不在候补队列中
      expect(shift.waitlist_queue).not_to include(
        confirmed_signup
      )

      # 7. 检查已取消报名不在候补队列中
      expect(shift.waitlist_queue).not_to include(
        cancelled_signup
      )
    end

    # Test 4: 候补时间相同时按照 ID 排序
    it "orders signups by id when waitlisted_at values are identical" do
      # 1. 在相同时间创建第一条候补记录
      signup_a = create_waitlisted_signup(
        user: volunteer_a,
        shift: shift,
        time: initial_time
      )

      # 2. 在相同时间创建第二条候补记录
      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time
      )

      # 3. 在相同时间创建第三条候补记录
      signup_c = create_waitlisted_signup(
        user: volunteer_c,
        shift: shift,
        time: initial_time
      )

      # 4. 检查三条记录的候补时间完全相同
      expect(signup_a.waitlisted_at).to eq(initial_time)
      expect(signup_b.waitlisted_at).to eq(initial_time)
      expect(signup_c.waitlisted_at).to eq(initial_time)

      # 5. 检查报名记录的 ID 顺序
      expect(signup_a.id).to be < signup_b.id
      expect(signup_b.id).to be < signup_c.id

      # 6. 检查候补队列是否按照 ID 升序排序
      expect(shift.waitlist_queue.to_a).to eq(
        [signup_a, signup_b, signup_c]
      )
    end

    # Test 5: 不包含其他班次的候补记录
    it "does not include waitlisted signups from other shifts" do
      # 1. 为当前班次创建候补报名
      signup_a = create_waitlisted_signup(
        user: volunteer_a,
        shift: shift,
        time: initial_time + 10.minutes
      )

      # 2. 为另一个班次创建更早的候补报名
      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: other_shift,
        time: initial_time
      )

      # 3. 检查数据库拥有两条候补报名记录
      expect(
        Signup.where(status: "waitlisted").count
      ).to eq(2)

      # 4. 检查当前班次的候补队列
      expect(shift.waitlist_queue.to_a).to eq(
        [signup_a]
      )

      # 5. 检查另一个班次的候补队列
      expect(other_shift.waitlist_queue.to_a).to eq(
        [signup_b]
      )

      # 6. 检查两个候补队列是否相互独立
      expect(shift.waitlist_queue).not_to include(
        signup_b
      )

      expect(other_shift.waitlist_queue).not_to include(
        signup_a
      )
    end

    # Test 6: 取消候补报名后从队列中移除
    it "removes a cancelled signup from the waitlist queue" do
      # 1. 创建第一条候补记录
      signup_a = create_waitlisted_signup(
        user: volunteer_a,
        shift: shift,
        time: initial_time
      )

      # 2. 创建第二条候补记录
      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time + 10.minutes
      )

      # 3. 检查原有候补队列顺序
      expect(shift.waitlist_queue.to_a).to eq(
        [signup_a, signup_b]
      )

      # 4. 模拟第一个 Volunteer 取消候补报名
      signup_a.update!(status: "cancelled")

      # 5. 检查报名状态和候补时间
      expect(signup_a.reload.status).to eq("cancelled")
      expect(signup_a.waitlisted_at).to be_nil

      # 6. 检查已取消报名是否从队列中移除
      expect(shift.waitlist_queue.to_a).to eq(
        [signup_b]
      )

      # 7. 检查候补队列人数是否减少
      expect(shift.waitlist_queue.count).to eq(1)

      # 8. 检查原有报名记录没有被删除
      expect(shift.signups.count).to eq(2)
    end

    # Test 7: 取消后重新候补时排到队尾
    it "places a returning waitlisted volunteer at the end of the queue" do
      # 1. 让 Volunteer D 占用唯一正式名额
      confirmed_signup = SignupService.call(
        user: volunteer_d,
        shift: shift
      )

      # 2. 检查班次是否已经满员
      expect(confirmed_signup.reload.status).to eq(
        "confirmed"
      )

      expect(shift.full?).to be true

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

      # 5. 创建 Volunteer C 的候补报名
      signup_c = create_waitlisted_signup(
        user: volunteer_c,
        shift: shift,
        time: initial_time + 20.minutes
      )

      # 6. 检查原有候补队列顺序
      expect(shift.waitlist_queue.to_a).to eq(
        [signup_a, signup_b, signup_c]
      )

      # 7. 保存 Volunteer A 原有报名记录的信息
      original_id = signup_a.id
      original_created_at = signup_a.created_at
      original_waitlisted_at = signup_a.waitlisted_at

      # 8. 模拟 Volunteer A 取消候补报名
      travel_to(initial_time + 25.minutes) do
        signup_a.update!(status: "cancelled")
      end

      # 9. 检查 Volunteer A 是否已经离开候补队列
      expect(shift.waitlist_queue.to_a).to eq(
        [signup_b, signup_c]
      )

      # 10. 初始化用于保存重新报名结果的变量
      returning_signup = nil

      # 11. 在更晚的时间通过 SignupService 重新报名
      travel_to(initial_time + 30.minutes) do

        # 检查重新报名不会创建新的记录
        expect {
          returning_signup = SignupService.call(
            user: volunteer_a,
            shift: shift
          )
        }.not_to change(Signup, :count)
      end

      # 12. 检查重新报名是否成功
      expect(returning_signup).to be_persisted
      expect(returning_signup.errors).to be_empty

      # 13. 从数据库重新读取报名记录
      returning_signup.reload

      # 14. 检查重新报名是否复用原有记录
      expect(returning_signup.id).to eq(original_id)

      # 15. 检查原有创建时间是否保持不变
      expect(returning_signup.created_at).to eq(
        original_created_at
      )

      # 16. 检查重新报名后的状态
      expect(returning_signup.status).to eq(
        "waitlisted"
      )

      # 17. 检查系统是否记录新的候补时间
      expect(returning_signup.waitlisted_at).to eq(
        initial_time + 30.minutes
      )

      # 18. 检查新的候补时间是否晚于原有时间
      expect(returning_signup.waitlisted_at).to be >
        original_waitlisted_at

      # 19. 检查 Volunteer A 是否排到了队尾
      expect(shift.waitlist_queue.to_a).to eq(
        [signup_b, signup_c, returning_signup]
      )

      # 20. 检查候补队列人数是否恢复为 3
      expect(shift.waitlist_queue.count).to eq(3)

      # 21. 检查正式报名人数是否保持不变
      expect(shift.confirmed_count).to eq(1)

      # 22. 检查班次是否仍然满员
      expect(shift.full?).to be true
    end

    # Test 8: 候补转正后从队列中移除
    it "removes a promoted signup from the waitlist queue" do
      # 1. 创建第一条候补报名
      signup_a = create_waitlisted_signup(
        user: volunteer_a,
        shift: shift,
        time: initial_time
      )

      # 2. 创建第二条候补报名
      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time + 10.minutes
      )

      # 3. 检查原有候补队列顺序
      expect(shift.waitlist_queue.to_a).to eq(
        [signup_a, signup_b]
      )

      # 4. 检查班次是否拥有一个空余名额
      expect(shift.available_slots).to eq(1)

      # 5. 模拟第一位候补用户成功转正
      signup_a.update!(status: "confirmed")

      # 6. 检查报名状态是否变为 confirmed
      expect(signup_a.reload.status).to eq(
        "confirmed"
      )

      # 7. 检查候补时间是否已经清空
      expect(signup_a.waitlisted_at).to be_nil

      # 8. 检查已转正用户是否离开候补队列
      expect(shift.waitlist_queue.to_a).to eq(
        [signup_b]
      )

      # 9. 检查候补队列人数是否减少
      expect(shift.waitlist_queue.count).to eq(1)

      # 10. 检查正式报名人数是否增加
      expect(shift.confirmed_count).to eq(1)

      # 11. 检查班次是否已经满员
      expect(shift.full?).to be true

      # 12. 检查总报名记录数量是否保持不变
      expect(shift.signups.count).to eq(2)
    end
  end
end
