
require 'rails_helper'

RSpec.describe Signup, type: :model do
  describe "time conflict detection" do
    # Test 1: 禁止同一个 Volunteer 报名时间重叠的班次
    it "rejects overlapping confirmed signups for the same user" do
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

      # 3. 设置第一个班次的开始时间
      start_time = 1.day.from_now

      # 4. 创建第一个合法的 Shift
      shift1 = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 5. 创建第二个与第一个时间重叠的 Shift
      shift2 = Shift.create!(
        activity: activity,
        start_time: start_time + 2.hours,
        end_time: start_time + 5.hours,
        capacity: 20
      )

      # 6. 创建一个合法的 Volunteer 用户
      volunteer = User.create!(
        email_address: "volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 7. 让 Volunteer 成功报名第一个 Shift
      signup1 = Signup.create!(
        user: volunteer,
        shift: shift1,
        status: "confirmed"
      )

      # 8. 尝试报名第二个时间重叠的 Shift
      signup2 = Signup.new(
        user: volunteer,
        shift: shift2,
        status: "confirmed"
      )

      # 9. 检查时间冲突的报名是否无法通过验证
      expect(signup2).not_to be_valid

      # 10. 检查错误是否来自 shift 字段
      expect(signup2.errors[:shift]).to include(
        "overlaps with another confirmed signup"
      )

      # 11. 检查时间冲突的报名是否无法保存
      expect(signup2.save).to be false

      # 12. 检查原有报名状态是否保持不变
      expect(signup1.reload.status).to eq("confirmed")

      # 13. 检查 Volunteer 是否仍然只有一条报名记录
      expect(volunteer.signups.count).to eq(1)
    end

    # Test 2: 允许同一个 Volunteer 报名时间不重叠的班次
    it "allows non-overlapping confirmed signups for the same user" do
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

      # 3. 设置第一个班次的开始时间
      start_time = 1.day.from_now

      # 4. 创建第一个合法的 Shift
      shift1 = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 5. 创建第二个与第一个时间不重叠的 Shift
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

      # 7. 让 Volunteer 成功报名第一个 Shift
      signup1 = Signup.create!(
        user: volunteer,
        shift: shift1,
        status: "confirmed"
      )

      # 8. 尝试报名第二个时间不重叠的 Shift
      signup2 = Signup.new(
        user: volunteer,
        shift: shift2,
        status: "confirmed"
      )

      # 9. 检查第二个报名是否能够通过验证
      expect(signup2).to be_valid

      # 10. 检查第二个报名是否能够成功保存
      expect { signup2.save! }.to change(Signup, :count).by(1)

      # 11. 从数据库重新读取两个报名记录
      signup1.reload
      signup2.reload

      # 12. 检查第一个报名的状态是否保持不变
      expect(signup1.status).to eq("confirmed")

      # 13. 检查第二个报名的状态是否为 confirmed
      expect(signup2.status).to eq("confirmed")

      # 14. 检查 Volunteer 是否拥有两条报名记录
      expect(volunteer.signups.count).to eq(2)

      # 15. 检查 Volunteer 是否拥有两条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(2)

      # 16. 检查两个班次的已确认报名人数是否正确
      expect(shift1.confirmed_count).to eq(1)
      expect(shift2.confirmed_count).to eq(1)
    end

    # Test 3: 允许同一个 Volunteer 报名首尾相接的班次
    it "allows confirmed signups for back-to-back shifts" do
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

      # 3. 设置第一个班次的开始时间
      start_time = 1.day.from_now.change(usec: 0)

      # 4. 创建第一个合法的 Shift
      shift1 = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 5. 创建第二个与第一个首尾相接的 Shift
      shift2 = Shift.create!(
        activity: activity,
        start_time: shift1.end_time,
        end_time: shift1.end_time + 3.hours,
        capacity: 20
      )

      # 6. 检查两个班次是否恰好首尾相接
      expect(shift1.end_time).to eq(shift2.start_time)

      # 7. 创建一个合法的 Volunteer 用户
      volunteer = User.create!(
        email_address: "volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 8. 让 Volunteer 成功报名第一个 Shift
      signup1 = Signup.create!(
        user: volunteer,
        shift: shift1,
        status: "confirmed"
      )

      # 9. 尝试报名第二个首尾相接的 Shift
      signup2 = Signup.new(
        user: volunteer,
        shift: shift2,
        status: "confirmed"
      )

      # 10. 检查第二个报名是否能够通过验证
      expect(signup2).to be_valid

      # 11. 检查第二个报名是否能够成功保存
      expect { signup2.save! }.to change(Signup, :count).by(1)

      # 12. 从数据库重新读取两个报名记录
      signup1.reload
      signup2.reload

      # 13. 检查第一个报名的状态是否保持不变
      expect(signup1.status).to eq("confirmed")

      # 14. 检查第二个报名的状态是否为 confirmed
      expect(signup2.status).to eq("confirmed")

      # 15. 检查 Volunteer 是否拥有两条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(2)

      # 16. 检查两个班次的已确认报名人数是否正确
      expect(shift1.confirmed_count).to eq(1)
      expect(shift2.confirmed_count).to eq(1)
    end

    # Test 4: 已取消报名不产生时间冲突
    it "ignores cancelled signups when checking time conflicts" do
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

      # 3. 设置第一个班次的开始时间
      start_time = 1.day.from_now

      # 4. 创建第一个合法的 Shift
      shift1 = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 5. 创建第二个与第一个时间重叠的 Shift
      shift2 = Shift.create!(
        activity: activity,
        start_time: start_time + 2.hours,
        end_time: start_time + 5.hours,
        capacity: 20
      )

      # 6. 创建一个合法的 Volunteer 用户
      volunteer = User.create!(
        email_address: "volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 7. 让 Volunteer 成功报名第一个 Shift
      signup1 = Signup.create!(
        user: volunteer,
        shift: shift1,
        status: "confirmed"
      )

      # 8. 取消第一个 Shift 的报名
      signup1.update!(status: "cancelled")

      # 9. 检查第一个报名是否已经取消
      expect(signup1.reload.status).to eq("cancelled")

      # 10. 尝试报名第二个时间重叠的 Shift
      signup2 = Signup.new(
        user: volunteer,
        shift: shift2,
        status: "confirmed"
      )

      # 11. 检查第二个报名是否能够通过验证
      expect(signup2).to be_valid

      # 12. 检查第二个报名是否能够成功保存
      expect { signup2.save! }.to change(Signup, :count).by(1)

      # 13. 从数据库重新读取两个报名记录
      signup1.reload
      signup2.reload

      # 14. 检查第一个报名是否仍然为 cancelled
      expect(signup1.status).to eq("cancelled")

      # 15. 检查第二个报名是否为 confirmed
      expect(signup2.status).to eq("confirmed")

      # 16. 检查 Volunteer 是否拥有两条报名记录
      expect(volunteer.signups.count).to eq(2)

      # 17. 检查 Volunteer 是否只有一条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(1)

      # 18. 检查两个班次的已确认报名人数是否正确
      expect(shift1.confirmed_count).to eq(0)
      expect(shift2.confirmed_count).to eq(1)
    end

    # Test 5: 已有候补报名不产生时间冲突
    it "ignores waitlisted signups when checking time conflicts" do
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

      # 3. 设置第一个班次的开始时间
      start_time = 1.day.from_now

      # 4. 创建第一个容量为 1 的 Shift
      shift1 = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 1
      )

      # 5. 创建第二个与第一个时间重叠的 Shift
      shift2 = Shift.create!(
        activity: activity,
        start_time: start_time + 2.hours,
        end_time: start_time + 5.hours,
        capacity: 20
      )

      # 6. 创建一个用于占满第一个班次的 Volunteer
      other_volunteer = User.create!(
        email_address: "other_volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 7. 创建需要进行时间冲突检测的 Volunteer
      volunteer = User.create!(
        email_address: "volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 8. 让另一个 Volunteer 占用第一个班次的名额
      Signup.create!(
        user: other_volunteer,
        shift: shift1,
        status: "confirmed"
      )

      # 9. 确认第一个班次已经满员
      expect(shift1.full?).to be true

      # 10. 让 Volunteer 进入第一个班次的候补队列
      signup1 = Signup.create!(
        user: volunteer,
        shift: shift1,
        status: "waitlisted"
      )

      # 11. 检查第一个报名是否为 waitlisted
      expect(signup1.reload.status).to eq("waitlisted")

      # 12. 尝试确认报名第二个时间重叠的 Shift
      signup2 = Signup.new(
        user: volunteer,
        shift: shift2,
        status: "confirmed"
      )

      # 13. 检查第二个报名是否能够通过验证
      expect(signup2).to be_valid

      # 14. 检查第二个报名是否能够成功保存
      expect { signup2.save! }.to change(Signup, :count).by(1)

      # 15. 从数据库重新读取两个报名记录
      signup1.reload
      signup2.reload

      # 16. 检查第一个报名是否仍然为 waitlisted
      expect(signup1.status).to eq("waitlisted")

      # 17. 检查第二个报名是否为 confirmed
      expect(signup2.status).to eq("confirmed")

      # 18. 检查 Volunteer 是否拥有两条报名记录
      expect(volunteer.signups.count).to eq(2)

      # 19. 检查 Volunteer 是否只有一条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(1)

      # 20. 检查 Volunteer 是否只有一条候补报名记录
      expect(
        volunteer.signups.where(status: "waitlisted").count
      ).to eq(1)

      # 21. 检查两个班次的已确认报名人数是否正确
      expect(shift1.confirmed_count).to eq(1)
      expect(shift2.confirmed_count).to eq(1)
    end

    # Test 6: 允许时间重叠的候补报名
    it "allows waitlisted signups for overlapping shifts" do
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

      # 3. 设置第一个班次的开始时间
      start_time = 1.day.from_now

      # 4. 创建第一个合法的 Shift
      shift1 = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 5. 创建第二个时间重叠且容量为 1 的 Shift
      shift2 = Shift.create!(
        activity: activity,
        start_time: start_time + 2.hours,
        end_time: start_time + 5.hours,
        capacity: 1
      )

      # 6. 创建需要进行时间冲突检测的 Volunteer
      volunteer = User.create!(
        email_address: "volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 7. 创建用于占满第二个班次的 Volunteer
      other_volunteer = User.create!(
        email_address: "other_volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 8. 让 Volunteer 成功报名第一个 Shift
      signup1 = Signup.create!(
        user: volunteer,
        shift: shift1,
        status: "confirmed"
      )

      # 9. 让另一个 Volunteer 占用第二个班次的唯一名额
      Signup.create!(
        user: other_volunteer,
        shift: shift2,
        status: "confirmed"
      )

      # 10. 确认第二个班次已经满员
      expect(shift2.full?).to be true

      # 11. 尝试加入第二个时间重叠班次的候补队列
      signup2 = Signup.new(
        user: volunteer,
        shift: shift2,
        status: "waitlisted"
      )

      # 12. 检查候补报名是否能够通过验证
      expect(signup2).to be_valid

      # 13. 检查候补报名是否能够成功保存
      expect { signup2.save! }.to change(Signup, :count).by(1)

      # 14. 从数据库重新读取两个报名记录
      signup1.reload
      signup2.reload

      # 15. 检查第一个报名是否仍然为 confirmed
      expect(signup1.status).to eq("confirmed")

      # 16. 检查第二个报名是否为 waitlisted
      expect(signup2.status).to eq("waitlisted")

      # 17. 检查 Volunteer 是否拥有两条报名记录
      expect(volunteer.signups.count).to eq(2)

      # 18. 检查 Volunteer 是否只有一条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(1)

      # 19. 检查 Volunteer 是否只有一条候补报名记录
      expect(
        volunteer.signups.where(status: "waitlisted").count
      ).to eq(1)

      # 20. 检查两个班次的已确认报名人数是否正确
      expect(shift1.confirmed_count).to eq(1)
      expect(shift2.confirmed_count).to eq(1)

      # 21. 检查第二个班次的候补报名人数是否为 1
      expect(
        shift2.signups.where(status: "waitlisted").count
      ).to eq(1)

      # 22. 检查第二个班次是否仍然满员
      expect(shift2.full?).to be true
    end

    # Test 7: 不同 Volunteer 之间的报名时间互不影响
    it "allows overlapping confirmed signups for different users" do
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

      # 3. 设置第一个班次的开始时间
      start_time = 1.day.from_now

      # 4. 创建第一个合法的 Shift
      shift1 = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 5. 创建第二个与第一个时间重叠的 Shift
      shift2 = Shift.create!(
        activity: activity,
        start_time: start_time + 2.hours,
        end_time: start_time + 5.hours,
        capacity: 20
      )

      # 6. 创建第一个 Volunteer
      volunteer1 = User.create!(
        email_address: "volunteer1@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 7. 创建第二个 Volunteer
      volunteer2 = User.create!(
        email_address: "volunteer2@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 8. 让第一个 Volunteer 成功报名第一个 Shift
      signup1 = Signup.create!(
        user: volunteer1,
        shift: shift1,
        status: "confirmed"
      )

      # 9. 让第二个 Volunteer 尝试报名时间重叠的 Shift
      signup2 = Signup.new(
        user: volunteer2,
        shift: shift2,
        status: "confirmed"
      )

      # 10. 检查第二个 Volunteer 的报名是否能够通过验证
      expect(signup2).to be_valid

      # 11. 检查第二个报名是否能够成功保存
      expect { signup2.save! }.to change(Signup, :count).by(1)

      # 12. 从数据库重新读取两个报名记录
      signup1.reload
      signup2.reload

      # 13. 检查第一个报名是否仍然为 confirmed
      expect(signup1.status).to eq("confirmed")

      # 14. 检查第二个报名是否为 confirmed
      expect(signup2.status).to eq("confirmed")

      # 15. 检查两个报名是否属于不同的 Volunteer
      expect(signup1.user_id).not_to eq(signup2.user_id)

      # 16. 检查第一个 Volunteer 是否拥有一条已确认报名记录
      expect(
        volunteer1.signups.where(status: "confirmed").count
      ).to eq(1)

      # 17. 检查第二个 Volunteer 是否拥有一条已确认报名记录
      expect(
        volunteer2.signups.where(status: "confirmed").count
      ).to eq(1)

      # 18. 检查两个班次的已确认报名人数是否正确
      expect(shift1.confirmed_count).to eq(1)
      expect(shift2.confirmed_count).to eq(1)
    end

    # Test 8: 跨 Organization 的时间冲突检测
    it "rejects overlapping confirmed signups across different organizations" do
      # 1. 创建第一个 Organization
      organization1 = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建第二个 Organization
      organization2 = Organization.create!(
        name: "CUHK Community Service"
      )

      # 3. 创建属于第一个 Organization 的 Activity
      activity1 = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization1
      )

      # 4. 创建属于第二个 Organization 的 Activity
      activity2 = Activity.create!(
        title: "Community Service",
        description: "Community service volunteer activity",
        location: "Sha Tin",
        organization: organization2
      )

      # 5. 设置第一个班次的开始时间
      start_time = 1.day.from_now

      # 6. 创建属于第一个 Activity 的 Shift
      shift1 = Shift.create!(
        activity: activity1,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 7. 创建属于第二个 Activity 且时间重叠的 Shift
      shift2 = Shift.create!(
        activity: activity2,
        start_time: start_time + 2.hours,
        end_time: start_time + 5.hours,
        capacity: 20
      )

      # 8. 检查两个班次是否属于不同的 Organization
      expect(
        shift1.activity.organization_id
      ).not_to eq(
        shift2.activity.organization_id
      )

      # 9. 创建一个合法的 Volunteer 用户
      volunteer = User.create!(
        email_address: "volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 10. 让 Volunteer 成功报名第一个 Organization 的 Shift
      signup1 = Signup.create!(
        user: volunteer,
        shift: shift1,
        status: "confirmed"
      )

      # 11. 检查第二个班次是否拥有可用名额
      expect(shift2.full?).to be false

      # 12. 尝试报名第二个 Organization 中时间重叠的 Shift
      signup2 = Signup.new(
        user: volunteer,
        shift: shift2,
        status: "confirmed"
      )

      # 13. 检查跨 Organization 的时间冲突报名是否无法通过验证
      expect(signup2).not_to be_valid

      # 14. 检查错误是否来自 shift 字段
      expect(signup2.errors[:shift]).to include(
        "overlaps with another confirmed signup"
      )

      # 15. 检查时间冲突的报名是否无法保存
      expect(signup2.save).to be false

      # 16. 检查第一个 Organization 的报名状态是否保持不变
      expect(signup1.reload.status).to eq("confirmed")

      # 17. 检查 Volunteer 是否仍然只有一条报名记录
      expect(volunteer.signups.count).to eq(1)

      # 18. 检查 Volunteer 是否仍然只有一条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(1)

      # 19. 检查第一个班次的已确认报名人数是否为 1
      expect(shift1.confirmed_count).to eq(1)

      # 20. 检查第二个班次的已确认报名人数是否仍然为 0
      expect(shift2.confirmed_count).to eq(0)
    end

    # Test 9: 更新时间冲突验证时排除当前报名自身
    it "excludes the current signup when checking time conflicts" do
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

      # 3. 设置一个已经结束的班次的开始时间
      start_time = 1.day.ago

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

      # 6. 让 Volunteer 成功报名该 Shift
      signup = Signup.create!(
        user: volunteer,
        shift: shift,
        status: "confirmed"
      )

      # 7. 记录原有报名的 ID
      original_signup_id = signup.id

      # 8. 检查初始报名状态是否为 confirmed
      expect(signup.status).to eq("confirmed")

      # 9. 检查初始出勤状态是否为 pending
      expect(signup.attendance_status).to eq("pending")

      # 10. 检查 Volunteer 是否只有一条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(1)

      # 11. 修改已有报名的出勤状态
      signup.attendance_status = "present"

      # 12. 检查修改后的报名记录是否能够通过验证
      expect(signup).to be_valid

      # 13. 检查报名是否没有产生自身时间冲突错误
      expect(signup.errors[:shift]).not_to include(
        "overlaps with another confirmed signup"
      )

      # 14. 检查出勤状态是否能够成功保存
      expect(signup.save).to be true

      # 15. 从数据库重新读取报名记录
      signup.reload

      # 16. 检查报名记录的 ID 是否保持不变
      expect(signup.id).to eq(original_signup_id)

      # 17. 检查出勤状态是否成功修改为 present
      expect(signup.attendance_status).to eq("present")

      # 18. 检查报名状态是否仍然为 confirmed
      expect(signup.status).to eq("confirmed")

      # 19. 检查报名所属的 Volunteer 和 Shift 是否保持不变
      expect(signup.user_id).to eq(volunteer.id)
      expect(signup.shift_id).to eq(shift.id)

      # 20. 检查 Volunteer 是否仍然只有一条报名记录
      expect(volunteer.signups.count).to eq(1)

      # 21. 检查班次的已确认报名人数是否保持不变
      expect(shift.confirmed_count).to eq(1)
    end

    # Test 10: 禁止存在时间冲突的候补报名转正
    it "rejects waitlisted signup promotion when a time conflict exists" do
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

      # 3. 设置第一个班次的开始时间
      start_time = 1.day.from_now

      # 4. 创建第一个合法的 Shift
      shift1 = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 5. 创建第二个时间重叠且容量为 1 的 Shift
      shift2 = Shift.create!(
        activity: activity,
        start_time: start_time + 2.hours,
        end_time: start_time + 5.hours,
        capacity: 1
      )

      # 6. 创建需要进行时间冲突检测的 Volunteer
      volunteer = User.create!(
        email_address: "volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 7. 创建用于占满第二个班次的 Volunteer
      other_volunteer = User.create!(
        email_address: "other_volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 8. 让 Volunteer 成功报名第一个 Shift
      signup1 = Signup.create!(
        user: volunteer,
        shift: shift1,
        status: "confirmed"
      )

      # 9. 让另一个 Volunteer 占用第二个班次的唯一名额
      other_signup = Signup.create!(
        user: other_volunteer,
        shift: shift2,
        status: "confirmed"
      )

      # 10. 确认第二个班次已经满员
      expect(shift2.full?).to be true

      # 11. 让 Volunteer 加入第二个班次的候补队列
      signup2 = Signup.create!(
        user: volunteer,
        shift: shift2,
        status: "waitlisted"
      )

      # 12. 检查第二个报名是否为 waitlisted
      expect(signup2.reload.status).to eq("waitlisted")

      # 13. 让另一个 Volunteer 取消第二个班次的报名
      other_signup.update!(status: "cancelled")

      # 14. 检查第二个班次是否已经释放一个名额
      expect(shift2.confirmed_count).to eq(0)
      expect(shift2.available_slots).to eq(1)
      expect(shift2.full?).to be false

      # 15. 尝试将存在时间冲突的候补报名转正
      signup2.status = "confirmed"

      # 16. 检查存在时间冲突的候补报名是否无法通过验证
      expect(signup2).not_to be_valid

      # 17. 检查错误是否来自时间冲突验证
      expect(signup2.errors[:shift]).to include(
        "overlaps with another confirmed signup"
      )

      # 18. 检查报名失败是否并非由班次容量不足导致
      expect(signup2.errors[:shift]).not_to include(
        "has reached its capacity"
      )

      # 19. 检查存在时间冲突的候补转正是否无法保存
      expect(signup2.save).to be false

      # 20. 从数据库重新读取所有报名记录
      signup1.reload
      signup2.reload
      other_signup.reload

      # 21. 检查第一个报名是否仍然为 confirmed
      expect(signup1.status).to eq("confirmed")

      # 22. 检查第二个报名是否仍然为 waitlisted
      expect(signup2.status).to eq("waitlisted")

      # 23. 检查另一个 Volunteer 的报名是否仍然为 cancelled
      expect(other_signup.status).to eq("cancelled")

      # 24. 检查 Volunteer 是否仍然拥有两条报名记录
      expect(volunteer.signups.count).to eq(2)

      # 25. 检查 Volunteer 是否仍然只有一条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(1)

      # 26. 检查 Volunteer 是否仍然只有一条候补报名记录
      expect(
        volunteer.signups.where(status: "waitlisted").count
      ).to eq(1)

      # 27. 检查两个班次的已确认报名人数是否正确
      expect(shift1.confirmed_count).to eq(1)
      expect(shift2.confirmed_count).to eq(0)

      # 28. 检查第二个班次的候补报名人数是否仍然为 1
      expect(
        shift2.signups.where(status: "waitlisted").count
      ).to eq(1)

      # 29. 检查第二个班次的剩余名额是否保持为 1
      expect(shift2.available_slots).to eq(1)

      # 30. 检查第二个班次是否仍然未满员
      expect(shift2.full?).to be false
    end
  end
end
