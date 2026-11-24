require "rails_helper"

RSpec.describe "Shift deletion", type: :request do
  # ==================================================
  # 公共测试数据
  # ==================================================

  # 创建 Organization A
  let(:organization_a) do
    Organization.create!(
      name: "CUHK Volunteer Team"
    )
  end

  # 创建 Organization B
  let(:organization_b) do
    Organization.create!(
      name: "CUHK Community Service"
    )
  end

  # 创建 Organization A 的 Organizer
  let(:organizer_a) do
    User.create!(
      email_address: "organizer_a@example.com",
      password: "password123",
      role: "organizer",
      organization: organization_a
    )
  end

  # 创建 Volunteer
  let(:volunteer) do
    User.create!(
      email_address: "volunteer@example.com",
      password: "password123",
      role: "volunteer"
    )
  end

  # 创建 Organization A 的活动
  let(:activity_a) do
    Activity.create!(
      title: "Campus Cleaning",
      description: "Campus cleaning volunteer activity",
      location: "CUHK Campus",
      organization: organization_a
    )
  end

  # 创建 Organization B 的活动
  let(:activity_b) do
    Activity.create!(
      title: "Community Service",
      description: "Community volunteer activity",
      location: "Sha Tin",
      organization: organization_b
    )
  end

  # 创建 Organization A 的另一个活动
  let(:other_activity) do
    Activity.create!(
      title: "Tree Planting",
      description: "Plant trees around campus",
      location: "CUHK Campus",
      organization: organization_a
    )
  end

  # 设置班次开始时间
  let(:start_time) do
    Time.current.change(usec: 0) + 1.day
  end

  # 创建 Organization A 的班次
  let!(:shift_a) do
    Shift.create!(
      activity: activity_a,
      start_time: start_time,
      end_time: start_time + 3.hours,
      capacity: 10
    )
  end

  # 创建 Organization B 的班次
  let!(:shift_b) do
    Shift.create!(
      activity: activity_b,
      start_time: start_time,
      end_time: start_time + 2.hours,
      capacity: 20
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

  # ==================================================
  # 未登录用户权限测试
  # ==================================================

  describe "unauthenticated access" do
    # Test 1: 未登录用户不能删除班次
    it "prevents unauthenticated users from deleting shifts" do
      expect {
        delete activity_shift_path(activity_a, shift_a)
      }.not_to change(Shift, :count)

      expect(response).to redirect_to(
        new_session_path
      )

      expect(Shift.exists?(shift_a.id)).to be true
    end
  end

  # ==================================================
  # Volunteer 权限测试
  # ==================================================

  describe "volunteer access" do
    before do
      sign_in_as(volunteer)
    end

    # Test 2: Volunteer 不能删除班次
    it "prevents volunteers from deleting shifts" do
      expect {
        delete activity_shift_path(activity_a, shift_a)
      }.not_to change(Shift, :count)

      expect(response).to have_http_status(
        :forbidden
      )

      expect(Shift.exists?(shift_a.id)).to be true
    end
  end

  # ==================================================
  # Organizer 班次删除测试
  # ==================================================

  describe "organizer access" do
    before do
      sign_in_as(organizer_a)
    end

    # Test 3: Organizer 可以删除自己组织的空班次
    it "allows organizers to delete empty shifts in their own organization" do
      # 1. 提交删除请求
      expect {
        delete activity_shift_path(activity_a, shift_a)
      }.to change(Shift, :count).by(-1)

      # 2. 检查 HTTP 响应及跳转
      expect(response).to have_http_status(
        :see_other
      )

      expect(response).to redirect_to(
        activity_shifts_path(activity_a)
      )

      # 3. 检查成功提示
      expect(flash[:notice]).to eq(
        "Shift deleted successfully."
      )

      # 4. 检查数据库记录
      expect(Shift.exists?(shift_a.id)).to be false

      # 5. 其他组织的班次不受影响
      expect(Shift.exists?(shift_b.id)).to be true

      # 6. 所属活动不受影响
      expect(Activity.exists?(activity_a.id)).to be true
    end

    # Test 4: 禁止删除存在已确认报名的班次
    it "rejects deletion of shifts with confirmed signups" do
      # 1. 创建已确认报名记录
      signup = Signup.create!(
        user: volunteer,
        shift: shift_a,
        status: "confirmed",
        attendance_status: "present"
      )

      original_signup_attributes = signup.attributes

      # 2. 尝试删除班次
      expect {
        delete activity_shift_path(activity_a, shift_a)
      }.not_to change(Shift, :count)

      # 3. 检查 HTTP 响应及跳转
      expect(response).to have_http_status(
        :see_other
      )

      expect(response).to redirect_to(
        activity_shift_path(activity_a, shift_a)
      )

      # 4. 检查错误提示
      expect(flash[:alert]).to include(
        "cannot delete a shift with existing signup records"
      )

      # 5. 检查班次及报名记录仍然存在
      expect(Shift.exists?(shift_a.id)).to be true

      # 6. 报名及出勤数据保持不变
      expect(signup.reload.attributes).to eq(
        original_signup_attributes
      )
    end

    # Test 5: 禁止删除存在候补报名的班次
    it "rejects deletion of shifts with waitlisted signups" do
      signup = Signup.create!(
        user: volunteer,
        shift: shift_a,
        status: "waitlisted",
        attendance_status: "pending"
      )

      original_signup_attributes = signup.attributes

      expect {
        delete activity_shift_path(activity_a, shift_a)
      }.not_to change(Shift, :count)

      expect(response).to have_http_status(
        :see_other
      )

      expect(response).to redirect_to(
        activity_shift_path(activity_a, shift_a)
      )

      expect(flash[:alert]).to include(
        "cannot delete a shift with existing signup records"
      )

      expect(Shift.exists?(shift_a.id)).to be true

      expect(signup.reload.attributes).to eq(
        original_signup_attributes
      )
    end

    # Test 6: 禁止删除存在已取消报名记录的班次
    it "rejects deletion of shifts with cancelled signup records" do
      signup = Signup.create!(
        user: volunteer,
        shift: shift_a,
        status: "cancelled",
        attendance_status: "pending"
      )

      original_signup_attributes = signup.attributes

      expect {
        delete activity_shift_path(activity_a, shift_a)
      }.not_to change(Shift, :count)

      expect(response).to have_http_status(
        :see_other
      )

      expect(response).to redirect_to(
        activity_shift_path(activity_a, shift_a)
      )

      expect(flash[:alert]).to include(
        "cannot delete a shift with existing signup records"
      )

      expect(Shift.exists?(shift_a.id)).to be true

      expect(signup.reload.attributes).to eq(
        original_signup_attributes
      )
    end

    # Test 7: Organizer 不能删除其他组织的班次
    it "prevents organizers from deleting shifts belonging to another organization" do
      original_attributes = shift_b.attributes

      expect {
        delete activity_shift_path(activity_b, shift_b)
      }.not_to change(Shift, :count)

      expect(response).to have_http_status(
        :not_found
      )

      expect(shift_b.reload.attributes).to eq(
        original_attributes
      )
    end

    # Test 8: 禁止通过错误的 Activity ID 删除班次
    it "rejects shift deletion through an incorrect parent activity" do
      original_attributes = shift_a.attributes

      expect {
        delete activity_shift_path(other_activity, shift_a)
      }.not_to change(Shift, :count)

      expect(response).to have_http_status(
        :not_found
      )

      expect(shift_a.reload.attributes).to eq(
        original_attributes
      )
    end

    # Test 9: 删除不存在的班次时返回 404
    it "returns not found when deleting a nonexistent shift" do
      nonexistent_shift_id = Shift.maximum(:id) + 1

      expect {
        delete activity_shift_path(
          activity_a,
          nonexistent_shift_id
        )
      }.not_to change(Shift, :count)

      expect(response).to have_http_status(
        :not_found
      )
    end
  end
end
