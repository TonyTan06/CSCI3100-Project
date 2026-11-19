
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
