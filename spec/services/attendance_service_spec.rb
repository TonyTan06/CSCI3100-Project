
require 'rails_helper'

RSpec.describe AttendanceService do

  # ==================================================
  # 公共测试数据
  # ==================================================

  # 创建主要 Organization
  let(:organization) do
    Organization.create!(
      name: "CUHK Volunteer Team"
    )
  end

  # 创建另一个 Organization
  let(:other_organization) do
    Organization.create!(
      name: "CUHK Community Service"
    )
  end

  # 创建主要 Activity
  let(:activity) do
    Activity.create!(
      title: "Campus Cleaning",
      description: "Campus cleaning volunteer activity",
      location: "CUHK Campus",
      organization: organization
    )
  end

  # 创建主要 Organizer
  let(:organizer) do
    User.create!(
      email_address: "organizer@example.com",
      password: "password123",
      role: "organizer",
      organization: organization
    )
  end

  # 创建其他组织的 Organizer
  let(:other_organizer) do
    User.create!(
      email_address: "other_organizer@example.com",
      password: "password123",
      role: "organizer",
      organization: other_organization
    )
  end

  # 创建主要 Volunteer
  let(:volunteer) do
    create_volunteer("volunteer@example.com")
  end

  # 创建另一个 Volunteer
  let(:other_volunteer) do
    create_volunteer("other_volunteer@example.com")
  end

  # 设置班次开始时间
  let(:start_time) do
    Time.current.change(usec: 0) + 1.day
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

  # 创建主要正式报名记录
  let(:signup) do
    Signup.create!(
      user: volunteer,
      shift: shift,
      status: "confirmed",
      attendance_status: "pending"
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

  # ==================================================
  # 出勤管理测试
  # ==================================================

  describe ".call" do

    # Test 1: Organizer 可以标记 Volunteer 已出勤
    it "allows an organizer to mark a confirmed volunteer as present" do

      expect(signup.attendance_status).to eq("pending")

      original_id = signup.id
      original_created_at = signup.created_at

      result = AttendanceService.call(
        user: organizer,
        signup: signup,
        attendance_status: "present"
      )

      # 检查修改成功
      expect(result).to be_a(Signup)
      expect(result).to be_persisted
      expect(result.errors).to be_empty

      # 检查数据库中的出勤状态
      expect(result.reload.attendance_status).to eq(
        "present"
      )

      # 检查报名状态保持不变
      expect(result.status).to eq("confirmed")

      # 检查原有报名记录没有被替换
      expect(result.id).to eq(original_id)
      expect(result.created_at).to eq(
        original_created_at
      )
    end

    # Test 2: Organizer 可以标记 Volunteer 缺席
    it "allows an organizer to mark a confirmed volunteer as absent" do

      result = AttendanceService.call(
        user: organizer,
        signup: signup,
        attendance_status: "absent"
      )

      expect(result.errors).to be_empty

      expect(signup.reload.attendance_status).to eq(
        "absent"
      )

      expect(signup.status).to eq("confirmed")
    end

    # Test 3: Organizer 可以将缺席修正为已出勤
    it "allows an organizer to correct absent attendance to present" do

      signup.update!(
        attendance_status: "absent"
      )

      result = AttendanceService.call(
        user: organizer,
        signup: signup,
        attendance_status: "present"
      )

      expect(result.errors).to be_empty

      expect(signup.reload.attendance_status).to eq(
        "present"
      )

      expect(signup.status).to eq("confirmed")
    end

    # Test 4: Organizer 可以将已出勤修正为缺席
    it "allows an organizer to correct present attendance to absent" do

      signup.update!(
        attendance_status: "present"
      )

      result = AttendanceService.call(
        user: organizer,
        signup: signup,
        attendance_status: "absent"
      )

      expect(result.errors).to be_empty

      expect(signup.reload.attendance_status).to eq(
        "absent"
      )

      expect(signup.status).to eq("confirmed")
    end

    # Test 5: Organizer 可以将出勤状态重置为 pending
    it "allows an organizer to reset attendance to pending" do

      signup.update!(
        attendance_status: "present"
      )

      result = AttendanceService.call(
        user: organizer,
        signup: signup,
        attendance_status: "pending"
      )

      expect(result.errors).to be_empty

      expect(signup.reload.attendance_status).to eq(
        "pending"
      )

      expect(signup.status).to eq("confirmed")
    end

    # Test 6: 禁止 Volunteer 修改出勤状态
    it "rejects attendance updates from volunteers" do

      original_updated_at = signup.updated_at

      result = AttendanceService.call(
        user: volunteer,
        signup: signup,
        attendance_status: "present"
      )

      # 检查角色验证错误
      expect(result.errors[:base]).to include(
        "must be an organizer"
      )

      # 检查数据库记录保持不变
      expect(signup.reload.attendance_status).to eq(
        "pending"
      )

      expect(signup.updated_at).to eq(
        original_updated_at
      )
    end

    # Test 7: 禁止 Organizer 修改其他组织的出勤记录
    it "rejects attendance updates for signups belonging to another organization" do

      original_updated_at = signup.updated_at

      result = AttendanceService.call(
        user: other_organizer,
        signup: signup,
        attendance_status: "present"
      )

      # 检查组织隔离验证错误
      expect(result.errors[:base]).to include(
        "can only manage attendance for their own organization"
      )

      expect(signup.reload.attendance_status).to eq(
        "pending"
      )

      expect(signup.updated_at).to eq(
        original_updated_at
      )
    end

    # Test 8: 禁止修改候补用户的出勤状态
    it "rejects attendance updates for waitlisted signups" do

      waitlisted_signup = Signup.create!(
        user: volunteer,
        shift: shift,
        status: "waitlisted"
      )

      original_updated_at =
        waitlisted_signup.updated_at

      original_waitlisted_at =
        waitlisted_signup.waitlisted_at

      result = AttendanceService.call(
        user: organizer,
        signup: waitlisted_signup,
        attendance_status: "present"
      )

      # 仅允许正式报名用户记录出勤
      expect(result.errors[:status]).to include(
        "must be confirmed to manage attendance"
      )

      waitlisted_signup.reload

      expect(waitlisted_signup.status).to eq(
        "waitlisted"
      )

      expect(
        waitlisted_signup.attendance_status
      ).to eq("pending")

      expect(waitlisted_signup.updated_at).to eq(
        original_updated_at
      )

      expect(waitlisted_signup.waitlisted_at).to eq(
        original_waitlisted_at
      )
    end

    # Test 9: 禁止修改已取消报名用户的出勤状态
    it "rejects attendance updates for cancelled signups" do

      cancelled_signup = Signup.create!(
        user: volunteer,
        shift: shift,
        status: "cancelled"
      )

      original_updated_at =
        cancelled_signup.updated_at

      result = AttendanceService.call(
        user: organizer,
        signup: cancelled_signup,
        attendance_status: "absent"
      )

      expect(result.errors[:status]).to include(
        "must be confirmed to manage attendance"
      )

      cancelled_signup.reload

      expect(cancelled_signup.status).to eq(
        "cancelled"
      )

      expect(
        cancelled_signup.attendance_status
      ).to eq("pending")

      expect(cancelled_signup.updated_at).to eq(
        original_updated_at
      )
    end

    # Test 10: 禁止设置非法出勤状态
    it "rejects invalid attendance status values" do

      original_updated_at = signup.updated_at

      result = AttendanceService.call(
        user: organizer,
        signup: signup,
        attendance_status: "late"
      )

      # 复用 Signup Model 的 inclusion 验证
      expect(
        result.errors.of_kind?(
          :attendance_status,
          :inclusion
        )
      ).to be true

      # 数据库中的原有状态必须保持不变
      expect(signup.reload.attendance_status).to eq(
        "pending"
      )

      expect(signup.updated_at).to eq(
        original_updated_at
      )
    end

    # Test 11: 禁止设置空出勤状态
    it "rejects nil attendance status" do

      result = AttendanceService.call(
        user: organizer,
        signup: signup,
        attendance_status: nil
      )

      expect(
        result.errors.of_kind?(
          :attendance_status,
          :inclusion
        )
      ).to be true

      expect(signup.reload.attendance_status).to eq(
        "pending"
      )
    end

    # Test 12: 出勤修改不影响报名状态、容量及候补队列
    it "does not affect signup status, capacity or waitlist when attendance changes" do

      # 1. 创建正式报名并占用唯一名额
      confirmed_signup = signup

      # 2. 创建另一个 Volunteer 的候补报名
      waitlisted_signup = SignupService.call(
        user: other_volunteer,
        shift: shift
      )

      expect(waitlisted_signup).to be_persisted

      expect(waitlisted_signup.status).to eq(
        "waitlisted"
      )

      # 3. 保存原有候补信息
      original_waitlisted_at =
        waitlisted_signup.waitlisted_at

      original_waitlisted_updated_at =
        waitlisted_signup.updated_at

      expect(shift.full?).to be true

      # 4. 修改出勤状态不得触发自动递补
      expect(WaitlistService).not_to receive(:call)

      result = nil

      expect {
        result = AttendanceService.call(
          user: organizer,
          signup: confirmed_signup,
          attendance_status: "absent"
        )
      }.not_to change(Signup, :count)

      # 5. 检查出勤修改成功
      expect(result.errors).to be_empty

      expect(
        confirmed_signup.reload.attendance_status
      ).to eq("absent")

      # 6. 检查正式报名状态保持不变
      expect(confirmed_signup.status).to eq(
        "confirmed"
      )

      # 7. 检查候补报名状态保持不变
      expect(waitlisted_signup.reload.status).to eq(
        "waitlisted"
      )

      expect(waitlisted_signup.waitlisted_at).to eq(
        original_waitlisted_at
      )

      expect(waitlisted_signup.updated_at).to eq(
        original_waitlisted_updated_at
      )

      # 8. 检查班次容量及候补队列保持不变
      expect(shift.reload.capacity).to eq(1)
      expect(shift.confirmed_count).to eq(1)
      expect(shift.available_slots).to eq(0)
      expect(shift.full?).to be true

      expect(shift.waitlist_queue.to_a).to eq(
        [waitlisted_signup]
      )
    end
  end
end
