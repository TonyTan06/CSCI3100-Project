
require 'rails_helper'

RSpec.describe Signup, type: :model do
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

  # 设置测试使用的第一个时间点
  let(:initial_time) do
    Time.current.change(usec: 0)
  end

  # 设置十分钟后的时间点
  let(:later_time) do
    initial_time + 10.minutes
  end

  # 设置班次开始时间
  let(:start_time) do
    initial_time + 1.day
  end

  # 创建一个容量为 1 的 Shift
  let(:shift) do
    Shift.create!(
      activity: activity,
      start_time: start_time,
      end_time: start_time + 3.hours,
      capacity: 1
    )
  end

  # 创建主要 Volunteer
  let(:volunteer) do
    User.create!(
      email_address: "volunteer@example.com",
      password: "password123",
      role: "volunteer"
    )
  end

  # 创建另一个 Volunteer
  let(:other_volunteer) do
    User.create!(
      email_address: "other_volunteer@example.com",
      password: "password123",
      role: "volunteer"
    )
  end

  # 创建一条已有候补时间的报名记录
  # 手动提供初始候补时间，用于独立测试后续状态变化
  let(:waitlisted_signup) do
    travel_to(initial_time) do
      Signup.create!(
        user: volunteer,
        shift: shift,
        status: "waitlisted",
        waitlisted_at: initial_time
      )
    end
  end

  # ==================================================
  # 候补时间管理测试
  # ==================================================

  describe "waitlist timestamp management" do

    # Test 1: 首次正式报名不记录候补时间
    it "does not set waitlisted_at for a confirmed signup" do
      # 1. 创建一条正式报名记录
      signup = Signup.create!(
        user: volunteer,
        shift: shift,
        status: "confirmed"
      )

      # 2. 检查报名是否成功保存
      expect(signup).to be_persisted

      # 3. 检查报名状态是否为 confirmed
      expect(signup.reload.status).to eq("confirmed")

      # 4. 检查正式报名是否没有候补时间
      expect(signup.waitlisted_at).to be_nil
    end

    # Test 2: 首次候补报名自动记录当前时间
    it "automatically sets waitlisted_at for a new waitlisted signup" do
      # 1. 将系统时间固定在 initial_time
      travel_to(initial_time) do

        # 2. 创建一条候补报名记录
        # 不手动提供 waitlisted_at
        signup = Signup.create!(
          user: volunteer,
          shift: shift,
          status: "waitlisted"
        )

        # 3. 检查报名是否成功保存
        expect(signup).to be_persisted

        # 4. 检查报名状态是否为 waitlisted
        expect(signup.reload.status).to eq("waitlisted")

        # 5. 检查系统是否自动记录候补时间
        expect(signup.waitlisted_at).to eq(initial_time)
      end
    end

    # Test 3: 候补状态不变时保留原有候补时间
    it "preserves waitlisted_at when the signup remains waitlisted" do
      # 1. 创建一条已有候补时间的报名记录
      signup = waitlisted_signup

      # 2. 保存原有候补时间
      original_waitlisted_at = signup.reload.waitlisted_at

      # 3. 检查原有候补时间是否正确
      expect(original_waitlisted_at).to eq(initial_time)

      # 4. 将系统时间移动到十分钟后
      travel_to(later_time) do

        # 5. 在不改变报名状态的情况下再次保存
        signup.update!(status: "waitlisted")

        # 6. 检查报名状态是否仍然为 waitlisted
        expect(signup.reload.status).to eq("waitlisted")

        # 7. 检查原有候补时间是否保持不变
        expect(signup.waitlisted_at).to eq(
          original_waitlisted_at
        )
      end
    end

    # Test 4: 取消候补报名后清空候补时间
    it "clears waitlisted_at when a waitlisted signup is cancelled" do
      # 1. 创建一条已有候补时间的报名记录
      signup = waitlisted_signup

      # 2. 检查原有候补时间是否存在
      expect(signup.reload.waitlisted_at).to eq(initial_time)

      # 3. 取消候补报名
      signup.update!(status: "cancelled")

      # 4. 检查报名状态是否为 cancelled
      expect(signup.reload.status).to eq("cancelled")

      # 5. 检查原有候补时间是否已清空
      expect(signup.waitlisted_at).to be_nil
    end

    # Test 5: 候补转为正式报名后清空候补时间
    it "clears waitlisted_at when a waitlisted signup is confirmed" do
      # 1. 创建一条已有候补时间的报名记录
      signup = waitlisted_signup

      # 2. 检查原有候补时间是否存在
      expect(signup.reload.waitlisted_at).to eq(initial_time)

      # 3. 检查班次是否拥有空余名额
      expect(shift.available_slots).to eq(1)

      # 4. 将候补报名转为正式报名
      signup.update!(status: "confirmed")

      # 5. 检查报名状态是否为 confirmed
      expect(signup.reload.status).to eq("confirmed")

      # 6. 检查原有候补时间是否已清空
      expect(signup.waitlisted_at).to be_nil

      # 7. 检查正式报名是否成功占用名额
      expect(shift.confirmed_count).to eq(1)
      expect(shift.available_slots).to eq(0)
    end

    # Test 6: 取消报名后重新候补时记录新的时间
    it "resets waitlisted_at when a cancelled signup rejoins the waitlist" do
      # 1. 创建一条已有候补时间的报名记录
      signup = waitlisted_signup

      # 2. 保存原有报名记录的 ID 和创建时间
      original_id = signup.id
      original_created_at = signup.created_at
      original_waitlisted_at = signup.waitlisted_at

      # 3. 取消候补报名
      signup.update!(status: "cancelled")

      # 4. 检查报名状态是否为 cancelled
      expect(signup.reload.status).to eq("cancelled")

      # 5. 将系统时间移动到十分钟后
      travel_to(later_time) do

        # 6. 重新加入候补队列
        signup.update!(status: "waitlisted")

        # 7. 检查报名状态是否为 waitlisted
        expect(signup.reload.status).to eq("waitlisted")

        # 8. 检查系统是否记录了新的候补时间
        expect(signup.waitlisted_at).to eq(later_time)

        # 9. 检查新的候补时间是否晚于原有时间
        expect(signup.waitlisted_at).to be > original_waitlisted_at

        # 10. 检查报名记录是否保持原有 ID
        expect(signup.id).to eq(original_id)

        # 11. 检查原有创建时间是否保持不变
        expect(signup.created_at).to eq(original_created_at)
      end
    end

    # Test 7: 正式报名转为候补时自动记录时间
    it "sets waitlisted_at when a confirmed signup becomes waitlisted" do
      # 1. 创建一条正式报名记录
      signup = Signup.create!(
        user: volunteer,
        shift: shift,
        status: "confirmed"
      )

      # 2. 检查正式报名没有候补时间
      expect(signup.reload.waitlisted_at).to be_nil

      # 3. 将系统时间移动到十分钟后
      travel_to(later_time) do

        # 4. 将报名状态修改为 waitlisted
        signup.update!(status: "waitlisted")

        # 5. 检查报名状态是否为 waitlisted
        expect(signup.reload.status).to eq("waitlisted")

        # 6. 检查系统是否自动记录进入候补队列的时间
        expect(signup.waitlisted_at).to eq(later_time)

        # 7. 检查原有正式名额是否已经释放
        expect(shift.confirmed_count).to eq(0)
        expect(shift.available_slots).to eq(1)
      end
    end

    # Test 8: 重复候补报名失败不会改变原有候补时间
    it "preserves the original waitlisted_at when a duplicate signup is rejected" do
      # 1. 让另一个 Volunteer 占用正式名额
      other_signup = Signup.create!(
        user: other_volunteer,
        shift: shift,
        status: "confirmed"
      )

      # 2. 检查班次是否已经满员
      expect(other_signup).to be_persisted
      expect(shift.full?).to be true

      # 3. 创建一条已有候补时间的报名记录
      signup = waitlisted_signup

      # 4. 保存原有候补时间和更新时间
      original_waitlisted_at = signup.reload.waitlisted_at
      original_updated_at = signup.updated_at

      # 5. 将系统时间移动到十分钟后
      travel_to(later_time) do

        # 6. 尝试重复加入候补队列
        duplicate_signup = nil

        expect {
          duplicate_signup = SignupService.call(
            user: volunteer,
            shift: shift
          )
        }.not_to change(Signup, :count)

        # 7. 检查重复报名是否被拒绝
        expect(duplicate_signup).not_to be_persisted

        # 8. 检查是否返回重复报名错误
        expect(
          duplicate_signup.errors.of_kind?(:user_id, :taken)
        ).to be true

        # 9. 从数据库重新读取原有报名记录
        signup.reload

        # 10. 检查原有候补时间是否保持不变
        expect(signup.waitlisted_at).to eq(
          original_waitlisted_at
        )

        # 11. 检查原有更新时间是否保持不变
        expect(signup.updated_at).to eq(
          original_updated_at
        )

        # 12. 检查原有报名状态是否保持不变
        expect(signup.status).to eq("waitlisted")

        # 13. 检查班次报名数量是否保持不变
        expect(shift.confirmed_count).to eq(1)

        expect(
          shift.signups.where(status: "waitlisted").count
        ).to eq(1)
      end
    end
  end
end
