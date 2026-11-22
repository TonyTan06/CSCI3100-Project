
require "rails_helper"

RSpec.describe "Activity Search", type: :request do
  # ==================================================
  # 测试数据
  # ==================================================

  let!(:organization_a) do
    Organization.create!(
      name: "CUHK Volunteer Team"
    )
  end

  let!(:organization_b) do
    Organization.create!(
      name: "CUHK Community Service"
    )
  end

  let!(:volunteer) do
    User.create!(
      email_address: "search_volunteer@example.com",
      password: "password123",
      role: "volunteer"
    )
  end

  let!(:organizer) do
    User.create!(
      email_address: "search_organizer@example.com",
      password: "password123",
      role: "organizer",
      organization: organization_a
    )
  end

  let!(:campus_activity) do
    Activity.create!(
      title: "Campus Cleanup",
      description: "Clean the campus together",
      location: "University Mall",
      organization: organization_a
    )
  end

  let!(:library_activity) do
    Activity.create!(
      title: "Library Support",
      description: "Help with library services",
      location: "Sha Tin",
      organization: organization_a
    )
  end

  let!(:other_activity) do
    Activity.create!(
      title: "Campus Tutoring",
      description: "Support students",
      location: "Community Center",
      organization: organization_b
    )
  end

  # ==================================================
  # 辅助方法
  # ==================================================

  # 使用真实 HTTP 请求登录用户
  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password123"
    }

    expect(response).to have_http_status(:redirect)
  end

  # 检查页面是否包含指定活动卡片
  def expect_activity_visible(activity)
    expect(response.body).to include(
      "id=\"activity-#{activity.id}\""
    )
  end

  # 检查页面是否没有显示指定活动卡片
  def expect_activity_hidden(activity)
    expect(response.body).not_to include(
      "id=\"activity-#{activity.id}\""
    )
  end

  # ==================================================
  # Volunteer 搜索测试
  # ==================================================

  describe "volunteer activity search" do
    before do
      sign_in_as(volunteer)
    end

    # Test 1: 根据活动标题搜索
    it "filters activities by title" do
      get activities_path, params: {
        q: "Cleanup"
      }

      expect(response).to have_http_status(:ok)
      expect_activity_visible(campus_activity)
      expect_activity_hidden(library_activity)
      expect_activity_hidden(other_activity)
    end

    # Test 2: 根据活动地点搜索
    it "filters activities by location" do
      get activities_path, params: {
        q: "Sha Tin"
      }

      expect(response).to have_http_status(:ok)
      expect_activity_visible(library_activity)
      expect_activity_hidden(campus_activity)
      expect_activity_hidden(other_activity)
    end

    # Test 3: 搜索时忽略英文大小写
    it "searches activities without case sensitivity" do
      get activities_path, params: {
        q: "cLeAnUp"
      }

      expect(response).to have_http_status(:ok)
      expect_activity_visible(campus_activity)
      expect_activity_hidden(library_activity)
    end

    # Test 4: 空关键词不影响原有活动列表
    it "displays all accessible activities when the query is blank" do
      get activities_path, params: {
        q: ""
      }

      expect(response).to have_http_status(:ok)
      expect_activity_visible(campus_activity)
      expect_activity_visible(library_activity)
      expect_activity_visible(other_activity)
    end
  end

  # ==================================================
  # Organizer 搜索权限测试
  # ==================================================

  describe "organizer activity search" do
    before do
      sign_in_as(organizer)
    end

    # Test 5: 搜索不能绕过组织访问限制
    it "only searches activities belonging to the organizer's organization" do
      get activities_path, params: {
        q: "Campus"
      }

      expect(response).to have_http_status(:ok)
      expect_activity_visible(campus_activity)
      expect_activity_hidden(library_activity)
      expect_activity_hidden(other_activity)
    end
  end
end
