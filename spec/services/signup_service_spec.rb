
require 'rails_helper'

RSpec.describe SignupService do
  describe ".call" do

    # Test 1: 班次有空余名额时自动确认报名
    it "automatically confirms a signup when the shift has available capacity" do
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
      start_time = 1.day.from_now.change(usec: 0)

      # 4. 创建一个容量为 20 的合法 Shift
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

      # 6. 检查班次尚未有任何已确认报名
      expect(shift.confirmed_count).to eq(0)

      # 7. 检查班次拥有 20 个剩余名额
      expect(shift.available_slots).to eq(20)

      # 8. 检查班次尚未满员
      expect(shift.full?).to be false

      # 9. 初始化用于保存 Service 返回结果的变量
      signup = nil

      # 10. 调用 SignupService 进行报名
      # 不手动指定报名状态，由系统自动判断
      expect {
        signup = SignupService.call(
          user: volunteer,
          shift: shift
        )
      }.to change(Signup, :count).by(1)

      # 11. 检查 Service 是否返回 Signup 对象
      expect(signup).to be_a(Signup)

      # 12. 检查报名记录是否已经保存至数据库
      expect(signup).to be_persisted

      # 13. 从数据库重新读取报名记录
      signup.reload

      # 14. 检查报名是否属于正确的 Volunteer
      expect(signup.user_id).to eq(volunteer.id)

      # 15. 检查报名是否属于正确的 Shift
      expect(signup.shift_id).to eq(shift.id)

      # 16. 检查系统是否自动将报名状态设置为 confirmed
      expect(signup.status).to eq("confirmed")

      # 17. 检查初始出勤状态是否为 pending
      expect(signup.attendance_status).to eq("pending")

      # 18. 检查 Volunteer 是否拥有一条报名记录
      expect(volunteer.signups.count).to eq(1)

      # 19. 检查班次的已确认报名人数是否增加为 1
      expect(shift.confirmed_count).to eq(1)

      # 20. 检查班次的剩余名额是否减少为 19
      expect(shift.available_slots).to eq(19)

      # 21. 检查班次是否仍然未满员
      expect(shift.full?).to be false

      # 22. 检查班次是否不存在候补报名记录
      expect(
        shift.signups.where(status: "waitlisted").count
      ).to eq(0)
    end

    # Test 2: 班次满员时自动进入候补队列
    it "automatically waitlists a signup when the shift is full" do
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
      start_time = 1.day.from_now.change(usec: 0)

      # 4. 创建一个容量为 1 的合法 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 1
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

      # 7. 让第一个 Volunteer 通过 SignupService 报名
      signup1 = SignupService.call(
        user: volunteer1,
        shift: shift
      )

      # 8. 检查第一个报名是否成功保存
      expect(signup1).to be_persisted

      # 9. 检查第一个报名是否为 confirmed
      expect(signup1.reload.status).to eq("confirmed")

      # 10. 检查班次是否已经满员
      expect(shift.confirmed_count).to eq(1)
      expect(shift.available_slots).to eq(0)
      expect(shift.full?).to be true

      # 11. 检查班次尚未有任何候补报名
      expect(
        shift.signups.where(status: "waitlisted").count
      ).to eq(0)

      # 12. 初始化用于保存第二个报名结果的变量
      signup2 = nil

      # 13. 让第二个 Volunteer 通过 SignupService 报名
      # 不手动指定状态，由系统自动判断是否进入候补
      expect {
        signup2 = SignupService.call(
          user: volunteer2,
          shift: shift
        )
      }.to change(Signup, :count).by(1)

      # 14. 检查 Service 是否返回 Signup 对象
      expect(signup2).to be_a(Signup)

      # 15. 检查第二个报名是否成功保存至数据库
      expect(signup2).to be_persisted

      # 16. 从数据库重新读取两个报名记录
      signup1.reload
      signup2.reload

      # 17. 检查第二个报名是否属于正确的 Volunteer
      expect(signup2.user_id).to eq(volunteer2.id)

      # 18. 检查第二个报名是否属于正确的 Shift
      expect(signup2.shift_id).to eq(shift.id)

      # 19. 检查系统是否自动将第二个报名设置为 waitlisted
      expect(signup2.status).to eq("waitlisted")

      # 20. 检查第二个报名的初始出勤状态
      expect(signup2.attendance_status).to eq("pending")

      # 21. 检查第一个报名是否仍然为 confirmed
      expect(signup1.status).to eq("confirmed")

      # 22. 检查第一个 Volunteer 是否只有一条报名记录
      expect(volunteer1.signups.count).to eq(1)

      # 23. 检查第二个 Volunteer 是否只有一条报名记录
      expect(volunteer2.signups.count).to eq(1)

      # 24. 检查班次的已确认报名人数是否保持为 1
      expect(shift.confirmed_count).to eq(1)

      # 25. 检查班次的候补报名人数是否增加为 1
      expect(
        shift.signups.where(status: "waitlisted").count
      ).to eq(1)

      # 26. 检查班次的总报名记录数量是否为 2
      expect(shift.signups.count).to eq(2)

      # 27. 检查候补报名是否没有占用正式名额
      expect(shift.available_slots).to eq(0)

      # 28. 检查班次是否仍然满员
      expect(shift.full?).to be true

      # 29. 检查班次容量是否保持不变
      expect(shift.reload.capacity).to eq(1)
    end

    # Test 3: 有空余名额但存在时间冲突时拒绝报名
    it "rejects a signup when capacity is available but a time conflict exists" do
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

      # 4. 创建第一个容量为 20 的合法 Shift
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

      # 7. 让 Volunteer 通过 SignupService 报名第一个 Shift
      signup1 = SignupService.call(
        user: volunteer,
        shift: shift1
      )

      # 8. 检查第一个报名是否成功保存
      expect(signup1).to be_persisted

      # 9. 检查第一个报名是否为 confirmed
      expect(signup1.reload.status).to eq("confirmed")

      # 10. 检查第二个班次是否拥有足够的空余名额
      expect(shift2.confirmed_count).to eq(0)
      expect(shift2.available_slots).to eq(20)
      expect(shift2.full?).to be false

      # 11. 检查两个班次是否确实存在时间重叠
      expect(shift1.start_time).to be < shift2.end_time
      expect(shift1.end_time).to be > shift2.start_time

      # 12. 初始化用于保存第二个报名结果的变量
      signup2 = nil

      # 13. 尝试通过 SignupService 报名第二个 Shift
      # 检查存在时间冲突时是否不会创建新的报名记录
      expect {
        signup2 = SignupService.call(
          user: volunteer,
          shift: shift2
        )
      }.not_to change(Signup, :count)

      # 14. 检查 Service 是否仍然返回 Signup 对象
      expect(signup2).to be_a(Signup)

      # 15. 检查第二个报名是否未保存至数据库
      expect(signup2).not_to be_persisted

      # 16. 检查第二个报名是否属于正确的 Volunteer
      expect(signup2.user_id).to eq(volunteer.id)

      # 17. 检查第二个报名是否属于正确的 Shift
      expect(signup2.shift_id).to eq(shift2.id)

      # 18. 检查系统是否尝试进行 confirmed 报名
      expect(signup2.status).to eq("confirmed")

      # 19. 检查 Service 返回的 Signup 是否包含时间冲突错误
      expect(signup2.errors[:shift]).to include(
        "overlaps with another confirmed signup"
      )

      # 20. 检查报名失败是否并非由容量不足导致
      expect(signup2.errors[:shift]).not_to include(
        "has reached its capacity"
      )

      # 21. 检查第一个报名是否仍然为 confirmed
      expect(signup1.reload.status).to eq("confirmed")

      # 22. 检查第一个报名的出勤状态是否保持不变
      expect(signup1.attendance_status).to eq("pending")

      # 23. 检查 Volunteer 是否仍然只有一条报名记录
      expect(volunteer.signups.count).to eq(1)

      # 24. 检查 Volunteer 是否仍然只有一条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(1)

      # 25. 检查两个班次的已确认报名人数是否正确
      expect(shift1.confirmed_count).to eq(1)
      expect(shift2.confirmed_count).to eq(0)

      # 26. 检查第二个班次是否没有任何候补报名
      expect(
        shift2.signups.where(status: "waitlisted").count
      ).to eq(0)

      # 27. 检查第二个班次是否没有任何报名记录
      expect(shift2.signups.count).to eq(0)

      # 28. 检查第二个班次的剩余名额是否保持不变
      expect(shift2.available_slots).to eq(20)

      # 29. 检查第二个班次是否仍然未满员
      expect(shift2.full?).to be false
    end

    # Test 4: 班次满员且存在时间冲突时允许候补报名
    it "allows a waitlisted signup when the shift is full despite a time conflict" do
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

      # 4. 创建第一个容量为 20 的合法 Shift
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

      # 8. 让 Volunteer 通过 SignupService 报名第一个 Shift
      signup1 = SignupService.call(
        user: volunteer,
        shift: shift1
      )

      # 9. 检查第一个报名是否成功保存
      expect(signup1).to be_persisted
      expect(signup1.reload.status).to eq("confirmed")

      # 10. 让另一个 Volunteer 通过 SignupService 报名第二个 Shift
      other_signup = SignupService.call(
        user: other_volunteer,
        shift: shift2
      )

      # 11. 检查另一个 Volunteer 是否成功确认报名
      expect(other_signup).to be_persisted
      expect(other_signup.reload.status).to eq("confirmed")

      # 12. 检查第二个班次是否已经满员
      expect(shift2.confirmed_count).to eq(1)
      expect(shift2.available_slots).to eq(0)
      expect(shift2.full?).to be true

      # 13. 检查第二个班次尚未有任何候补报名
      expect(
        shift2.signups.where(status: "waitlisted").count
      ).to eq(0)

      # 14. 检查两个班次是否确实存在时间重叠
      expect(shift1.start_time).to be < shift2.end_time
      expect(shift1.end_time).to be > shift2.start_time

      # 15. 初始化用于保存第二个报名结果的变量
      signup2 = nil

      # 16. 尝试通过 SignupService 报名第二个时间重叠的 Shift
      # 即使存在时间冲突，满员时仍然允许进入候补队列
      expect {
        signup2 = SignupService.call(
          user: volunteer,
          shift: shift2
        )
      }.to change(Signup, :count).by(1)

      # 17. 检查 Service 是否返回 Signup 对象
      expect(signup2).to be_a(Signup)

      # 18. 检查第二个报名是否成功保存至数据库
      expect(signup2).to be_persisted

      # 19. 检查 Service 是否没有返回任何验证错误
      expect(signup2.errors).to be_empty

      # 20. 从数据库重新读取所有报名记录
      signup1.reload
      signup2.reload
      other_signup.reload

      # 21. 检查第二个报名是否属于正确的 Volunteer
      expect(signup2.user_id).to eq(volunteer.id)

      # 22. 检查第二个报名是否属于正确的 Shift
      expect(signup2.shift_id).to eq(shift2.id)

      # 23. 检查系统是否自动将第二个报名设置为 waitlisted
      expect(signup2.status).to eq("waitlisted")

      # 24. 检查第二个报名的初始出勤状态
      expect(signup2.attendance_status).to eq("pending")

      # 25. 检查第一个报名是否仍然为 confirmed
      expect(signup1.status).to eq("confirmed")

      # 26. 检查另一个 Volunteer 的报名是否保持不变
      expect(other_signup.status).to eq("confirmed")

      # 27. 检查 Volunteer 是否拥有两条报名记录
      expect(volunteer.signups.count).to eq(2)

      # 28. 检查 Volunteer 是否只有一条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(1)

      # 29. 检查 Volunteer 是否只有一条候补报名记录
      expect(
        volunteer.signups.where(status: "waitlisted").count
      ).to eq(1)

      # 30. 检查两个班次的已确认报名人数是否保持不变
      expect(shift1.confirmed_count).to eq(1)
      expect(shift2.confirmed_count).to eq(1)

      # 31. 检查第二个班次的候补报名人数是否增加为 1
      expect(
        shift2.signups.where(status: "waitlisted").count
      ).to eq(1)

      # 32. 检查第二个班次的总报名记录数量是否为 2
      expect(shift2.signups.count).to eq(2)

      # 33. 检查候补报名是否没有占用正式名额
      expect(shift2.available_slots).to eq(0)

      # 34. 检查第二个班次是否仍然满员
      expect(shift2.full?).to be true

      # 35. 检查第二个班次容量是否保持不变
      expect(shift2.reload.capacity).to eq(1)
    end

    # Test 5: 禁止 Organizer 报名
    it "rejects signup requests from organizers" do
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
      start_time = 1.day.from_now.change(usec: 0)

      # 4. 创建一个容量为 20 的合法 Shift
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

      # 6. 检查用户是否拥有 Organizer 角色
      expect(organizer.role).to eq("organizer")

      # 7. 检查 Organizer 是否属于正确的 Organization
      expect(organizer.organization_id).to eq(organization.id)

      # 8. 检查班次是否拥有足够的空余名额
      expect(shift.confirmed_count).to eq(0)
      expect(shift.available_slots).to eq(20)
      expect(shift.full?).to be false

      # 9. 检查 Organizer 尚未有任何报名记录
      expect(organizer.signups.count).to eq(0)

      # 10. 初始化用于保存报名结果的变量
      signup = nil

      # 11. 尝试让 Organizer 通过 SignupService 报名
      # 检查非法角色报名是否不会创建新的报名记录
      expect {
        signup = SignupService.call(
          user: organizer,
          shift: shift
        )
      }.not_to change(Signup, :count)

      # 12. 检查 Service 是否仍然返回 Signup 对象
      expect(signup).to be_a(Signup)

      # 13. 检查 Organizer 的报名是否未保存至数据库
      expect(signup).not_to be_persisted

      # 14. 检查返回的报名对象是否属于正确的用户
      expect(signup.user_id).to eq(organizer.id)

      # 15. 检查返回的报名对象是否属于正确的 Shift
      expect(signup.shift_id).to eq(shift.id)

      # 16. 检查系统是否尝试进行 confirmed 报名
      expect(signup.status).to eq("confirmed")

      # 17. 检查 Service 是否正确返回角色验证错误
      expect(signup.errors[:user]).to include(
        "must be a volunteer"
      )

      # 18. 检查报名失败是否并非由容量不足导致
      expect(signup.errors[:shift]).not_to include(
        "has reached its capacity"
      )

      # 19. 检查报名失败是否并非由时间冲突导致
      expect(signup.errors[:shift]).not_to include(
        "overlaps with another confirmed signup"
      )

      # 20. 检查 Organizer 是否仍然没有任何报名记录
      expect(organizer.signups.count).to eq(0)

      # 21. 检查班次是否没有任何已确认报名记录
      expect(shift.confirmed_count).to eq(0)

      # 22. 检查班次是否没有任何候补报名记录
      expect(
        shift.signups.where(status: "waitlisted").count
      ).to eq(0)

      # 23. 检查班次是否没有任何报名记录
      expect(shift.signups.count).to eq(0)

      # 24. 检查班次的剩余名额是否保持不变
      expect(shift.available_slots).to eq(20)

      # 25. 检查班次是否仍然未满员
      expect(shift.full?).to be false

      # 26. 检查 Organizer 的角色是否保持不变
      expect(organizer.reload.role).to eq("organizer")

      # 27. 检查 Organizer 所属的 Organization 是否保持不变
      expect(organizer.organization_id).to eq(organization.id)

      # 28. 检查班次容量是否保持不变
      expect(shift.reload.capacity).to eq(20)
    end

    # Test 6: 禁止重复确认报名
    it "rejects duplicate signups for an already confirmed volunteer" do
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
      start_time = 1.day.from_now.change(usec: 0)

      # 4. 创建一个容量为 20 的合法 Shift
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

      # 6. 让 Volunteer 通过 SignupService 成功报名
      signup1 = SignupService.call(
        user: volunteer,
        shift: shift
      )

      # 7. 检查第一次报名是否成功保存
      expect(signup1).to be_persisted

      # 8. 检查第一次报名是否为 confirmed
      expect(signup1.reload.status).to eq("confirmed")

      # 9. 保存原有报名的 ID 和时间信息
      original_signup_id = signup1.id
      original_created_at = signup1.created_at
      original_updated_at = signup1.updated_at

      # 10. 检查班次是否仍然拥有空余名额
      expect(shift.confirmed_count).to eq(1)
      expect(shift.available_slots).to eq(19)
      expect(shift.full?).to be false

      # 11. 检查 Volunteer 是否只有一条报名记录
      expect(volunteer.signups.count).to eq(1)

      # 12. 初始化用于保存重复报名结果的变量
      signup2 = nil

      # 13. 让同一个 Volunteer 尝试重复报名同一个 Shift
      # 检查重复报名是否不会创建新的报名记录
      expect {
        signup2 = SignupService.call(
          user: volunteer,
          shift: shift
        )
      }.not_to change(Signup, :count)

      # 14. 检查 Service 是否仍然返回 Signup 对象
      expect(signup2).to be_a(Signup)

      # 15. 检查重复报名是否未保存至数据库
      expect(signup2).not_to be_persisted

      # 16. 检查重复报名对象是否属于正确的 Volunteer
      expect(signup2.user_id).to eq(volunteer.id)

      # 17. 检查重复报名对象是否属于相同的 Shift
      expect(signup2.shift_id).to eq(shift.id)

      # 18. 检查系统是否尝试进行 confirmed 报名
      expect(signup2.status).to eq("confirmed")

      # 19. 检查 Service 是否正确返回重复报名验证错误
      expect(
        signup2.errors.of_kind?(:user_id, :taken)
      ).to be true

      # 20. 检查重复报名失败是否并非由容量不足导致
      expect(signup2.errors[:shift]).not_to include(
        "has reached its capacity"
      )

      # 21. 从数据库重新读取原有报名记录
      signup1.reload

      # 22. 检查原有报名记录的 ID 是否保持不变
      expect(signup1.id).to eq(original_signup_id)

      # 23. 检查原有报名状态是否仍然为 confirmed
      expect(signup1.status).to eq("confirmed")

      # 24. 检查原有报名的出勤状态是否保持不变
      expect(signup1.attendance_status).to eq("pending")

      # 25. 检查原有报名的创建时间和更新时间是否保持不变
      expect(signup1.created_at).to eq(original_created_at)
      expect(signup1.updated_at).to eq(original_updated_at)

      # 26. 检查 Volunteer 是否仍然只有一条报名记录
      expect(volunteer.signups.count).to eq(1)

      # 27. 检查 Volunteer 是否仍然只有一条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(1)

      # 28. 检查班次的已确认报名人数是否保持为 1
      expect(shift.confirmed_count).to eq(1)

      # 29. 检查班次是否没有任何候补报名记录
      expect(
        shift.signups.where(status: "waitlisted").count
      ).to eq(0)

      # 30. 检查班次的总报名记录数量是否保持为 1
      expect(shift.signups.count).to eq(1)

      # 31. 检查班次的剩余名额是否保持为 19
      expect(shift.available_slots).to eq(19)

      # 32. 检查班次是否仍然未满员
      expect(shift.full?).to be false

      # 33. 检查班次容量是否保持不变
      expect(shift.reload.capacity).to eq(20)
    end

    # Test 7: 禁止重复候补报名
    it "rejects duplicate signups for an already waitlisted volunteer" do
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
      start_time = 1.day.from_now.change(usec: 0)

      # 4. 创建一个容量为 1 的合法 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 1
      )

      # 5. 创建用于占满班次的 Volunteer
      other_volunteer = User.create!(
        email_address: "other_volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 6. 创建需要进行重复候补检测的 Volunteer
      volunteer = User.create!(
        email_address: "volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 7. 让另一个 Volunteer 占用班次的唯一名额
      other_signup = SignupService.call(
        user: other_volunteer,
        shift: shift
      )

      # 8. 检查另一个 Volunteer 是否成功确认报名
      expect(other_signup).to be_persisted
      expect(other_signup.reload.status).to eq("confirmed")

      # 9. 检查班次是否已经满员
      expect(shift.confirmed_count).to eq(1)
      expect(shift.available_slots).to eq(0)
      expect(shift.full?).to be true

      # 10. 让 Volunteer 通过 SignupService 加入候补队列
      signup1 = SignupService.call(
        user: volunteer,
        shift: shift
      )

      # 11. 检查第一次候补报名是否成功保存
      expect(signup1).to be_persisted

      # 12. 检查第一次报名是否为 waitlisted
      expect(signup1.reload.status).to eq("waitlisted")

      # 13. 检查班次是否拥有一条候补报名记录
      expect(
        shift.signups.where(status: "waitlisted").count
      ).to eq(1)

      # 14. 检查 Volunteer 是否只有一条报名记录
      expect(volunteer.signups.count).to eq(1)

      # 15. 保存原有候补报名的 ID 和时间信息
      original_signup_id = signup1.id
      original_created_at = signup1.created_at
      original_updated_at = signup1.updated_at

      # 16. 初始化用于保存重复候补报名结果的变量
      signup2 = nil

      # 17. 让同一个 Volunteer 尝试再次加入候补队列
      # 检查重复候补是否不会创建新的报名记录
      expect {
        signup2 = SignupService.call(
          user: volunteer,
          shift: shift
        )
      }.not_to change(Signup, :count)

      # 18. 检查 Service 是否仍然返回 Signup 对象
      expect(signup2).to be_a(Signup)

      # 19. 检查重复候补报名是否未保存至数据库
      expect(signup2).not_to be_persisted

      # 20. 检查重复候补报名对象是否属于正确的 Volunteer
      expect(signup2.user_id).to eq(volunteer.id)

      # 21. 检查重复候补报名对象是否属于相同的 Shift
      expect(signup2.shift_id).to eq(shift.id)

      # 22. 检查系统是否尝试进行 waitlisted 报名
      expect(signup2.status).to eq("waitlisted")

      # 23. 检查 Service 是否正确返回重复报名验证错误
      expect(
        signup2.errors.of_kind?(:user_id, :taken)
      ).to be true

      # 24. 检查重复候补失败是否并非由容量验证导致
      expect(signup2.errors[:shift]).not_to include(
        "has reached its capacity"
      )

      # 25. 检查重复候补失败是否并非由时间冲突导致
      expect(signup2.errors[:shift]).not_to include(
        "overlaps with another confirmed signup"
      )

      # 26. 从数据库重新读取原有报名记录
      signup1.reload
      other_signup.reload

      # 27. 检查原有候补报名记录的 ID 是否保持不变
      expect(signup1.id).to eq(original_signup_id)

      # 28. 检查原有报名状态是否仍然为 waitlisted
      expect(signup1.status).to eq("waitlisted")

      # 29. 检查原有候补报名的出勤状态是否保持不变
      expect(signup1.attendance_status).to eq("pending")

      # 30. 检查原有候补报名的创建时间和更新时间是否保持不变
      expect(signup1.created_at).to eq(original_created_at)
      expect(signup1.updated_at).to eq(original_updated_at)

      # 31. 检查另一个 Volunteer 的报名是否仍然为 confirmed
      expect(other_signup.status).to eq("confirmed")

      # 32. 检查 Volunteer 是否仍然只有一条报名记录
      expect(volunteer.signups.count).to eq(1)

      # 33. 检查 Volunteer 是否仍然只有一条候补报名记录
      expect(
        volunteer.signups.where(status: "waitlisted").count
      ).to eq(1)

      # 34. 检查 Volunteer 是否没有任何已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(0)

      # 35. 检查班次的已确认报名人数是否保持为 1
      expect(shift.confirmed_count).to eq(1)

      # 36. 检查班次的候补报名人数是否保持为 1
      expect(
        shift.signups.where(status: "waitlisted").count
      ).to eq(1)

      # 37. 检查班次的总报名记录数量是否保持为 2
      expect(shift.signups.count).to eq(2)

      # 38. 检查班次的剩余名额是否保持为 0
      expect(shift.available_slots).to eq(0)

      # 39. 检查班次是否仍然满员
      expect(shift.full?).to be true

      # 40. 检查班次容量是否保持不变
      expect(shift.reload.capacity).to eq(1)
    end

    # Test 8: 允许取消报名后重新报名
    it "allows a volunteer to sign up again after cancellation" do
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
      start_time = 1.day.from_now.change(usec: 0)

      # 4. 创建一个容量为 20 的合法 Shift
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

      # 6. 让 Volunteer 通过 SignupService 进行第一次报名
      signup1 = SignupService.call(
        user: volunteer,
        shift: shift
      )

      # 7. 检查第一次报名是否成功保存
      expect(signup1).to be_persisted

      # 8. 检查第一次报名是否为 confirmed
      expect(signup1.reload.status).to eq("confirmed")

      # 9. 保存原有报名记录的 ID 和创建时间
      original_signup_id = signup1.id
      original_created_at = signup1.created_at

      # 10. 检查第一次报名是否成功占用一个名额
      expect(shift.confirmed_count).to eq(1)
      expect(shift.available_slots).to eq(19)

      # 11. 检查 Volunteer 是否只有一条报名记录
      expect(volunteer.signups.count).to eq(1)

      # 12. 模拟 Volunteer 取消报名
      signup1.update!(status: "cancelled")

      # 13. 检查报名状态是否成功变为 cancelled
      expect(signup1.reload.status).to eq("cancelled")

      # 14. 检查取消报名后原有记录是否仍然存在
      expect(signup1).to be_persisted
      expect(volunteer.signups.count).to eq(1)

      # 15. 检查取消报名是否成功释放名额
      expect(shift.confirmed_count).to eq(0)
      expect(shift.available_slots).to eq(20)
      expect(shift.full?).to be false

      # 16. 检查班次是否拥有一条已取消报名记录
      expect(
        shift.signups.where(status: "cancelled").count
      ).to eq(1)

      # 17. 初始化用于保存重新报名结果的变量
      signup2 = nil

      # 18. 让 Volunteer 通过 SignupService 重新报名
      # 检查重新报名是否不会创建新的报名记录
      expect {
        signup2 = SignupService.call(
          user: volunteer,
          shift: shift
        )
      }.not_to change(Signup, :count)

      # 19. 检查 Service 是否返回 Signup 对象
      expect(signup2).to be_a(Signup)

      # 20. 检查重新报名是否成功保存至数据库
      expect(signup2).to be_persisted

      # 21. 检查重新报名是否没有任何验证错误
      expect(signup2.errors).to be_empty

      # 22. 从数据库重新读取报名记录
      signup1.reload
      signup2.reload

      # 23. 检查重新报名是否复用了原有报名记录
      expect(signup2.id).to eq(original_signup_id)

      # 24. 检查原有报名记录的 ID 是否保持不变
      expect(signup1.id).to eq(original_signup_id)

      # 25. 检查报名记录的创建时间是否保持不变
      expect(signup2.created_at).to eq(original_created_at)

      # 26. 检查重新报名是否属于正确的 Volunteer
      expect(signup2.user_id).to eq(volunteer.id)

      # 27. 检查重新报名是否属于正确的 Shift
      expect(signup2.shift_id).to eq(shift.id)

      # 28. 检查重新报名的状态是否为 confirmed
      expect(signup2.status).to eq("confirmed")

      # 29. 检查原有报名记录是否已重新激活
      expect(signup1.status).to eq("confirmed")

      # 30. 检查重新报名的出勤状态是否为 pending
      expect(signup2.attendance_status).to eq("pending")

      # 31. 检查 Volunteer 是否仍然只有一条报名记录
      expect(volunteer.signups.count).to eq(1)

      # 32. 检查 Volunteer 是否拥有一条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(1)

      # 33. 检查 Volunteer 是否没有已取消报名记录
      expect(
        volunteer.signups.where(status: "cancelled").count
      ).to eq(0)

      # 34. 检查班次是否没有任何候补报名记录
      expect(
        shift.signups.where(status: "waitlisted").count
      ).to eq(0)

      # 35. 检查班次是否没有任何已取消报名记录
      expect(
        shift.signups.where(status: "cancelled").count
      ).to eq(0)

      # 36. 检查班次的已确认报名人数是否恢复为 1
      expect(shift.confirmed_count).to eq(1)

      # 37. 检查班次的总报名记录数量是否仍然为 1
      expect(shift.signups.count).to eq(1)

      # 38. 检查班次的剩余名额是否恢复为 19
      expect(shift.available_slots).to eq(19)

      # 39. 检查班次是否仍然未满员
      expect(shift.full?).to be false

      # 40. 检查班次容量是否保持不变
      expect(shift.reload.capacity).to eq(20)
    end

    # Test 9: 重新报名时重新判断班次容量
    it "automatically waitlists a returning volunteer when the shift has become full" do
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
      start_time = 1.day.from_now.change(usec: 0)

      # 4. 创建一个容量为 1 的合法 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 1
      )

      # 5. 创建需要重新报名的 Volunteer
      volunteer = User.create!(
        email_address: "volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 6. 创建用于占用空余名额的 Volunteer
      other_volunteer = User.create!(
        email_address: "other_volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 7. 让第一个 Volunteer 通过 SignupService 报名
      signup1 = SignupService.call(
        user: volunteer,
        shift: shift
      )

      # 8. 检查第一次报名是否成功保存
      expect(signup1).to be_persisted

      # 9. 检查第一次报名是否为 confirmed
      expect(signup1.reload.status).to eq("confirmed")

      # 10. 保存原有报名记录的 ID 和创建时间
      original_signup_id = signup1.id
      original_created_at = signup1.created_at

      # 11. 检查班次是否已经满员
      expect(shift.confirmed_count).to eq(1)
      expect(shift.available_slots).to eq(0)
      expect(shift.full?).to be true

      # 12. 模拟第一个 Volunteer 取消报名
      signup1.update!(status: "cancelled")

      # 13. 检查报名状态是否成功变为 cancelled
      expect(signup1.reload.status).to eq("cancelled")

      # 14. 检查取消报名是否成功释放名额
      expect(shift.confirmed_count).to eq(0)
      expect(shift.available_slots).to eq(1)
      expect(shift.full?).to be false

      # 15. 让另一个 Volunteer 报名并占用空余名额
      other_signup = SignupService.call(
        user: other_volunteer,
        shift: shift
      )

      # 16. 检查另一个 Volunteer 是否成功确认报名
      expect(other_signup).to be_persisted
      expect(other_signup.reload.status).to eq("confirmed")

      # 17. 保存另一个 Volunteer 报名记录的更新时间
      other_original_updated_at = other_signup.updated_at

      # 18. 检查班次是否再次满员
      expect(shift.confirmed_count).to eq(1)
      expect(shift.available_slots).to eq(0)
      expect(shift.full?).to be true

      # 19. 检查班次是否拥有两条报名记录
      expect(shift.signups.count).to eq(2)

      # 20. 检查班次是否拥有一条已取消报名记录
      expect(
        shift.signups.where(status: "cancelled").count
      ).to eq(1)

      # 21. 检查班次尚未有任何候补报名记录
      expect(
        shift.signups.where(status: "waitlisted").count
      ).to eq(0)

      # 22. 初始化用于保存重新报名结果的变量
      signup2 = nil

      # 23. 让第一个 Volunteer 通过 SignupService 重新报名
      # 检查重新报名是否不会创建新的报名记录
      expect {
        signup2 = SignupService.call(
          user: volunteer,
          shift: shift
        )
      }.not_to change(Signup, :count)

      # 24. 检查 Service 是否返回 Signup 对象
      expect(signup2).to be_a(Signup)

      # 25. 检查重新报名是否成功保存至数据库
      expect(signup2).to be_persisted

      # 26. 检查重新报名是否没有任何验证错误
      expect(signup2.errors).to be_empty

      # 27. 从数据库重新读取所有报名记录
      signup1.reload
      signup2.reload
      other_signup.reload

      # 28. 检查重新报名是否复用了原有报名记录
      expect(signup2.id).to eq(original_signup_id)

      # 29. 检查原有报名记录的创建时间是否保持不变
      expect(signup2.created_at).to eq(original_created_at)

      # 30. 检查重新报名是否属于正确的 Volunteer
      expect(signup2.user_id).to eq(volunteer.id)

      # 31. 检查重新报名是否属于正确的 Shift
      expect(signup2.shift_id).to eq(shift.id)

      # 32. 检查系统是否根据当前容量将报名设置为 waitlisted
      expect(signup2.status).to eq("waitlisted")

      # 33. 检查原有报名记录是否已重新激活为 waitlisted
      expect(signup1.status).to eq("waitlisted")

      # 34. 检查重新报名的出勤状态是否为 pending
      expect(signup2.attendance_status).to eq("pending")

      # 35. 检查另一个 Volunteer 的报名是否仍然为 confirmed
      expect(other_signup.status).to eq("confirmed")

      # 36. 检查另一个 Volunteer 的报名更新时间是否保持不变
      expect(other_signup.updated_at).to eq(
        other_original_updated_at
      )

      # 37. 检查第一个 Volunteer 是否仍然只有一条报名记录
      expect(volunteer.signups.count).to eq(1)

      # 38. 检查第一个 Volunteer 是否拥有一条候补报名记录
      expect(
        volunteer.signups.where(status: "waitlisted").count
      ).to eq(1)

      # 39. 检查第一个 Volunteer 是否没有已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(0)

      # 40. 检查第一个 Volunteer 是否没有已取消报名记录
      expect(
        volunteer.signups.where(status: "cancelled").count
      ).to eq(0)

      # 41. 检查班次的已确认报名人数是否保持为 1
      expect(shift.confirmed_count).to eq(1)

      # 42. 检查班次的候补报名人数是否增加为 1
      expect(
        shift.signups.where(status: "waitlisted").count
      ).to eq(1)

      # 43. 检查班次是否没有已取消报名记录
      expect(
        shift.signups.where(status: "cancelled").count
      ).to eq(0)

      # 44. 检查班次的总报名记录数量是否保持为 2
      expect(shift.signups.count).to eq(2)

      # 45. 检查班次的剩余名额是否保持为 0
      expect(shift.available_slots).to eq(0)

      # 46. 检查班次是否仍然满员
      expect(shift.full?).to be true

      # 47. 检查班次容量是否保持不变
      expect(shift.reload.capacity).to eq(1)
    end

    # Test 10: 重新报名时重新检查时间冲突
    it "rejects a returning volunteer when a new time conflict exists" do
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

      # 4. 创建第一个容量为 20 的合法 Shift
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

      # 7. 让 Volunteer 报名第一个 Shift
      signup1 = SignupService.call(
        user: volunteer,
        shift: shift1
      )

      # 8. 检查第一次报名是否成功保存
      expect(signup1).to be_persisted

      # 9. 检查第一次报名是否为 confirmed
      expect(signup1.reload.status).to eq("confirmed")

      # 10. 保存原有报名记录的 ID 和创建时间
      original_signup_id = signup1.id
      original_created_at = signup1.created_at

      # 11. 检查第一个班次是否成功占用一个名额
      expect(shift1.confirmed_count).to eq(1)
      expect(shift1.available_slots).to eq(19)

      # 12. 模拟 Volunteer 取消第一个班次的报名
      signup1.update!(status: "cancelled")

      # 13. 检查第一个报名是否成功变为 cancelled
      expect(signup1.reload.status).to eq("cancelled")

      # 14. 保存取消报名后的更新时间
      cancelled_updated_at = signup1.updated_at

      # 15. 检查取消报名是否成功释放名额
      expect(shift1.confirmed_count).to eq(0)
      expect(shift1.available_slots).to eq(20)
      expect(shift1.full?).to be false

      # 16. 检查两个班次是否确实存在时间重叠
      expect(shift1.start_time).to be < shift2.end_time
      expect(shift1.end_time).to be > shift2.start_time

      # 17. 让 Volunteer 报名第二个时间重叠的 Shift
      signup2 = SignupService.call(
        user: volunteer,
        shift: shift2
      )

      # 18. 检查第二个报名是否成功保存
      expect(signup2).to be_persisted

      # 19. 检查第二个报名是否为 confirmed
      expect(signup2.reload.status).to eq("confirmed")

      # 20. 检查第二个报名是否没有任何验证错误
      expect(signup2.errors).to be_empty

      # 21. 保存第二个报名记录的更新时间
      second_original_updated_at = signup2.updated_at

      # 22. 检查 Volunteer 是否拥有两条报名记录
      expect(volunteer.signups.count).to eq(2)

      # 23. 检查第一个班次是否仍然拥有空余名额
      expect(shift1.confirmed_count).to eq(0)
      expect(shift1.available_slots).to eq(20)
      expect(shift1.full?).to be false

      # 24. 初始化用于保存重新报名结果的变量
      signup3 = nil

      # 25. 尝试重新报名第一个 Shift
      # 检查重新报名是否不会创建新的报名记录
      expect {
        signup3 = SignupService.call(
          user: volunteer,
          shift: shift1
        )
      }.not_to change(Signup, :count)

      # 26. 检查 Service 是否仍然返回 Signup 对象
      expect(signup3).to be_a(Signup)

      # 27. 检查重新报名是否复用了原有报名对象
      expect(signup3).to be_persisted
      expect(signup3.id).to eq(original_signup_id)

      # 28. 检查重新报名对象是否属于正确的 Volunteer
      expect(signup3.user_id).to eq(volunteer.id)

      # 29. 检查重新报名对象是否属于正确的 Shift
      expect(signup3.shift_id).to eq(shift1.id)

      # 30. 检查系统是否尝试进行 confirmed 报名
      expect(signup3.status).to eq("confirmed")

      # 31. 检查 Service 是否正确返回时间冲突错误
      expect(signup3.errors[:shift]).to include(
        "overlaps with another confirmed signup"
      )

      # 32. 检查报名失败是否并非由容量不足导致
      expect(signup3.errors[:shift]).not_to include(
        "has reached its capacity"
      )

      # 33. 检查报名失败是否并非由重复报名导致
      expect(
        signup3.errors.of_kind?(:user_id, :taken)
      ).to be false

      # 34. 检查数据库中的原有报名状态是否仍然为 cancelled
      expect(signup1.reload.status).to eq("cancelled")

      # 35. 检查原有报名记录的 ID 是否保持不变
      expect(signup1.id).to eq(original_signup_id)

      # 36. 检查原有报名记录的创建时间是否保持不变
      expect(signup1.created_at).to eq(original_created_at)

      # 37. 检查重新报名失败是否没有修改数据库中的更新时间
      expect(signup1.updated_at).to eq(cancelled_updated_at)

      # 38. 检查原有报名的出勤状态是否保持不变
      expect(signup1.attendance_status).to eq("pending")

      # 39. 检查第二个报名是否仍然为 confirmed
      expect(signup2.reload.status).to eq("confirmed")

      # 40. 检查第二个报名的更新时间是否保持不变
      expect(signup2.updated_at).to eq(
        second_original_updated_at
      )

      # 41. 检查 Volunteer 是否仍然只有两条报名记录
      expect(volunteer.signups.count).to eq(2)

      # 42. 检查 Volunteer 是否只有一条已确认报名记录
      expect(
        volunteer.signups.where(status: "confirmed").count
      ).to eq(1)

      # 43. 检查 Volunteer 是否只有一条已取消报名记录
      expect(
        volunteer.signups.where(status: "cancelled").count
      ).to eq(1)

      # 44. 检查 Volunteer 是否没有候补报名记录
      expect(
        volunteer.signups.where(status: "waitlisted").count
      ).to eq(0)

      # 45. 检查两个班次的已确认报名人数是否保持不变
      expect(shift1.confirmed_count).to eq(0)
      expect(shift2.confirmed_count).to eq(1)

      # 46. 检查两个班次的剩余名额是否保持不变
      expect(shift1.available_slots).to eq(20)
      expect(shift2.available_slots).to eq(19)

      # 47. 检查两个班次是否分别只有一条报名记录
      expect(shift1.signups.count).to eq(1)
      expect(shift2.signups.count).to eq(1)

      # 48. 检查两个班次是否仍然未满员
      expect(shift1.full?).to be false
      expect(shift2.full?).to be false

      # 49. 检查两个班次的容量是否保持不变
      expect(shift1.reload.capacity).to eq(20)
      expect(shift2.reload.capacity).to eq(20)
    end

  end
end
