
require "rails_helper"

RSpec.describe "Development Account Switch Routing", type: :routing do
  # ==================================================
  # 测试环境中的开发专用路由隔离
  # ==================================================

  # Test 1: 测试环境不能访问账号切换路由
  it "does not expose the account switch route in the test environment" do
    expect(Rails.env).to be_test

    expect(
      post: "/dev/switch_account"
    ).not_to be_routable
  end

  # Test 2: 测试环境不应注册开发专用的命名路由
  it "does not register the development account switch path helper" do
    expect(
      Rails.application.routes.named_routes.names
    ).not_to include(:dev_switch_account)
  end
end
