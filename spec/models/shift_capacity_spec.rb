
require 'rails_helper'

RSpec.describe Shift, type: :model do
  describe "capacity management" do

    # Test 1: 正确统计已确认报名人数
    it "counts confirmed signups correctly" do
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

      # 4. 创建一个容量为 5 的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 5
      )

      # 5. 创建第一个 Volunteer
      volunteer1 = User.create!(
        email_address: "volunteer1@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 6. 创建第二个 Volunteer
      volunteer2 = User.create!(
        email_address: "volunteer2@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 7. 创建第一个已确认报名
      Signup.create!(
        user: volunteer1,
        shift: shift,
        status: "confirmed"
      )

      # 8. 创建第二个已确认报名
      Signup.create!(
        user: volunteer2,
        shift: shift,
        status: "confirmed"
      )

      # 9. 检查已确认报名人数是否为 2
      expect(shift.confirmed_count).to eq(2)
    end

    # Test 2: 候补及取消报名不占用名额
    it "excludes waitlisted and cancelled signups from confirmed count" do
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

      # 4. 创建一个容量为 5 的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 5
      )

      # 5. 创建第一个 Volunteer
      volunteer1 = User.create!(
        email_address: "volunteer1@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 6. 创建第二个 Volunteer
      volunteer2 = User.create!(
        email_address: "volunteer2@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 7. 创建第三个 Volunteer
      volunteer3 = User.create!(
        email_address: "volunteer3@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 8. 创建第四个 Volunteer
      volunteer4 = User.create!(
        email_address: "volunteer4@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 9. 创建第一个已确认报名
      Signup.create!(
        user: volunteer1,
        shift: shift,
        status: "confirmed"
      )

      # 10. 创建第二个已确认报名
      Signup.create!(
        user: volunteer2,
        shift: shift,
        status: "confirmed"
      )

      # 11. 创建一个候补报名
      Signup.create!(
        user: volunteer3,
        shift: shift,
        status: "waitlisted"
      )

      # 12. 创建一个已取消报名
      Signup.create!(
        user: volunteer4,
        shift: shift,
        status: "cancelled"
      )

      # 13. 检查总报名记录数量是否为 4
      expect(shift.signups.count).to eq(4)

      # 14. 检查已确认报名人数是否仍然为 2
      expect(shift.confirmed_count).to eq(2)
    end

    # Test 3: 正确计算剩余名额
    it "calculates available slots correctly" do
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

      # 4. 创建一个容量为 5 的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 5
      )

      # 5. 检查没有报名时的剩余名额是否为 5
      expect(shift.available_slots).to eq(5)

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

      # 8. 创建第一个已确认报名
      Signup.create!(
        user: volunteer1,
        shift: shift,
        status: "confirmed"
      )

      # 9. 检查剩余名额是否减少至 4
      expect(shift.available_slots).to eq(4)

      # 10. 创建第二个已确认报名
      Signup.create!(
        user: volunteer2,
        shift: shift,
        status: "confirmed"
      )

      # 11. 检查剩余名额是否减少至 3
      expect(shift.available_slots).to eq(3)
    end

    # Test 4: 正确判断班次是否已满
    it "determines whether a shift is full" do
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

      # 4. 创建一个容量为 2 的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 2
      )

      # 5. 检查没有报名时班次是否未满
      expect(shift.full?).to be false

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

      # 8. 创建第一个已确认报名
      Signup.create!(
        user: volunteer1,
        shift: shift,
        status: "confirmed"
      )

      # 9. 检查仍有一个名额时班次是否未满
      expect(shift.full?).to be false

      # 10. 创建第二个已确认报名
      Signup.create!(
        user: volunteer2,
        shift: shift,
        status: "confirmed"
      )

      # 11. 检查没有剩余名额时班次是否已满
      expect(shift.full?).to be true
    end

    # Test 5: 禁止已确认报名人数超过容量
    it "rejects confirmed signups when the shift is full" do
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

      # 4. 创建一个容量为 2 的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 2
      )

      # 5. 创建第一个 Volunteer
      volunteer1 = User.create!(
        email_address: "volunteer1@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 6. 创建第二个 Volunteer
      volunteer2 = User.create!(
        email_address: "volunteer2@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 7. 创建第三个 Volunteer
      volunteer3 = User.create!(
        email_address: "volunteer3@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 8. 创建第一个已确认报名
      Signup.create!(
        user: volunteer1,
        shift: shift,
        status: "confirmed"
      )

      # 9. 创建第二个已确认报名
      Signup.create!(
        user: volunteer2,
        shift: shift,
        status: "confirmed"
      )

      # 10. 确认当前班次已经满员
      expect(shift.full?).to be true

      # 11. 尝试创建第三个已确认报名
      signup = Signup.new(
        user: volunteer3,
        shift: shift,
        status: "confirmed"
      )

      # 12. 检查超容量报名是否无法通过验证
      expect(signup).not_to be_valid

      # 13. 检查错误是否来自 shift 字段
      expect(signup.errors[:shift]).to include("has reached its capacity")

      # 14. 检查超容量报名是否无法保存
      expect(signup.save).to be false

      # 15. 检查已确认报名人数是否仍然为 2
      expect(shift.confirmed_count).to eq(2)
    end

    # Test 6: 允许已满班次接受候补报名
    it "allows waitlisted signups when the shift is full" do
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

      # 4. 创建一个容量为 2 的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 2
      )

      # 5. 创建第一个 Volunteer
      volunteer1 = User.create!(
        email_address: "volunteer1@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 6. 创建第二个 Volunteer
      volunteer2 = User.create!(
        email_address: "volunteer2@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 7. 创建第三个 Volunteer
      volunteer3 = User.create!(
        email_address: "volunteer3@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 8. 创建第一个已确认报名
      Signup.create!(
        user: volunteer1,
        shift: shift,
        status: "confirmed"
      )

      # 9. 创建第二个已确认报名
      Signup.create!(
        user: volunteer2,
        shift: shift,
        status: "confirmed"
      )

      # 10. 确认当前班次已经满员
      expect(shift.full?).to be true

      # 11. 创建第三个 Volunteer 的候补报名
      signup = Signup.new(
        user: volunteer3,
        shift: shift,
        status: "waitlisted"
      )

      # 12. 检查候补报名是否能够通过验证
      expect(signup).to be_valid

      # 13. 检查候补报名是否能够成功保存
      expect { signup.save! }.to change(Signup, :count).by(1)

      # 14. 从数据库重新读取报名记录
      signup.reload

      # 15. 检查报名状态是否为 waitlisted
      expect(signup.status).to eq("waitlisted")

      # 16. 检查总报名记录数量是否为 3
      expect(shift.signups.count).to eq(3)

      # 17. 检查已确认报名人数是否仍然为 2
      expect(shift.confirmed_count).to eq(2)

      # 18. 检查剩余名额是否仍然为 0
      expect(shift.available_slots).to eq(0)

      # 19. 检查班次是否仍然满员
      expect(shift.full?).to be true
    end

    # Test 7: 禁止将容量调整至低于已确认人数
    it "rejects capacity reductions below the confirmed signup count" do
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

      # 4. 创建一个容量为 3 的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 3
      )

      # 5. 创建第一个 Volunteer
      volunteer1 = User.create!(
        email_address: "volunteer1@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 6. 创建第二个 Volunteer
      volunteer2 = User.create!(
        email_address: "volunteer2@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 7. 创建第一个已确认报名
      Signup.create!(
        user: volunteer1,
        shift: shift,
        status: "confirmed"
      )

      # 8. 创建第二个已确认报名
      Signup.create!(
        user: volunteer2,
        shift: shift,
        status: "confirmed"
      )

      # 9. 检查当前已确认报名人数是否为 2
      expect(shift.confirmed_count).to eq(2)

      # 10. 尝试将班次容量减少至 1
      shift.capacity = 1

      # 11. 检查 Shift 是否无法通过验证
      expect(shift).not_to be_valid

      # 12. 检查错误是否来自 capacity 字段
      expect(shift.errors[:capacity]).to include(
        "cannot be less than the number of confirmed signups"
      )

      # 13. 检查非法容量修改是否无法保存
      expect(shift.save).to be false

      # 14. 从数据库重新读取 Shift
      shift.reload

      # 15. 检查原有容量是否保持不变
      expect(shift.capacity).to eq(3)

      # 16. 检查已确认报名人数是否保持不变
      expect(shift.confirmed_count).to eq(2)

      # 17. 将班次容量减少至恰好等于已确认报名人数
      shift.capacity = 2

      # 18. 检查合法的容量修改是否能够通过验证
      expect(shift).to be_valid

      # 19. 检查合法的容量修改是否能够成功保存
      expect(shift.save).to be true

      # 20. 从数据库重新读取 Shift
      shift.reload

      # 21. 检查班次容量是否成功修改为 2
      expect(shift.capacity).to eq(2)

      # 22. 检查班次是否已经满员
      expect(shift.full?).to be true
    end

    # Test 8: 满员时允许更新已有 confirmed 报名的出勤状态
    it "allows attendance updates for confirmed signups when the shift is full" do
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
      start_time = 1.day.ago

      # 4. 创建一个容量为 2 的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 2
      )

      # 5. 创建第一个 Volunteer
      volunteer1 = User.create!(
        email_address: "volunteer1@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 6. 创建第二个 Volunteer
      volunteer2 = User.create!(
        email_address: "volunteer2@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 7. 创建第一个已确认报名
      signup1 = Signup.create!(
        user: volunteer1,
        shift: shift,
        status: "confirmed"
      )

      # 8. 创建第二个已确认报名
      Signup.create!(
        user: volunteer2,
        shift: shift,
        status: "confirmed"
      )

      # 9. 确认当前班次已经满员
      expect(shift.full?).to be true

      # 10. 检查第一个报名的初始出勤状态
      expect(signup1.attendance_status).to eq("pending")

      # 11. 修改第一个报名的出勤状态
      signup1.attendance_status = "present"

      # 12. 检查修改后的报名记录是否能够通过验证
      expect(signup1).to be_valid

      # 13. 检查出勤状态是否能够成功保存
      expect(signup1.save).to be true

      # 14. 从数据库重新读取报名记录
      signup1.reload

      # 15. 检查出勤状态是否成功修改
      expect(signup1.attendance_status).to eq("present")

      # 16. 检查报名状态是否仍然为 confirmed
      expect(signup1.status).to eq("confirmed")

      # 17. 检查总报名记录数量是否仍然为 2
      expect(shift.signups.count).to eq(2)

      # 18. 检查已确认报名人数是否仍然为 2
      expect(shift.confirmed_count).to eq(2)

      # 19. 检查剩余名额是否仍然为 0
      expect(shift.available_slots).to eq(0)

      # 20. 检查班次是否仍然满员
      expect(shift.full?).to be true
    end

    # Test 9: 满员时禁止 waitlisted 报名转为 confirmed
    it "rejects waitlisted signup promotion when the shift is full" do
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

      # 4. 创建一个容量为 2 的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 2
      )

      # 5. 创建第一个 Volunteer
      volunteer1 = User.create!(
        email_address: "volunteer1@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 6. 创建第二个 Volunteer
      volunteer2 = User.create!(
        email_address: "volunteer2@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 7. 创建第三个 Volunteer
      volunteer3 = User.create!(
        email_address: "volunteer3@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 8. 创建第一个已确认报名
      Signup.create!(
        user: volunteer1,
        shift: shift,
        status: "confirmed"
      )

      # 9. 创建第二个已确认报名
      Signup.create!(
        user: volunteer2,
        shift: shift,
        status: "confirmed"
      )

      # 10. 创建第三个 Volunteer 的候补报名
      signup = Signup.create!(
        user: volunteer3,
        shift: shift,
        status: "waitlisted"
      )

      # 11. 确认当前班次已经满员
      expect(shift.full?).to be true

      # 12. 检查第三个 Volunteer 的初始报名状态
      expect(signup.status).to eq("waitlisted")

      # 13. 尝试将候补报名转为已确认报名
      signup.status = "confirmed"

      # 14. 检查修改后的报名记录是否无法通过验证
      expect(signup).not_to be_valid

      # 15. 检查错误是否来自 shift 字段
      expect(signup.errors[:shift]).to include(
        "has reached its capacity"
      )

      # 16. 检查非法的报名状态修改是否无法保存
      expect(signup.save).to be false

      # 17. 从数据库重新读取报名记录
      signup.reload

      # 18. 检查原有候补状态是否保持不变
      expect(signup.status).to eq("waitlisted")

      # 19. 检查总报名记录数量是否仍然为 3
      expect(shift.signups.count).to eq(3)

      # 20. 检查已确认报名人数是否仍然为 2
      expect(shift.confirmed_count).to eq(2)

      # 21. 检查候补报名人数是否仍然为 1
      expect(
        shift.signups.where(status: "waitlisted").count
      ).to eq(1)

      # 22. 检查剩余名额是否仍然为 0
      expect(shift.available_slots).to eq(0)

      # 23. 检查班次是否仍然满员
      expect(shift.full?).to be true
    end

    # Test 10: 取消 confirmed 报名后正确释放名额
    it "releases a slot when a confirmed signup is cancelled" do
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

      # 4. 创建一个容量为 2 的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 2
      )

      # 5. 创建第一个 Volunteer
      volunteer1 = User.create!(
        email_address: "volunteer1@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 6. 创建第二个 Volunteer
      volunteer2 = User.create!(
        email_address: "volunteer2@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 7. 创建第一个已确认报名
      signup1 = Signup.create!(
        user: volunteer1,
        shift: shift,
        status: "confirmed"
      )

      # 8. 创建第二个已确认报名
      signup2 = Signup.create!(
        user: volunteer2,
        shift: shift,
        status: "confirmed"
      )

      # 9. 检查当前已确认报名人数是否为 2
      expect(shift.confirmed_count).to eq(2)

      # 10. 检查当前剩余名额是否为 0
      expect(shift.available_slots).to eq(0)

      # 11. 确认当前班次已经满员
      expect(shift.full?).to be true

      # 12. 将第一个报名的状态修改为 cancelled
      signup1.status = "cancelled"

      # 13. 检查取消报名后是否能够通过验证
      expect(signup1).to be_valid

      # 14. 检查取消报名是否能够成功保存
      expect(signup1.save).to be true

      # 15. 从数据库重新读取第一个报名记录
      signup1.reload

      # 16. 检查第一个报名的状态是否为 cancelled
      expect(signup1.status).to eq("cancelled")

      # 17. 检查第二个报名的状态是否保持不变
      expect(signup2.reload.status).to eq("confirmed")

      # 18. 检查总报名记录数量是否仍然为 2
      expect(shift.signups.count).to eq(2)

      # 19. 检查已取消报名人数是否为 1
      expect(
        shift.signups.where(status: "cancelled").count
      ).to eq(1)

      # 20. 检查已确认报名人数是否减少至 1
      expect(shift.confirmed_count).to eq(1)

      # 21. 检查剩余名额是否增加至 1
      expect(shift.available_slots).to eq(1)

      # 22. 检查班次是否不再满员
      expect(shift.full?).to be false

      # 23. 检查班次总容量是否保持不变
      expect(shift.reload.capacity).to eq(2)
    end
  end
end
