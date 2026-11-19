
require 'rails_helper'

RSpec.describe Organization, type: :model do
  describe "validations" do

    # Test 1: 组织必须拥有名称
    it "requires a name" do
      # 1. 创建名称为空的 Organization
      organization = Organization.new(
        name: ""
      )

      # 2. 检查 Organization 是否无效
      expect(organization).not_to be_valid
    end

    # Test 2: 有效名称可以成功创建组织
    it "creates an organization with a valid name" do
      # 1. 创建并保存一个有效的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 检查 Organization 是否已保存到数据库
      expect(organization).to be_persisted

      # 3. 检查组织名称是否正确
      expect(organization.name).to eq("CUHK Volunteer Team")
    end
  end

  describe "associations" do

    # Test 3: Organization 可以关联 Organizer 用户
    it "has associated organizer users" do
      # 1. 创建一个 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建一个属于该组织的 Organizer
      organizer = User.create!(
        email_address: "organizer@example.com",
        password: "password123",
        role: "organizer",
        organization: organization
      )

      # 3. 检查 Organization 是否包含该 Organizer
      expect(organization.users).to include(organizer)
    end
  end
end
