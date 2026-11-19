
require 'rails_helper'

RSpec.describe Signup, type: :model do
  describe "validations" do

    # Test 1: 报名记录必须属于一个 User
    it "requires a user" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建班次所属的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 设置班次的开始时间
      start_time = 1.day.from_now

      # 4. 创建一个合法的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 5. 创建一个没有所属 User 的 Signup
      signup = Signup.new(
        shift: shift,
        status: "confirmed",
        attendance_status: "pending"
      )

      # 6. 检查 Signup 是否无法通过验证
      expect(signup).not_to be_valid

      # 7. 检查错误是否来自 user 字段
      expect(signup.errors[:user]).to include("must exist")
    end

    # Test 2: 报名记录必须属于一个 Shift
    it "requires a shift" do
      # 1. 创建一个合法的 Volunteer 用户
      volunteer = User.create!(
        email_address: "volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 2. 创建一个没有所属 Shift 的 Signup
      signup = Signup.new(
        user: volunteer,
        status: "confirmed",
        attendance_status: "pending"
      )

      # 3. 检查 Signup 是否无法通过验证
      expect(signup).not_to be_valid

      # 4. 检查错误是否来自 shift 字段
      expect(signup.errors[:shift]).to include("must exist")
    end

    # Test 3: 报名记录必须拥有状态
    it "requires a status" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建班次所属的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 设置班次的开始时间
      start_time = 1.day.from_now

      # 4. 创建一个合法的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 5. 创建一个合法的 Volunteer 用户
      volunteer = User.create!(
        email_address: "volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 6. 创建一个没有报名状态的 Signup
      signup = Signup.new(
        user: volunteer,
        shift: shift,
        status: nil,
        attendance_status: "pending"
      )

      # 7. 检查 Signup 是否无法通过验证
      expect(signup).not_to be_valid

      # 8. 检查错误是否来自 status 字段
      expect(signup.errors[:status]).to include("can't be blank")
    end

    # Test 4: 拒绝无效的报名状态
    it "rejects invalid signup statuses" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建班次所属的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 设置班次的开始时间
      start_time = 1.day.from_now

      # 4. 创建一个合法的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 5. 创建一个合法的 Volunteer 用户
      volunteer = User.create!(
        email_address: "volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 6. 创建一个报名状态无效的 Signup
      signup = Signup.new(
        user: volunteer,
        shift: shift,
        status: "unknown",
        attendance_status: "pending"
      )

      # 7. 检查 Signup 是否无法通过验证
      expect(signup).not_to be_valid

      # 8. 检查错误是否来自 status 字段
      expect(signup.errors[:status]).to include("is not included in the list")
    end

    # Test 5: 报名记录的默认出勤状态为 pending
    it "assigns pending as the default attendance status" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建班次所属的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 设置班次的开始时间
      start_time = 1.day.from_now

      # 4. 创建一个合法的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 5. 创建一个合法的 Volunteer 用户
      volunteer = User.create!(
        email_address: "volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 6. 创建一个未指定出勤状态的 Signup
      signup = Signup.create!(
        user: volunteer,
        shift: shift,
        status: "confirmed"
      )

      # 7. 从数据库重新读取 Signup
      signup.reload

      # 8. 检查默认出勤状态是否为 pending
      expect(signup.attendance_status).to eq("pending")
    end

    # Test 6: 拒绝无效的出勤状态
    it "rejects invalid attendance statuses" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建班次所属的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 设置班次的开始时间
      start_time = 1.day.from_now

      # 4. 创建一个合法的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 5. 创建一个合法的 Volunteer 用户
      volunteer = User.create!(
        email_address: "volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 6. 创建一个出勤状态无效的 Signup
      signup = Signup.new(
        user: volunteer,
        shift: shift,
        status: "confirmed",
        attendance_status: "unknown"
      )

      # 7. 检查 Signup 是否无法通过验证
      expect(signup).not_to be_valid

      # 8. 检查错误是否来自 attendance_status 字段
      expect(signup.errors[:attendance_status]).to include("is not included in the list")

      # 9. 将出勤状态修改为空
      signup.attendance_status = nil

      # 10. 检查 Signup 是否无法通过验证
      expect(signup).not_to be_valid

      # 11. 检查错误是否来自 attendance_status 字段
      expect(signup.errors[:attendance_status]).to include("is not included in the list")
    end

    # Test 7: 仅允许 Volunteer 报名
    it "rejects signups from organizer users" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建班次所属的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 设置班次的开始时间
      start_time = 1.day.from_now

      # 4. 创建一个合法的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 5. 创建一个合法的 Organizer 用户
      organizer = User.create!(
        email_address: "organizer@example.com",
        password: "password123",
        role: "organizer",
        organization: organization
      )

      # 6. 尝试使用 Organizer 创建 Signup
      signup = Signup.new(
        user: organizer,
        shift: shift,
        status: "confirmed",
        attendance_status: "pending"
      )

      # 7. 检查 Signup 是否无法通过验证
      expect(signup).not_to be_valid

      # 8. 检查错误是否来自 user 字段
      expect(signup.errors[:user]).to include("must be a volunteer")
    end

    # Test 8: 防止同一个 Volunteer 重复报名同一个 Shift
    it "rejects duplicate signups for the same user and shift" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建班次所属的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 设置班次的开始时间
      start_time = 1.day.from_now

      # 4. 创建一个合法的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 5. 创建一个合法的 Volunteer 用户
      volunteer = User.create!(
        email_address: "volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 6. 创建并保存第一次报名记录
      Signup.create!(
        user: volunteer,
        shift: shift,
        status: "confirmed"
      )

      # 7. 尝试创建同一个用户对同一个班次的第二次报名
      duplicate_signup = Signup.new(
        user: volunteer,
        shift: shift,
        status: "confirmed"
      )

      # 8. 检查重复报名是否无法通过验证
      expect(duplicate_signup).not_to be_valid

      # 9. 检查错误是否来自 user_id 字段
      expect(duplicate_signup.errors[:user_id]).to include("has already been taken")
    end

    # Test 9: 合法报名可以成功保存
    it "successfully saves a valid signup" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建班次所属的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 设置班次的开始时间
      start_time = 1.day.from_now

      # 4. 创建一个合法的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 5. 创建一个合法的 Volunteer 用户
      volunteer = User.create!(
        email_address: "volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 6. 创建一个合法的 Signup
      signup = Signup.new(
        user: volunteer,
        shift: shift,
        status: "confirmed",
        attendance_status: "pending"
      )

      # 7. 检查 Signup 是否能够通过验证
      expect(signup).to be_valid

      # 8. 检查 Signup 是否能够成功保存
      expect { signup.save! }.to change(Signup, :count).by(1)

      # 9. 检查 Signup 是否已经持久化
      expect(signup).to be_persisted

      # 10. 从数据库重新读取 Signup
      signup.reload

      # 11. 检查 Volunteer 是否正确保存
      expect(signup.user).to eq(volunteer)

      # 12. 检查 Shift 是否正确保存
      expect(signup.shift).to eq(shift)

      # 13. 检查报名状态是否正确保存
      expect(signup.status).to eq("confirmed")

      # 14. 检查出勤状态是否正确保存
      expect(signup.attendance_status).to eq("pending")
    end
  end

  describe "associations" do

    # Test 10: User 可以关联多个 Signup
    it "allows a user to have multiple signups" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建班次所属的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 设置班次的开始时间
      start_time = 1.day.from_now

      # 4. 创建第一个合法的 Shift
      shift1 = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 5. 创建第二个合法且时间不冲突的 Shift
      shift2 = Shift.create!(
        activity: activity,
        start_time: start_time + 4.hours,
        end_time: start_time + 7.hours,
        capacity: 20
      )

      # 6. 创建一个合法的 Volunteer 用户
      volunteer = User.create!(
        email_address: "volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 7. 创建第一个报名记录
      signup1 = Signup.create!(
        user: volunteer,
        shift: shift1,
        status: "confirmed"
      )

      # 8. 创建第二个报名记录
      signup2 = Signup.create!(
        user: volunteer,
        shift: shift2,
        status: "confirmed"
      )

      # 9. 检查 Volunteer 是否关联两个 Signup
      expect(volunteer.signups).to contain_exactly(
        signup1,
        signup2
      )
    end

    # Test 11: Shift 可以关联多个 Signup
    it "allows a shift to have multiple signups" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建班次所属的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 设置班次的开始时间
      start_time = 1.day.from_now

      # 4. 创建一个合法的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 5. 创建第一个合法的 Volunteer 用户
      volunteer1 = User.create!(
        email_address: "volunteer1@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 6. 创建第二个合法的 Volunteer 用户
      volunteer2 = User.create!(
        email_address: "volunteer2@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 7. 让第一个 Volunteer 报名该 Shift
      signup1 = Signup.create!(
        user: volunteer1,
        shift: shift,
        status: "confirmed"
      )

      # 8. 让第二个 Volunteer 报名该 Shift
      signup2 = Signup.create!(
        user: volunteer2,
        shift: shift,
        status: "confirmed"
      )

      # 9. 检查 Shift 是否关联两个 Signup
      expect(shift.signups).to contain_exactly(
        signup1,
        signup2
      )
    end
  end
end
