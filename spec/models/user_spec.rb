
require 'rails_helper'

RSpec.describe User, type: :model do
  describe "validations" do

    # Test 1: 用户必须提供邮箱地址
    it "requires an email address" do
      # 1. 创建邮箱为空、密码有效的 User
      user = User.new(
        email_address: "",
        password: "password123"
      )

      # 2. 检查 user.valid? 是否为 false
      expect(user).not_to be_valid
    end

    # Test 2: 拒绝重复的邮箱地址
    it "rejects duplicate email addresses" do
      # 1. 使用 User.create! 创建并保存第一个用户
      User.create!(
        email_address: "test@example.com",
        password: "password123"
      )

      # 2. 使用 User.new 创建第二个邮箱相同的用户
      second_user = User.new(
        email_address: "test@example.com",
        password: "password456"
      )

      # 3. 使用 expect 检查第二个用户是否无效
      expect(second_user).not_to be_valid
    end

    # Test 3: 邮箱不区分大小写，拒绝重复注册
    it "rejects duplicate emails regardless of case" do
      # 1. 创建第一个用户，邮箱为 test@example.com
      User.create!(
        email_address: "test@example.com",
        password: "password123"
      )

      # 2. 创建第二个用户，邮箱为 TEST@EXAMPLE.COM
      second_user = User.new(
        email_address: "TEST@EXAMPLE.COM",
        password: "password456"
      )

      # 3. 检查第二个用户是否无效
      expect(second_user).not_to be_valid
      expect(second_user.errors[:email_address]).to include("has already been taken")
    end

    # Test 4: 接受有效的邮箱和密码
    it "accepts a valid email and password" do
      # 1. 使用 User.new 创建有效用户
      user = User.new(
        email_address: "test@example.com",
        password: "password123"
      )

      # 2. 检查该用户是否通过验证
      expect(user).to be_valid
    end

    # Test 5: 拒绝无效的邮箱格式
    it "rejects an invalid email format" do
      # 1. 创建邮箱为 "abc"、密码有效的用户
      user = User.new(
        email_address: "abc",
        password: "password123"
      )

      # 2. 检查这个用户是否无效
      expect(user).not_to be_valid
    end

    # Test 6: 用户必须提供密码
    it "requires a password" do
      # 1. 创建邮箱有效、密码为空的用户
      user = User.new(
        email_address: "test@example.com",
        password: ""
      )

      # 2. 检查用户是否无效
      expect(user).not_to be_valid
    end

    # Test 7: 拒绝两次密码不一致
    it "rejects mismatched password confirmation" do
      # 1. 创建邮箱有效的用户
      # 2. password 设置为 "password123"
      # 3. password_confirmation 设置为 "password456"
      user = User.new(
        email_address: "test@example.com",
        password: "password123",
        password_confirmation: "password456"
      )

      # 4. 检查用户是否无效
      expect(user).not_to be_valid
    end

    # Test 8: 新用户默认拥有 Volunteer 角色
    it "assigns the volunteer role to new users by default" do
      # 1. 创建一个新用户
      user = User.create!(
        email_address: "volunteer@example.com",
        password: "password123"
      )

      # 2. 检查用户的默认角色
      expect(user.role).to eq("volunteer")
    end

    # Test 9: 用户可以拥有 Organizer 角色
    it "allows users to have the organizer role" do
      # 0. 创建 Organizer 所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 1. 创建一个 Organizer 用户
      user = User.create!(
        email_address: "organizer@example.com",
        password: "password123",
        role: "organizer",
        organization: organization
      )

      # 2. 检查用户的角色是否为 Organizer
      expect(user.role).to eq("organizer")
    end

    # Test 10: 拒绝无效的用户角色
    it "rejects invalid user roles" do
      # 1. 创建一个角色无效的用户
      user = User.new(
        email_address: "test@example.com",
        password: "password123",
        role: "admin123"
      )

      # 2. 检查用户是否无法通过验证
      expect(user).not_to be_valid

      # 3. 检查错误是否来自 role 字段
      expect(user.errors[:role]).to include("is not included in the list")
    end

    # Test 11: Organizer 必须属于一个 Organization
    it "requires an organization for organizer users" do
      # 1. 创建一个没有所属组织的 Organizer
      user = User.new(
        email_address: "organizer@example.com",
        password: "password123",
        role: "organizer"
      )

      # 2. 检查用户是否无法通过验证
      expect(user).not_to be_valid

      # 3. 检查错误是否来自 organization 字段
      expect(user.errors[:organization]).to include("can't be blank")
    end

    # Test 12: Volunteer 可以没有所属 Organization
    it "allows volunteer users without an organization" do
      # 1. 创建一个没有所属组织的 Volunteer
      user = User.create!(
        email_address: "volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )

      # 2. 检查用户是否成功保存到数据库
      expect(user).to be_persisted

      # 3. 检查用户是否没有所属 Organization
      expect(user.organization).to be_nil
    end
  end
end
