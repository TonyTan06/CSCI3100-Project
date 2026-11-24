require "rails_helper"

RSpec.describe "Demo Accounts", type: :request do
  before do
    get new_session_path
  end

  let(:page) { Nokogiri::HTML(response.body) }

  # 验证登录页面可以正常访问
  it "renders the login page successfully" do
    expect(response).to have_http_status(:ok)
  end

  # 验证页面包含四个演示账号按钮
  it "displays four demo account buttons" do
    buttons = page.css(".demo-account-btn")

    expect(buttons.size).to eq(4)
  end

  # 验证四个按钮对应正确的演示账号
  it "provides the correct demo account email addresses" do
    emails = page.css(".demo-account-btn").map do |button|
      button["data-email"]
    end

    expect(emails).to match_array([
      "volunteer1@example.com",
      "volunteer2@example.com",
      "organizer1@example.com",
      "organizer2@example.com"
    ])
  end

  # 验证演示账号使用正确的预设密码
  it "provides the correct demo account password" do
    page.css(".demo-account-btn").each do |button|
      expect(button["data-password"]).to eq("password123")
    end
  end

  # 验证按钮不会直接提交登录表单
  it "uses non-submit buttons for demo accounts" do
    page.css(".demo-account-btn").each do |button|
      expect(button["type"]).to eq("button")
    end
  end

  # 验证 Stimulus Controller 绑定
  it "connects the demo account controller" do
    expect(
      page.at_css('[data-controller="demo-account"]')
    ).to be_present
  end

  # 验证邮箱及密码输入框的 Stimulus Target
  it "connects the email and password targets" do
    expect(
      page.at_css('[data-demo-account-target="email"]')
    ).to be_present

    expect(
      page.at_css('[data-demo-account-target="password"]')
    ).to be_present
  end

  # 验证按钮绑定正确的 Stimulus Action
  it "connects each button to the fill action" do
    page.css(".demo-account-btn").each do |button|
      expect(button["data-action"]).to eq("click->demo-account#fill")
    end
  end

  # 验证页面包含课程演示免责声明
  it "displays the course demonstration disclaimer" do
    expect(page.at_css(".demo-account-note").text).to include(
      "Course demonstration only. Not an official CUHK service."
    )
  end
end
