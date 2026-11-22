
require 'rails_helper'

RSpec.describe "Registrations", type: :request do
  describe "GET /registration/new" do
    # Test 1: 未登录用户可以访问注册页面
    it "allows unauthenticated users to access the registration page" do
      # 1. 向注册页面发送 GET 请求
      get new_registration_path

      # 2. 检查 HTTP 响应是否为 200 OK
      expect(response).to have_http_status(200)
    end

    # Test 2: 注册页面显示邮箱输入框
    it "displays an email input field" do
      # 1. 访问注册页面
      get new_registration_path

      # 2. 检查页面是否包含邮箱输入框
      expect(response.body).to include('name="user[email_address]"')
    end

    # Test 3: 注册页面显示密码输入框
    it "displays a password input field" do
      # 1. 访问注册页面
      get new_registration_path

      # 2. 检查页面是否包含密码输入框
      expect(response.body).to include('name="user[password]"')
    end

    # Test 4: 注册页面显示确认密码输入框
    it "displays a password confirmation input field" do
      # 1. 访问注册页面
      get new_registration_path

      # 2. 检查页面是否包含确认密码输入框
      expect(response.body).to include('name="user[password_confirmation]"')
    end

    # Test 5: 注册页面显示创建账号按钮
    it "displays a create account button" do
      # 1. 访问注册页面
      get new_registration_path

      # 2. 检查页面是否包含 Create Account 按钮
      expect(response.body).to include('type="submit"')
      expect(response.body).to include("Create Account")
    end
  end

  describe "POST /registration" do
    # Test 6: 有效注册信息可以成功创建用户
    it "creates a user with valid information" do
      # 1. 准备有效的注册数据
      user_params = {
        user: {
          email_address: "volunteer@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }

      # 2. 向 registration_path 发送 POST 请求
      # 3. 检查数据库中的 User 数量是否增加 1
      expect {
        post registration_path, params: user_params
      }.to change(User, :count).by(1)
    end

    # Test 7: 密码不一致时不能创建用户
    it "does not create a user when passwords do not match" do
      # 1. 准备密码不一致的注册数据
      user_params = {
        user: {
          email_address: "volunteer@example.com",
          password: "password123",
          password_confirmation: "different123"
        }
      }

      # 2. 发送 POST 请求
      # 3. 检查数据库中的 User 数量没有变化
      expect {
        post registration_path, params: user_params
      }.not_to change(User, :count)

      # 4. 检查服务器返回 422 Unprocessable Entity
      expect(response).to have_http_status(:unprocessable_content)
    end

    # Test 8: 密码不一致时显示错误信息
    it "displays an error message when passwords do not match" do
      # 1. 准备密码不一致的注册数据
      user_params = {
        user: {
          email_address: "volunteer@example.com",
          password: "password123",
          password_confirmation: "different123"
        }
      }

      # 2. 发送 POST 请求
      post registration_path, params: user_params

      # 3. 检查页面是否显示密码不一致的错误信息
      expect(CGI.unescapeHTML(response.body)).to include(
        "Password confirmation doesn't match Password"
      )
    end

    # Test 9: 重复邮箱不能创建用户
    it "does not create a user with a duplicate email address" do
      # 1. 先创建一个已经注册的用户
      User.create!(
        email_address: "volunteer@example.com",
        password: "password123"
      )

      # 2. 准备使用相同邮箱的注册数据
      user_params = {
        user: {
          email_address: "volunteer@example.com",
          password: "anotherpassword123",
          password_confirmation: "anotherpassword123"
        }
      }

      # 3. 发送 POST 请求，并检查 User 数量没有增加
      expect {
        post registration_path, params: user_params
      }.not_to change(User, :count)

      # 4. 检查服务器返回 HTTP 422
      expect(response).to have_http_status(:unprocessable_content)
    end

    # Test 10: 重复邮箱时显示错误信息
    it "displays an error message for a duplicate email address" do
      # 1. 创建一个已经注册的用户
      User.create!(
        email_address: "volunteer@example.com",
        password: "password123"
      )

      # 2. 准备使用相同邮箱的注册数据
      user_params = {
        user: {
          email_address: "volunteer@example.com",
          password: "anotherpassword123",
          password_confirmation: "anotherpassword123"
        }
      }

      # 3. 发送 POST 请求
      post registration_path, params: user_params

      # 4. 检查页面是否显示邮箱重复的错误信息
      expect(response.body).to include(
        "Email address has already been taken"
      )
    end

    # Test 11: 注册成功后跳转到登录页面
    it "redirects to the login page after successful registration" do
      # 1. 准备有效的注册数据
      user_params = {
        user: {
          email_address: "volunteer@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }

      # 2. 发送 POST 请求
      post registration_path, params: user_params

      # 3. 检查注册成功后是否跳转到登录页面
      expect(response).to redirect_to(new_session_path)
    end

    # Test 12: 注册成功后显示成功提示信息
    it "displays a success message after registration" do
      # 1. 准备有效的注册数据
      user_params = {
        user: {
          email_address: "volunteer@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }

      # 2. 发送 POST 请求
      post registration_path, params: user_params

      # 3. 模拟浏览器跳转到登录页面
      follow_redirect!

      # 4. 检查登录页面是否显示注册成功提示
      expect(response.body).to include(
        "Account created successfully."
      )
    end

    # Test 13: 新注册的用户可以使用邮箱和密码登录
    it "allows a newly registered user to log in" do
      # 1. 准备有效的注册数据
      user_params = {
        user: {
          email_address: "volunteer@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }

      # 2. 注册新用户
      post registration_path, params: user_params

      # 3. 使用新注册的账号登录
      # 4. 检查数据库中的登录 Session 数量增加 1
      expect {
        post session_path, params: {
          email_address: "volunteer@example.com",
          password: "password123"
        }
      }.to change(Session, :count).by(1)
    end

    # Test 14: 用户不能通过注册请求自行获得 Organizer 角色
    it "prevents users from assigning themselves the organizer role" do
      # 1. 准备包含 Organizer 角色的注册数据
      user_params = {
        user: {
          email_address: "volunteer@example.com",
          password: "password123",
          password_confirmation: "password123",
          role: "organizer"
        }
      }

      # 2. 发送 POST 请求，并确认用户成功创建
      expect {
        post registration_path, params: user_params
      }.to change(User, :count).by(1)

      # 3. 从数据库读取新注册的用户
      user = User.find_by!(email_address: "volunteer@example.com")

      # 4. 检查用户角色仍然是 Volunteer
      expect(user.role).to eq("volunteer")
    end
  end
end
