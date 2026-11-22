
# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end


# ==================================================
# 1. Organizations
# ==================================================

# 创建 Organization A
organization_a = Organization.find_or_create_by!(
  name: "CUHK Volunteer Team"
)

# 创建 Organization B
organization_b = Organization.find_or_create_by!(
  name: "CUHK Community Service"
)

puts "Organizations created successfully."


# ==================================================
# 2. Organizers
# ==================================================

# 创建 Organization A 的 Organizer
organizer_a = User.find_or_create_by!(
  email_address: "organizer1@example.com"
) do |user|
  user.password = "password123"
  user.password_confirmation = "password123"
  user.role = "organizer"
  user.organization = organization_a
end

# 创建 Organization B 的 Organizer
organizer_b = User.find_or_create_by!(
  email_address: "organizer2@example.com"
) do |user|
  user.password = "password123"
  user.password_confirmation = "password123"
  user.role = "organizer"
  user.organization = organization_b
end

puts "Organizers created successfully."


# ==================================================
# 3. Volunteers
# ==================================================

# 创建 Volunteer A
volunteer_a = User.find_or_create_by!(
  email_address: "volunteer1@example.com"
) do |user|
  user.password = "password123"
  user.password_confirmation = "password123"
  user.role = "volunteer"
end

# 创建 Volunteer B
volunteer_b = User.find_or_create_by!(
  email_address: "volunteer2@example.com"
) do |user|
  user.password = "password123"
  user.password_confirmation = "password123"
  user.role = "volunteer"
end

puts "Volunteers created successfully."


# ==================================================
# 4. Activities
# ==================================================

# 创建 Organization A 的 Campus Cleanup
campus_cleanup = Activity.find_or_create_by!(
  organization: organization_a,
  title: "Campus Cleanup"
) do |activity|
  activity.description = "Help keep the CUHK campus clean and green."
  activity.location = "CUHK Main Campus"
end

# 创建 Organization A 的 Library Support
library_support = Activity.find_or_create_by!(
  organization: organization_a,
  title: "Library Support"
) do |activity|
  activity.description = "Assist with organizing books and supporting library services."
  activity.location = "CUHK University Library"
end

# 创建 Organization B 的 Community Tutoring
community_tutoring = Activity.find_or_create_by!(
  organization: organization_b,
  title: "Community Tutoring"
) do |activity|
  activity.description = "Support local students through volunteer tutoring sessions."
  activity.location = "Sha Tin Community Centre"
end

puts "Activities created successfully."


# ==================================================
# 5. Shifts
# ==================================================

# 创建 Campus Cleanup 的第一个班次
# 容量为 1，用于演示满员及 Waitlist
campus_shift_1 = Shift.find_or_create_by!(
  activity: campus_cleanup,
  start_time: Time.zone.local(2027, 1, 12, 9, 0)
) do |shift|
  shift.end_time = Time.zone.local(2027, 1, 12, 12, 0)
  shift.capacity = 1
end

# 创建 Campus Cleanup 的第二个班次
campus_shift_2 = Shift.find_or_create_by!(
  activity: campus_cleanup,
  start_time: Time.zone.local(2027, 1, 13, 14, 0)
) do |shift|
  shift.end_time = Time.zone.local(2027, 1, 13, 17, 0)
  shift.capacity = 5
end

# 创建 Library Support 班次
library_shift = Shift.find_or_create_by!(
  activity: library_support,
  start_time: Time.zone.local(2027, 1, 14, 10, 0)
) do |shift|
  shift.end_time = Time.zone.local(2027, 1, 14, 12, 0)
  shift.capacity = 4
end

# 创建 Community Tutoring 的第一个班次
community_shift_1 = Shift.find_or_create_by!(
  activity: community_tutoring,
  start_time: Time.zone.local(2027, 1, 15, 9, 0)
) do |shift|
  shift.end_time = Time.zone.local(2027, 1, 15, 12, 0)
  shift.capacity = 3
end

# 创建 Community Tutoring 的第二个班次
community_shift_2 = Shift.find_or_create_by!(
  activity: community_tutoring,
  start_time: Time.zone.local(2027, 1, 16, 14, 0)
) do |shift|
  shift.end_time = Time.zone.local(2027, 1, 16, 17, 0)
  shift.capacity = 5
end

puts "Shifts created successfully."


# ==================================================
# 6. Signups
# ==================================================

# Volunteer A 报名 Campus Cleanup 的第一个班次
# 容量为 1，因此该报名占用全部名额
Signup.find_or_create_by!(
  user: volunteer_a,
  shift: campus_shift_1
) do |signup|
  signup.status = "confirmed"
  signup.attendance_status = "pending"
end

# Volunteer B 加入 Campus Cleanup 的候补队列
# waitlisted_at 由 Signup Model 自动设置
Signup.find_or_create_by!(
  user: volunteer_b,
  shift: campus_shift_1
) do |signup|
  signup.status = "waitlisted"
  signup.attendance_status = "pending"
end

# Volunteer B 正式报名 Library Support
Signup.find_or_create_by!(
  user: volunteer_b,
  shift: library_shift
) do |signup|
  signup.status = "confirmed"
  signup.attendance_status = "pending"
end

# Volunteer A 正式报名 Community Tutoring
# 出勤状态为 Present，用于演示 Attendance 统计
Signup.find_or_create_by!(
  user: volunteer_a,
  shift: community_shift_1
) do |signup|
  signup.status = "confirmed"
  signup.attendance_status = "present"
end

puts "Signups created successfully."


# ==================================================
# 7. Demo Data Summary
# ==================================================

puts "=========================================="
puts "VolunteerHub demo data is ready."
puts "Organizations: #{Organization.count}"
puts "Users: #{User.count}"
puts "Activities: #{Activity.count}"
puts "Shifts: #{Shift.count}"
puts "Signups: #{Signup.count}"
puts "=========================================="
