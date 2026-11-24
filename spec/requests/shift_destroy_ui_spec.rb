require "rails_helper"
require "nokogiri"

RSpec.describe "Shift deletion UI", type: :request do
  # ==================================================
  # 公共测试数据
  # ==================================================

  let(:organization) do
    Organization.create!(
      name: "CUHK Volunteer Team"
    )
  end

  let(:organizer) do
    User.create!(
      email_address: "organizer@example.com",
      password: "password123",
      role: "organizer",
      organization: organization
    )
  end

  let(:volunteer) do
    User.create!(
      email_address: "volunteer@example.com",
      password: "password123",
      role: "volunteer"
    )
  end

  let(:activity) do
    Activity.create!(
      title: "Campus Cleaning",
      description: "Campus cleaning volunteer activity",
      location: "CUHK Campus",
      organization: organization
    )
  end

  let(:start_time) { 1.day.from_now.change(usec: 0) }

  let!(:shift) do
    Shift.create!(
      activity: activity,
      start_time: start_time,
      end_time: start_time + 3.hours,
      capacity: 10
    )
  end

  # ==================================================
  # 辅助方法
  # ==================================================

  # 通过真实 HTTP 请求登录用户
  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password123"
    }

    expect(response).to have_http_status(:redirect)
  end

  # 查找 Shift 删除按钮
  def delete_button(document)
    document.css("button").find do |button|
      button.text.strip == "Delete Shift"
    end
  end

  # ==================================================
  # Organizer 删除按钮测试
  # ==================================================

  describe "organizer access" do
    before do
      sign_in_as(organizer)
    end

    # Test 1: 空班次显示可用的删除按钮
    it "displays an enabled delete button for an empty shift" do
      get activity_shift_path(activity, shift)

      expect(response).to have_http_status(:ok)

      document = Nokogiri::HTML(response.body)
      button = delete_button(document)

      expect(button).not_to be_nil
      expect(button["disabled"]).to be_nil
    end

    # Test 2: 删除表单使用正确的 DELETE 请求
    it "submits the deletion form to the correct shift endpoint" do
      get activity_shift_path(activity, shift)

      document = Nokogiri::HTML(response.body)
      button = delete_button(document)

      expect(button).not_to be_nil

      form = button.ancestors("form").first

      expect(form).not_to be_nil
      expect(form["action"]).to eq(
        activity_shift_path(activity, shift)
      )

      expect(form["method"]).to eq("post")

      method_input = form.at_css('input[name="_method"]')

      expect(method_input).not_to be_nil
      expect(method_input["value"]).to eq("delete")
    end

    # Test 3: 删除操作包含确认提示
    it "requires confirmation before deleting a shift" do
      get activity_shift_path(activity, shift)

      document = Nokogiri::HTML(response.body)
      button = delete_button(document)

      expect(button).not_to be_nil

      form = button.ancestors("form").first

      expect(form).not_to be_nil

      expect(form["data-turbo-confirm"]).to eq(
        "Are you sure you want to delete this shift? This action cannot be undone."
      )
    end

    # Test 4: 存在正式报名时禁用删除按钮
    it "disables the delete button when confirmed signups exist" do
      Signup.create!(
        user: volunteer,
        shift: shift,
        status: "confirmed",
        attendance_status: "pending"
      )

      get activity_shift_path(activity, shift)

      document = Nokogiri::HTML(response.body)
      button = delete_button(document)

      expect(button).not_to be_nil
      expect(button["disabled"]).not_to be_nil

      expect(button.ancestors("form")).to be_empty
    end

    # Test 5: 存在历史报名时显示无法删除的原因
    it "explains why shifts with historical signup records cannot be deleted" do
      Signup.create!(
        user: volunteer,
        shift: shift,
        status: "cancelled",
        attendance_status: "pending"
      )

      get activity_shift_path(activity, shift)

      document = Nokogiri::HTML(response.body)
      button = delete_button(document)

      expect(button).not_to be_nil
      expect(button["disabled"]).not_to be_nil

      reason = document.at_css("#shift-delete-reason")

      expect(reason).not_to be_nil

      expect(reason.text).to include(
        "This shift cannot be deleted because it has existing signup records."
      )

      expect(reason.text).to include(
        "This restriction protects volunteer signup and attendance history."
      )
    end
  end

  # ==================================================
  # Volunteer 删除按钮权限测试
  # ==================================================

  describe "volunteer access" do
    before do
      sign_in_as(volunteer)
    end

    # Test 6: Volunteer 不应看到删除班次按钮
    it "does not display the delete shift button to volunteers" do
      get activity_shift_path(activity, shift)

      expect(response).to have_http_status(:ok)

      document = Nokogiri::HTML(response.body)

      expect(delete_button(document)).to be_nil
      expect(document.at_css("#shift-management")).to be_nil
    end
  end
end
