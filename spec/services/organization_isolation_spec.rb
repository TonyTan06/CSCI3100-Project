
require 'rails_helper'

RSpec.describe "Service organization isolation" do
  # ==================================================
  # 公共测试数据
  # ==================================================

  # 创建两个不同的 Organization
  let(:organization_a) do
    Organization.create!(
      name: "CUHK Volunteer Team"
    )
  end

  let(:organization_b) do
    Organization.create!(
      name: "CUHK Community Service"
    )
  end

  # 创建 Organization A 的 Organizer
  let(:organizer_a) do
    User.create!(
      email_address: "organizer_a@example.com",
      password: "password123",
      role: "organizer",
      organization: organization_a
    )
  end

  # 创建 Organization B 的 Organizer
  let(:organizer_b) do
    User.create!(
      email_address: "organizer_b@example.com",
      password: "password123",
      role: "organizer",
      organization: organization_b
    )
  end

  # 创建 Volunteer
  let(:volunteer) do
    User.create!(
      email_address: "volunteer@example.com",
      password: "password123",
      role: "volunteer"
    )
  end

  # 创建 Organization A 的活动
  let(:activity_a) do
    Activity.create!(
      title: "Campus Cleaning",
      description: "Campus cleaning volunteer activity",
      location: "CUHK Campus",
      organization: organization_a
    )
  end

  # 创建 Organization B 的活动
  let(:activity_b) do
    Activity.create!(
      title: "Community Service",
      description: "Community volunteer activity",
      location: "Sha Tin",
      organization: organization_b
    )
  end

  # 设置班次开始时间
  let(:start_time) do
    Time.current.change(usec: 0) + 1.day
  end

  # 创建 Organization A 的班次
  let(:shift_a) do
    Shift.create!(
      activity: activity_a,
      start_time: start_time,
      end_time: start_time + 3.hours,
      capacity: 10
    )
  end

  # 创建 Organization B 的班次
  let(:shift_b) do
    Shift.create!(
      activity: activity_b,
      start_time: start_time + 4.hours,
      end_time: start_time + 7.hours,
      capacity: 10
    )
  end

  # ==================================================
  # 非法属性修改测试
  # ==================================================

  describe "protected attributes" do
    # Test 1: 禁止修改 Shift 所属 Activity
    it "prevents changing the activity of an existing shift" do
      result = ShiftUpdateService.call(
        user: organizer_a,
        shift: shift_a,
        attributes: {
          capacity: 15,
          activity_id: activity_b.id,
          activity: activity_b
        }
      )

      # 合法属性可以修改
      expect(result.errors).to be_empty
      expect(shift_a.reload.capacity).to eq(15)

      # 班次所属活动必须保持不变
      expect(shift_a.activity).to eq(activity_a)

      # 班次所属组织必须保持不变
      expect(
        shift_a.activity.organization
      ).to eq(organization_a)

      expect(activity_b.shifts).not_to include(
        shift_a
      )
    end

    # Test 2: 禁止修改 Shift 的 ID
    it "prevents changing the identity of an existing shift" do
      original_id = shift_a.id
      other_shift_id = shift_b.id

      result = ShiftUpdateService.call(
        user: organizer_a,
        shift: shift_a,
        attributes: {
          capacity: 15,
          id: other_shift_id
        }
      )

      expect(result.errors).to be_empty

      # 检查原有班次 ID 保持不变
      expect(result.reload.id).to eq(original_id)

      # 检查合法属性成功修改
      expect(result.capacity).to eq(15)

      # 检查其他组织的班次没有被修改
      expect(shift_b.reload.id).to eq(other_shift_id)
      expect(shift_b.capacity).to eq(10)
      expect(shift_b.activity).to eq(activity_b)
    end

    # Test 3: 非法修改失败时保留原有数据
    it "preserves stored data when an invalid update includes protected attributes" do
      original_capacity = shift_a.capacity
      original_activity_id = shift_a.activity_id
      original_updated_at = shift_a.updated_at

      result = ShiftUpdateService.call(
        user: organizer_a,
        shift: shift_a,
        attributes: {
          capacity: -10,
          activity_id: activity_b.id
        }
      )

      # 检查非法容量被拒绝
      expect(result.errors[:capacity]).not_to be_empty

      # 检查数据库中的原有数据保持不变
      shift_a.reload

      expect(shift_a.capacity).to eq(
        original_capacity
      )

      expect(shift_a.activity_id).to eq(
        original_activity_id
      )

      expect(shift_a.updated_at).to eq(
        original_updated_at
      )
    end

    # Test 4: 字符串类型参数也不能绕过属性过滤
    it "filters protected attributes when attribute keys are strings" do
      result = ShiftUpdateService.call(
        user: organizer_a,
        shift: shift_a,
        attributes: {
          "capacity" => "15",
          "activity_id" => activity_b.id.to_s,
          "id" => shift_b.id.to_s
        }
      )

      expect(result.errors).to be_empty

      shift_a.reload

      # 合法属性成功修改
      expect(shift_a.capacity).to eq(15)

      # 非法属性被过滤
      expect(shift_a.activity).to eq(activity_a)
      expect(shift_a.id).not_to eq(shift_b.id)

      # 其他班次不受影响
      expect(shift_b.reload.capacity).to eq(10)
    end
  end

  # ==================================================
  # 跨组织业务权限测试
  # ==================================================

  describe "cross-organization permissions" do
    # Test 5: Volunteer 可以参加不同组织的活动
    it "allows volunteers to sign up for shifts across organizations" do
      signup_a = SignupService.call(
        user: volunteer,
        shift: shift_a
      )

      signup_b = SignupService.call(
        user: volunteer,
        shift: shift_b
      )

      # 两次报名均应成功
      expect(signup_a).to be_persisted
      expect(signup_b).to be_persisted

      expect(signup_a.errors).to be_empty
      expect(signup_b.errors).to be_empty

      expect(signup_a.reload.status).to eq(
        "confirmed"
      )

      expect(signup_b.reload.status).to eq(
        "confirmed"
      )

      # 两条报名记录属于不同的 Organization
      expect(
        signup_a.shift.activity.organization
      ).to eq(organization_a)

      expect(
        signup_b.shift.activity.organization
      ).to eq(organization_b)

      # 两个班次分别占用一个名额
      expect(shift_a.confirmed_count).to eq(1)
      expect(shift_b.confirmed_count).to eq(1)

      expect(volunteer.signups.count).to eq(2)
    end

    # Test 6: Organizer 只能管理自己组织活动的出勤
    it "authorizes attendance based on the activity organization" do
      # Volunteer 同时参加两个组织的活动
      signup_a = SignupService.call(
        user: volunteer,
        shift: shift_a
      )

      signup_b = SignupService.call(
        user: volunteer,
        shift: shift_b
      )

      # Organizer A 管理自己组织的出勤
      result_a = AttendanceService.call(
        user: organizer_a,
        signup: signup_a,
        attendance_status: "present"
      )

      expect(result_a.errors).to be_empty

      expect(
        signup_a.reload.attendance_status
      ).to eq("present")

      # Organizer A 尝试管理 Organization B 的出勤
      unauthorized_result = AttendanceService.call(
        user: organizer_a,
        signup: signup_b,
        attendance_status: "absent"
      )

      expect(
        unauthorized_result.errors[:base]
      ).to include(
        "can only manage attendance for their own organization"
      )

      # 未授权的操作不能修改数据库
      expect(
        signup_b.reload.attendance_status
      ).to eq("pending")

      # Organizer B 可以管理自己组织的出勤
      result_b = AttendanceService.call(
        user: organizer_b,
        signup: signup_b,
        attendance_status: "present"
      )

      expect(result_b.errors).to be_empty

      expect(
        signup_b.reload.attendance_status
      ).to eq("present")

      # 两个班次的报名状态均保持不变
      expect(signup_a.reload.status).to eq("confirmed")
      expect(signup_b.reload.status).to eq("confirmed")
    end
  end
end
