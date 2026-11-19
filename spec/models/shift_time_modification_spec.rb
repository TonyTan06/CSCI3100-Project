
require 'rails_helper'

RSpec.describe Shift, type: :model do
  describe "time modification protection" do

    # Test 1: 禁止造成已确认报名时间冲突的班次修改
    it "rejects time changes that cause conflicts for confirmed volunteers" do
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

      # 8. 让 Volunteer 成功报名第二个 Shift
      signup2 = Signup.create!(
        user: volunteer,
        shift: shift2,
        status: "confirmed"
      )

      # 9. 检查 Volunteer 是否拥有两条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(2)

      # 10. 保存第二个班次原有的开始时间和结束时间
      original_start_time = shift2.start_time
      original_end_time = shift2.end_time

      # 11. 尝试修改第二个班次的时间，使其与第一个班次重叠
      shift2.start_time = start_time + 2.hours
      shift2.end_time = start_time + 5.hours

      # 12. 检查修改后的班次是否无法通过验证
      expect(shift2).not_to be_valid

      # 13. 检查错误是否来自班次时间冲突验证
      expect(shift2.errors[:base]).to include(
        "time change conflicts with another confirmed signup"
      )

      # 14. 检查非法的班次时间修改是否无法保存
      expect(shift2.save).to be false

      # 15. 从数据库重新读取第二个班次
      shift2.reload

      # 16. 检查原有开始时间是否保持不变
      expect(shift2.start_time).to eq(original_start_time)

      # 17. 检查原有结束时间是否保持不变
      expect(shift2.end_time).to eq(original_end_time)

      # 18. 检查两个报名是否仍然为 confirmed
      expect(signup1.reload.status).to eq("confirmed")
      expect(signup2.reload.status).to eq("confirmed")

      # 19. 检查 Volunteer 是否仍然拥有两条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(2)

      # 20. 检查两个班次的已确认报名人数是否保持不变
      expect(shift1.confirmed_count).to eq(1)
      expect(shift2.confirmed_count).to eq(1)
    end

    # Test 2: 允许不产生时间冲突的班次时间修改
    it "allows time changes that do not cause conflicts for confirmed volunteers" do
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

      # 8. 让 Volunteer 成功报名第二个 Shift
      signup2 = Signup.create!(
        user: volunteer,
        shift: shift2,
        status: "confirmed"
      )

      # 9. 检查 Volunteer 是否拥有两条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(2)

      # 10. 保存第一个班次原有的开始时间和结束时间
      original_shift1_start_time = shift1.start_time
      original_shift1_end_time = shift1.end_time

      # 11. 设置第二个班次的新开始时间和结束时间
      new_start_time = start_time + 5.hours
      new_end_time = start_time + 8.hours

      # 12. 修改第二个班次的时间
      shift2.start_time = new_start_time
      shift2.end_time = new_end_time

      # 13. 检查修改后的班次是否能够通过验证
      expect(shift2).to be_valid

      # 14. 检查是否没有产生时间冲突错误
      expect(shift2.errors[:base]).not_to include(
        "time change conflicts with another confirmed signup"
      )

      # 15. 检查合法的班次时间修改是否能够成功保存
      expect(shift2.save).to be true

      # 16. 从数据库重新读取两个班次
      shift1.reload
      shift2.reload

      # 17. 检查第二个班次的开始时间是否成功修改
      expect(shift2.start_time).to eq(new_start_time)

      # 18. 检查第二个班次的结束时间是否成功修改
      expect(shift2.end_time).to eq(new_end_time)

      # 19. 检查第一个班次的时间是否保持不变
      expect(shift1.start_time).to eq(original_shift1_start_time)
      expect(shift1.end_time).to eq(original_shift1_end_time)

      # 20. 检查两个班次是否仍然不存在时间重叠
      expect(shift2.start_time).to be >= shift1.end_time

      # 21. 检查两个报名是否仍然为 confirmed
      expect(signup1.reload.status).to eq("confirmed")
      expect(signup2.reload.status).to eq("confirmed")

      # 22. 检查 Volunteer 是否仍然拥有两条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(2)

      # 23. 检查两个班次的已确认报名人数是否保持不变
      expect(shift1.confirmed_count).to eq(1)
      expect(shift2.confirmed_count).to eq(1)

      # 24. 检查两个班次的容量是否保持不变
      expect(shift1.capacity).to eq(20)
      expect(shift2.capacity).to eq(20)
    end

    # Test 3: 允许没有报名记录的班次修改时间
    it "allows time changes for shifts without signups" do
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

      # 8. 检查第一个班次是否拥有一条已确认报名记录
      expect(shift1.confirmed_count).to eq(1)

      # 9. 检查第二个班次是否没有任何报名记录
      expect(shift2.signups.count).to eq(0)

      # 10. 设置第二个班次的新开始时间和结束时间
      new_start_time = start_time + 2.hours
      new_end_time = start_time + 5.hours

      # 11. 修改第二个班次的时间，使其与第一个班次重叠
      shift2.start_time = new_start_time
      shift2.end_time = new_end_time

      # 12. 检查修改后的班次是否能够通过验证
      expect(shift2).to be_valid

      # 13. 检查是否没有产生时间冲突错误
      expect(shift2.errors[:base]).not_to include(
        "time change conflicts with another confirmed signup"
      )

      # 14. 检查班次时间修改是否能够成功保存
      expect(shift2.save).to be true

      # 15. 从数据库重新读取两个班次
      shift1.reload
      shift2.reload

      # 16. 检查第二个班次的开始时间是否成功修改
      expect(shift2.start_time).to eq(new_start_time)

      # 17. 检查第二个班次的结束时间是否成功修改
      expect(shift2.end_time).to eq(new_end_time)

      # 18. 检查两个班次是否确实存在时间重叠
      expect(shift1.start_time).to be < shift2.end_time
      expect(shift1.end_time).to be > shift2.start_time

      # 19. 检查第一个班次的原有报名是否保持不变
      expect(signup1.reload.status).to eq("confirmed")

      # 20. 检查 Volunteer 是否仍然只有一条报名记录
      expect(volunteer.signups.count).to eq(1)

      # 21. 检查两个班次的已确认报名人数是否正确
      expect(shift1.confirmed_count).to eq(1)
      expect(shift2.confirmed_count).to eq(0)

      # 22. 检查第二个班次是否仍然没有报名记录
      expect(shift2.signups.count).to eq(0)

      # 23. 检查第二个班次的剩余名额是否保持不变
      expect(shift2.available_slots).to eq(20)
    end

    # Test 4: 候补报名不限制班次时间修改
    it "ignores waitlisted signups when checking shift time changes" do
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

      # 5. 创建第二个时间不重叠且容量为 1 的 Shift
      shift2 = Shift.create!(
        activity: activity,
        start_time: start_time + 4.hours,
        end_time: start_time + 7.hours,
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

      # 13. 设置第二个班次的新开始时间和结束时间
      new_start_time = start_time + 2.hours
      new_end_time = start_time + 5.hours

      # 14. 修改第二个班次的时间，使其与第一个班次重叠
      shift2.start_time = new_start_time
      shift2.end_time = new_end_time

      # 15. 检查修改后的班次是否能够通过验证
      expect(shift2).to be_valid

      # 16. 检查是否没有产生时间冲突错误
      expect(shift2.errors[:base]).not_to include(
        "time change conflicts with another confirmed signup"
      )

      # 17. 检查班次时间修改是否能够成功保存
      expect(shift2.save).to be true

      # 18. 从数据库重新读取两个班次
      shift1.reload
      shift2.reload

      # 19. 检查第二个班次的新开始时间是否成功保存
      expect(shift2.start_time).to eq(new_start_time)

      # 20. 检查第二个班次的新结束时间是否成功保存
      expect(shift2.end_time).to eq(new_end_time)

      # 21. 检查两个班次是否确实存在时间重叠
      expect(shift1.start_time).to be < shift2.end_time
      expect(shift1.end_time).to be > shift2.start_time

      # 22. 检查第一个报名是否仍然为 confirmed
      expect(signup1.reload.status).to eq("confirmed")

      # 23. 检查第二个报名是否仍然为 waitlisted
      expect(signup2.reload.status).to eq("waitlisted")

      # 24. 检查另一个 Volunteer 的报名是否保持不变
      expect(other_signup.reload.status).to eq("confirmed")

      # 25. 检查 Volunteer 是否仍然拥有两条报名记录
      expect(volunteer.signups.count).to eq(2)

      # 26. 检查两个班次的已确认报名人数是否保持不变
      expect(shift1.confirmed_count).to eq(1)
      expect(shift2.confirmed_count).to eq(1)

      # 27. 检查第二个班次的候补报名人数是否仍然为 1
      expect(
        shift2.signups.where(status: "waitlisted").count
      ).to eq(1)

      # 28. 检查第二个班次的总报名记录数量是否仍然为 2
      expect(shift2.signups.count).to eq(2)

      # 29. 检查第二个班次是否仍然满员
      expect(shift2.full?).to be true
    end

    # Test 5: 已取消报名不限制班次时间修改
    it "ignores cancelled signups when checking shift time changes" do
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

      # 8. 让 Volunteer 成功报名第二个 Shift
      signup2 = Signup.create!(
        user: volunteer,
        shift: shift2,
        status: "confirmed"
      )

      # 9. 检查 Volunteer 是否拥有两条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(2)

      # 10. 取消第二个 Shift 的报名
      signup2.update!(status: "cancelled")

      # 11. 检查第二个报名是否已经取消
      expect(signup2.reload.status).to eq("cancelled")

      # 12. 检查第二个班次是否已经释放报名名额
      expect(shift2.confirmed_count).to eq(0)
      expect(shift2.available_slots).to eq(20)

      # 13. 检查第二个班次是否仍然保留报名记录
      expect(shift2.signups.count).to eq(1)

      # 14. 设置第二个班次的新开始时间和结束时间
      new_start_time = start_time + 2.hours
      new_end_time = start_time + 5.hours

      # 15. 修改第二个班次的时间，使其与第一个班次重叠
      shift2.start_time = new_start_time
      shift2.end_time = new_end_time

      # 16. 检查修改后的班次是否能够通过验证
      expect(shift2).to be_valid

      # 17. 检查是否没有产生时间冲突错误
      expect(shift2.errors[:base]).not_to include(
        "time change conflicts with another confirmed signup"
      )

      # 18. 检查班次时间修改是否能够成功保存
      expect(shift2.save).to be true

      # 19. 从数据库重新读取两个班次
      shift1.reload
      shift2.reload

      # 20. 检查第二个班次的新开始时间是否成功保存
      expect(shift2.start_time).to eq(new_start_time)

      # 21. 检查第二个班次的新结束时间是否成功保存
      expect(shift2.end_time).to eq(new_end_time)

      # 22. 检查两个班次是否确实存在时间重叠
      expect(shift1.start_time).to be < shift2.end_time
      expect(shift1.end_time).to be > shift2.start_time

      # 23. 检查第一个报名是否仍然为 confirmed
      expect(signup1.reload.status).to eq("confirmed")

      # 24. 检查第二个报名是否仍然为 cancelled
      expect(signup2.reload.status).to eq("cancelled")

      # 25. 检查 Volunteer 是否仍然拥有两条报名记录
      expect(volunteer.signups.count).to eq(2)

      # 26. 检查 Volunteer 是否只有一条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(1)

      # 27. 检查 Volunteer 是否只有一条已取消报名记录
      expect(
        volunteer.signups.where(status: "cancelled").count
      ).to eq(1)

      # 28. 检查两个班次的已确认报名人数是否正确
      expect(shift1.confirmed_count).to eq(1)
      expect(shift2.confirmed_count).to eq(0)

      # 29. 检查第二个班次的剩余名额是否保持不变
      expect(shift2.available_slots).to eq(20)

      # 30. 检查第二个班次是否仍然保留已取消的报名记录
      expect(shift2.signups.count).to eq(1)
    end

    # Test 6: 检查所有已确认 Volunteer 的时间冲突
    it "rejects time changes when any confirmed volunteer has a conflict" do
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

      # 5. 创建第二个与第一个时间不重叠的 Shift
      shift2 = Shift.create!(
        activity: activity,
        start_time: start_time + 4.hours,
        end_time: start_time + 7.hours,
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

      # 8. 创建第三个 Volunteer
      volunteer3 = User.create!(
        email_address: "volunteer3@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 9. 让第二个 Volunteer 成功报名第一个 Shift
      existing_signup = Signup.create!(
        user: volunteer2,
        shift: shift1,
        status: "confirmed"
      )

      # 10. 让第一个 Volunteer 成功报名第二个 Shift
      signup1 = Signup.create!(
        user: volunteer1,
        shift: shift2,
        status: "confirmed"
      )

      # 11. 让第二个 Volunteer 成功报名第二个 Shift
      signup2 = Signup.create!(
        user: volunteer2,
        shift: shift2,
        status: "confirmed"
      )

      # 12. 让第三个 Volunteer 成功报名第二个 Shift
      signup3 = Signup.create!(
        user: volunteer3,
        shift: shift2,
        status: "confirmed"
      )

      # 13. 检查两个班次的已确认报名人数
      expect(shift1.confirmed_count).to eq(1)
      expect(shift2.confirmed_count).to eq(3)

      # 14. 检查第一个 Volunteer 只有一条已确认报名记录
      expect(
        volunteer1.signups.where(status: "confirmed").count
      ).to eq(1)

      # 15. 检查第二个 Volunteer 拥有两条已确认报名记录
      expect(
        volunteer2.signups.where(status: "confirmed").count
      ).to eq(2)

      # 16. 检查第三个 Volunteer 只有一条已确认报名记录
      expect(
        volunteer3.signups.where(status: "confirmed").count
      ).to eq(1)

      # 17. 保存第二个班次原有的开始时间和结束时间
      original_start_time = shift2.start_time
      original_end_time = shift2.end_time

      # 18. 修改第二个班次的时间，使其与第一个班次重叠
      shift2.start_time = start_time + 2.hours
      shift2.end_time = start_time + 5.hours

      # 19. 检查修改后的两个班次是否确实存在时间重叠
      expect(shift1.start_time).to be < shift2.end_time
      expect(shift1.end_time).to be > shift2.start_time

      # 20. 检查修改后的班次是否无法通过验证
      expect(shift2).not_to be_valid

      # 21. 检查错误是否来自班次时间冲突验证
      expect(shift2.errors[:base]).to include(
        "time change conflicts with another confirmed signup"
      )

      # 22. 检查非法的班次时间修改是否无法保存
      expect(shift2.save).to be false

      # 23. 从数据库重新读取第二个班次
      shift2.reload

      # 24. 检查原有开始时间是否保持不变
      expect(shift2.start_time).to eq(original_start_time)

      # 25. 检查原有结束时间是否保持不变
      expect(shift2.end_time).to eq(original_end_time)

      # 26. 检查第一个班次的原有报名是否保持不变
      expect(existing_signup.reload.status).to eq("confirmed")

      # 27. 检查第二个班次的所有报名是否保持不变
      expect(signup1.reload.status).to eq("confirmed")
      expect(signup2.reload.status).to eq("confirmed")
      expect(signup3.reload.status).to eq("confirmed")

      # 28. 检查两个班次的已确认报名人数是否保持不变
      expect(shift1.confirmed_count).to eq(1)
      expect(shift2.confirmed_count).to eq(3)

      # 29. 检查两个班次的总报名记录数量是否保持不变
      expect(shift1.signups.count).to eq(1)
      expect(shift2.signups.count).to eq(3)

      # 30. 检查第二个班次的剩余名额是否保持不变
      expect(shift2.available_slots).to eq(17)

      # 31. 检查两个班次是否仍然不存在时间冲突
      expect(shift2.start_time).to be >= shift1.end_time
    end

    # Test 7: 检测跨 Organization 的时间修改冲突
    it "rejects time changes that cause conflicts across different organizations" do
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
      start_time = 1.day.from_now.change(usec: 0)

      # 6. 创建属于第一个 Activity 的 Shift
      shift1 = Shift.create!(
        activity: activity1,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 7. 创建属于第二个 Activity 且时间不重叠的 Shift
      shift2 = Shift.create!(
        activity: activity2,
        start_time: start_time + 4.hours,
        end_time: start_time + 7.hours,
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

      # 11. 让 Volunteer 成功报名第二个 Organization 的 Shift
      signup2 = Signup.create!(
        user: volunteer,
        shift: shift2,
        status: "confirmed"
      )

      # 12. 检查 Volunteer 是否拥有两条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(2)

      # 13. 保存第二个班次原有的开始时间和结束时间
      original_start_time = shift2.start_time
      original_end_time = shift2.end_time

      # 14. 修改第二个 Organization 的班次时间
      shift2.start_time = start_time + 2.hours
      shift2.end_time = start_time + 5.hours

      # 15. 检查修改后的两个班次是否确实存在时间重叠
      expect(shift1.start_time).to be < shift2.end_time
      expect(shift1.end_time).to be > shift2.start_time

      # 16. 检查跨 Organization 的冲突是否导致验证失败
      expect(shift2).not_to be_valid

      # 17. 检查错误是否来自班次时间冲突验证
      expect(shift2.errors[:base]).to include(
        "time change conflicts with another confirmed signup"
      )

      # 18. 检查非法的班次时间修改是否无法保存
      expect(shift2.save).to be false

      # 19. 从数据库重新读取第二个班次
      shift2.reload

      # 20. 检查原有开始时间是否保持不变
      expect(shift2.start_time).to eq(original_start_time)

      # 21. 检查原有结束时间是否保持不变
      expect(shift2.end_time).to eq(original_end_time)

      # 22. 检查第一个 Organization 的报名是否保持不变
      expect(signup1.reload.status).to eq("confirmed")

      # 23. 检查第二个 Organization 的报名是否保持不变
      expect(signup2.reload.status).to eq("confirmed")

      # 24. 检查 Volunteer 是否仍然拥有两条报名记录
      expect(volunteer.signups.count).to eq(2)

      # 25. 检查 Volunteer 是否仍然拥有两条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(2)

      # 26. 检查两个班次的已确认报名人数是否保持不变
      expect(shift1.confirmed_count).to eq(1)
      expect(shift2.confirmed_count).to eq(1)

      # 27. 检查两个班次的剩余名额是否保持不变
      expect(shift1.available_slots).to eq(19)
      expect(shift2.available_slots).to eq(19)

      # 28. 检查两个班次是否仍然不存在时间冲突
      expect(shift2.start_time).to be >= shift1.end_time

      # 29. 检查两个班次是否仍然属于原有 Organization
      expect(shift1.reload.activity.organization_id).to eq(
        organization1.id
      )

      expect(shift2.activity.organization_id).to eq(
        organization2.id
      )
    end
  end
end
