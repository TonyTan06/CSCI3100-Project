
require 'rails_helper'
require 'nokogiri'

RSpec.describe "Signups", type: :request do
  # ==================================================
  # 公共测试数据
  # ==================================================

  let(:organization_a) do
    Organization.create!(
      name: "CUHK Volunteer Team"
    )
  end

  let(:organization_b) do
    Organization.create!(
      name: "CUHK Community Service"
    )
  end

  let(:organizer_a) do
    User.create!(
      email_address: "organizer_a@example.com",
      password: "password123",
      role: "organizer",
      organization: organization_a
    )
  end

  let(:volunteer_a) do
    User.create!(
      email_address: "volunteer_a@example.com",
      password: "password123",
      role: "volunteer"
    )
  end

  let(:volunteer_b) do
    User.create!(
      email_address: "volunteer_b@example.com",
      password: "password123",
      role: "volunteer"
    )
  end

  let(:activity_a) do
    Activity.create!(
      title: "Campus Cleaning",
      description: "Campus cleaning volunteer activity",
      location: "CUHK Campus",
      organization: organization_a
    )
  end

  let(:activity_b) do
    Activity.create!(
      title: "Community Service",
      description: "Community volunteer activity",
      location: "Sha Tin",
      organization: organization_b
    )
  end

  let(:start_time) do
    Time.current.change(usec: 0) + 1.day
  end

  # Activity A 的班次，容量为 1
  let!(:shift_a) do
    Shift.create!(
      activity: activity_a,
      start_time: start_time,
      end_time: start_time + 3.hours,
      capacity: 1
    )
  end

  # Activity B 的班次，与 Shift A 存在时间重叠
  let!(:shift_b) do
    Shift.create!(
      activity: activity_b,
      start_time: start_time + 1.hour,
      end_time: start_time + 4.hours,
      capacity: 5
    )
  end

  # ==================================================
  # 辅助方法
  # ==================================================

  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password123"
    }
    expect(response).to have_http_status(:redirect)
  end

  # ==================================================
  # 班次报名测试
  # ==================================================

  describe "signup creation" do
    # ==================================================
    # 未登录用户权限测试
    # ==================================================

    context "unauthenticated access" do
      # Test 1: 未登录用户不能报名
      it "prevents unauthenticated users from signing up" do
        expect {
          post "/activities/#{activity_a.id}/shifts/#{shift_a.id}/signups"
        }.not_to change(Signup, :count)

        expect(response).to redirect_to(
          new_session_path
        )
      end
    end

    # ==================================================
    # Organizer 权限测试
    # ==================================================

    context "organizer access" do
      before do
        sign_in_as(organizer_a)
      end

      # Test 2: Organizer 不能报名
      it "prevents organizers from signing up for shifts" do
        expect {
          post "/activities/#{activity_a.id}/shifts/#{shift_a.id}/signups"
        }.not_to change(Signup, :count)

        expect(response).to have_http_status(
          :forbidden
        )
      end
    end

    # ==================================================
    # Volunteer 报名测试
    # ==================================================

    context "volunteer access" do
      before do
        sign_in_as(volunteer_a)
      end

      # Test 3: 有剩余名额时自动正式报名
      it "creates a confirmed signup when capacity is available" do
        # 1. 检查班次初始状态
        expect(shift_a.available_slots).to eq(1)
        expect(shift_a.confirmed_count).to eq(0)

        # 2. 提交报名请求
        expect {
          post "/activities/#{activity_a.id}/shifts/#{shift_a.id}/signups"
        }.to change(Signup, :count).by(1)

        # 3. 查询新报名记录
        signup = Signup.find_by!(
          user: volunteer_a,
          shift: shift_a
        )

        # 4. 检查报名属性
        expect(signup.user).to eq(volunteer_a)
        expect(signup.shift).to eq(shift_a)
        expect(signup.status).to eq("confirmed")
        expect(signup.attendance_status).to eq("pending")
        expect(signup.waitlisted_at).to be_nil

        # 5. 检查班次统计
        expect(shift_a.reload.confirmed_count).to eq(1)
        expect(shift_a.available_slots).to eq(0)
        expect(shift_a.full?).to be true

        # 6. 报名成功后跳转至班次详情
        expect(response).to redirect_to(
          activity_shift_path(activity_a, shift_a)
        )

        expect(response).to have_http_status(:see_other)
      end

      # Test 4: 班次满员时自动进入候补队列
      it "creates a waitlisted signup when the shift is full" do
        # 1. Volunteer B 占用唯一正式名额
        existing_signup = Signup.create!(
          user: volunteer_b,
          shift: shift_a,
          status: "confirmed"
        )

        expect(shift_a.full?).to be true

        # 2. Volunteer A 提交报名请求
        expect {
          post "/activities/#{activity_a.id}/shifts/#{shift_a.id}/signups"
        }.to change(Signup, :count).by(1)

        # 3. 查询新报名记录
        signup = Signup.find_by!(
          user: volunteer_a,
          shift: shift_a
        )

        # 4. 检查候补报名属性
        expect(signup.status).to eq("waitlisted")
        expect(signup.attendance_status).to eq("pending")
        expect(signup.waitlisted_at).not_to be_nil

        # 5. 原有正式报名不受影响
        expect(existing_signup.reload.status).to eq("confirmed")

        # 6. 检查班次统计及候补队列
        expect(shift_a.confirmed_count).to eq(1)
        expect(shift_a.available_slots).to eq(0)
        expect(shift_a.waitlist_queue.to_a).to eq([ signup ])

        # 7. 报名成功后跳转至班次详情
        expect(response).to redirect_to(
          activity_shift_path(activity_a, shift_a)
        )

        expect(response).to have_http_status(:see_other)
      end

      # Test 5: Volunteer 可以报名其他组织的活动
      it "allows volunteers to sign up for shifts across organizations" do
        # 1. 报名 Organization B 的班次
        expect {
          post "/activities/#{activity_b.id}/shifts/#{shift_b.id}/signups"
        }.to change(Signup, :count).by(1)

        # 2. 查询报名记录
        signup = Signup.find_by!(
          user: volunteer_a,
          shift: shift_b
        )

        # 3. 检查报名结果
        expect(signup.status).to eq("confirmed")

        expect(signup.shift.activity.organization).to eq(
          organization_b
        )

        # 4. Organization A 的班次不受影响
        expect(shift_a.signups).to be_empty

        # 5. 跳转至正确的班次详情
        expect(response).to redirect_to(
          activity_shift_path(activity_b, shift_b)
        )
      end

      # Test 6: 禁止重复正式报名
      it "rejects duplicate confirmed signups" do
        # 1. 创建已有正式报名
        existing_signup = Signup.create!(
          user: volunteer_a,
          shift: shift_a,
          status: "confirmed"
        )

        original_attributes = existing_signup.attributes

        # 2. 尝试重复报名
        expect {
          post "/activities/#{activity_a.id}/shifts/#{shift_a.id}/signups"
        }.not_to change(Signup, :count)

        # 3. 检查 HTTP 响应
        expect(response).to have_http_status(422)

        # 4. 原有报名记录必须保持不变
        expect(existing_signup.reload.attributes).to eq(
          original_attributes
        )

        expect(shift_a.confirmed_count).to eq(1)
        expect(shift_a.waitlist_queue).to be_empty
      end

      # Test 7: 禁止重复候补报名
      it "rejects duplicate waitlisted signups" do
        # 1. Volunteer B 占用正式名额
        Signup.create!(
          user: volunteer_b,
          shift: shift_a,
          status: "confirmed"
        )

        # 2. Volunteer A 已经进入候补队列
        existing_signup = Signup.create!(
          user: volunteer_a,
          shift: shift_a,
          status: "waitlisted"
        )

        original_attributes = existing_signup.attributes

        # 3. 尝试再次报名
        expect {
          post "/activities/#{activity_a.id}/shifts/#{shift_a.id}/signups"
        }.not_to change(Signup, :count)

        # 4. 检查 HTTP 响应
        expect(response).to have_http_status(422)

        # 5. 原有候补状态及排队时间保持不变
        expect(existing_signup.reload.attributes).to eq(
          original_attributes
        )

        expect(shift_a.waitlist_queue.to_a).to eq(
          [ existing_signup ]
        )
      end

      # Test 8: 拒绝存在时间冲突的正式报名
      it "rejects signups that conflict with another confirmed signup" do
        # 1. Volunteer A 已报名 Shift B
        existing_signup = Signup.create!(
          user: volunteer_a,
          shift: shift_b,
          status: "confirmed"
        )

        original_attributes = existing_signup.attributes

        # 2. 尝试报名时间重叠的 Shift A
        expect {
          post "/activities/#{activity_a.id}/shifts/#{shift_a.id}/signups"
        }.not_to change(Signup, :count)

        # 3. 检查 HTTP 响应
        expect(response).to have_http_status(422)

        # 4. 检查时间冲突错误信息
        page_text = Nokogiri::HTML(response.body).text

        expect(page_text).to include(
          "Shift overlaps with another confirmed signup"
        )

        # 5. 原有报名记录不受影响
        expect(existing_signup.reload.attributes).to eq(
          original_attributes
        )

        expect(shift_a.signups).to be_empty
        expect(shift_a.available_slots).to eq(1)
      end

      # Test 9: 允许取消后重新报名
      it "allows volunteers to sign up again after cancellation" do
        # 1. 创建已经取消的报名记录
        existing_signup = Signup.create!(
          user: volunteer_a,
          shift: shift_a,
          status: "cancelled",
          attendance_status: "absent"
        )

        original_id = existing_signup.id

        # 2. 重新提交报名请求
        expect {
          post "/activities/#{activity_a.id}/shifts/#{shift_a.id}/signups"
        }.not_to change(Signup, :count)

        # 3. 重新读取原有报名记录
        existing_signup.reload

        # 4. 必须复用原有报名记录
        expect(existing_signup.id).to eq(original_id)
        expect(existing_signup.user).to eq(volunteer_a)
        expect(existing_signup.shift).to eq(shift_a)

        # 5. 检查报名状态及出勤状态
        expect(existing_signup.status).to eq("confirmed")
        expect(existing_signup.attendance_status).to eq("pending")
        expect(existing_signup.waitlisted_at).to be_nil

        # 6. 检查班次统计
        expect(shift_a.confirmed_count).to eq(1)
        expect(shift_a.available_slots).to eq(0)

        # 7. 跳转至班次详情
        expect(response).to redirect_to(
          activity_shift_path(activity_a, shift_a)
        )
      end

      # Test 10: 禁止通过 HTTP 参数修改受保护属性
      it "ignores protected attributes during signup creation" do
        # 1. 创建其他用户的报名记录
        existing_signup = Signup.create!(
          user: volunteer_b,
          shift: shift_b,
          status: "confirmed"
        )

        original_attributes = existing_signup.attributes

        # 2. 构造包含非法属性的参数
        malicious_attributes = {
          id: existing_signup.id,
          user_id: volunteer_b.id,
          shift_id: shift_b.id,
          status: "cancelled",
          attendance_status: "present",
          waitlisted_at: 1.day.ago.iso8601
        }

        # 3. 提交包含非法属性的报名请求
        expect {
          post "/activities/#{activity_a.id}/shifts/#{shift_a.id}/signups", params: {
            signup: malicious_attributes
          }
        }.to change(Signup, :count).by(1)

        # 4. 查询新报名记录
        signup = Signup.find_by!(
          user: volunteer_a,
          shift: shift_a
        )

        # 5. 用户和班次必须由服务器确定
        expect(signup.id).not_to eq(existing_signup.id)
        expect(signup.user_id).to eq(volunteer_a.id)
        expect(signup.shift_id).to eq(shift_a.id)

        # 6. 报名状态及出勤状态必须由系统决定
        expect(signup.status).to eq("confirmed")
        expect(signup.attendance_status).to eq("pending")
        expect(signup.waitlisted_at).to be_nil

        # 7. 其他用户报名记录保持不变
        expect(existing_signup.reload.attributes).to eq(
          original_attributes
        )

        # 8. 跳转至正确的班次详情
        expect(response).to redirect_to(
          activity_shift_path(activity_a, shift_a)
        )
      end

      # Test 11: 禁止通过错误的 Activity ID 报名
      it "rejects signups through an incorrect parent activity" do
        # 使用 Activity A 的 ID 报名 Activity B 的班次
        expect {
          post "/activities/#{activity_a.id}/shifts/#{shift_b.id}/signups"
        }.not_to change(Signup, :count)

        expect(response).to have_http_status(
          :not_found
        )

        expect(shift_a.signups).to be_empty
        expect(shift_b.signups).to be_empty
      end

      # Test 12: 禁止报名不存在的班次
      it "returns not found when signing up for a nonexistent shift" do
        nonexistent_shift_id = Shift.maximum(:id) + 1

        expect {
          post "/activities/#{activity_a.id}/shifts/#{nonexistent_shift_id}/signups"
        }.not_to change(Signup, :count)

        expect(response).to have_http_status(
          :not_found
        )
      end
    end
  end

  # ==================================================
  # 取消报名测试
  # ==================================================

  describe "signup cancellation" do
    # 创建额外的 Volunteer，用于候补递补测试
    let(:volunteer_c) do
      User.create!(
        email_address: "volunteer_c@example.com",
        password: "password123",
        role: "volunteer"
      )
    end

    # ==================================================
    # 未登录用户权限测试
    # ==================================================

    context "unauthenticated access" do
      # Test 13: 未登录用户不能取消报名
      it "prevents unauthenticated users from cancelling signups" do
        # 1. 创建已有报名记录
        signup = Signup.create!(
          user: volunteer_a,
          shift: shift_a,
          status: "confirmed"
        )
        original_attributes = signup.attributes

        # 2. 尝试取消报名
        expect {
          delete "/activities/#{activity_a.id}/shifts/#{shift_a.id}/signups/#{signup.id}"
        }.not_to change(Signup, :count)

        # 3. 检查是否跳转至登录页面
        expect(response).to redirect_to(
          new_session_path
        )

        # 4. 原有报名记录保持不变
        expect(signup.reload.attributes).to eq(
          original_attributes
        )
      end
    end

    # ==================================================
    # Organizer 权限测试
    # ==================================================

    context "organizer access" do
      before do
        sign_in_as(organizer_a)
      end

      # Test 14: Organizer 不能取消报名
      it "prevents organizers from cancelling volunteer signups" do
        # 1. 创建已有报名记录
        signup = Signup.create!(
          user: volunteer_a,
          shift: shift_a,
          status: "confirmed"
        )
        original_attributes = signup.attributes

        # 2. 尝试取消 Volunteer 的报名
        expect {
          delete "/activities/#{activity_a.id}/shifts/#{shift_a.id}/signups/#{signup.id}"
        }.not_to change(Signup, :count)

        # 3. 检查权限拒绝响应
        expect(response).to have_http_status(
          :forbidden
        )

        # 4. 原有报名记录保持不变
        expect(signup.reload.attributes).to eq(
          original_attributes
        )
      end
    end

    # ==================================================
    # Volunteer 取消报名测试
    # ==================================================

    context "volunteer access" do
      before do
        sign_in_as(volunteer_a)
      end

      # Test 15: Volunteer 可以取消正式报名
      it "allows volunteers to cancel their own confirmed signups" do
        # 1. 创建正式报名
        signup = Signup.create!(
          user: volunteer_a,
          shift: shift_a,
          status: "confirmed"
        )
        original_id = signup.id

        # 2. 确认班次已经满员
        expect(shift_a.full?).to be true

        # 3. 提交取消报名请求
        expect {
          delete "/activities/#{activity_a.id}/shifts/#{shift_a.id}/signups/#{signup.id}"
        }.not_to change(Signup, :count)

        # 4. 检查报名记录及状态
        signup.reload
        expect(signup.id).to eq(original_id)
        expect(signup.user).to eq(volunteer_a)
        expect(signup.shift).to eq(shift_a)
        expect(signup.status).to eq("cancelled")
        expect(signup.waitlisted_at).to be_nil

        # 5. 检查班次名额已经释放
        expect(shift_a.confirmed_count).to eq(0)
        expect(shift_a.available_slots).to eq(1)
        expect(shift_a.full?).to be false

        # 6. 取消成功后跳转至班次详情
        expect(response).to redirect_to(
          activity_shift_path(activity_a, shift_a)
        )
        expect(response).to have_http_status(:see_other)
      end

      # Test 16: Volunteer 可以取消候补报名
      it "allows volunteers to cancel their own waitlisted signups" do
        # 1. Volunteer B 占用唯一正式名额
        confirmed_signup = Signup.create!(
          user: volunteer_b,
          shift: shift_a,
          status: "confirmed"
        )

        # 2. Volunteer A 和 C 进入候补队列
        signup_a = Signup.create!(
          user: volunteer_a,
          shift: shift_a,
          status: "waitlisted"
        )
        signup_c = Signup.create!(
          user: volunteer_c,
          shift: shift_a,
          status: "waitlisted"
        )

        original_confirmed_attributes =
          confirmed_signup.attributes
        original_waitlisted_attributes =
          signup_c.attributes

        # 3. Volunteer A 取消候补报名
        expect {
          delete "/activities/#{activity_a.id}/shifts/#{shift_a.id}/signups/#{signup_a.id}"
        }.not_to change(Signup, :count)

        # 4. 检查报名状态及候补时间
        expect(signup_a.reload.status).to eq("cancelled")
        expect(signup_a.waitlisted_at).to be_nil

        # 5. 其他报名记录保持不变
        expect(confirmed_signup.reload.attributes).to eq(
          original_confirmed_attributes
        )
        expect(signup_c.reload.attributes).to eq(
          original_waitlisted_attributes
        )

        # 6. 取消候补报名不会释放正式名额
        expect(shift_a.confirmed_count).to eq(1)
        expect(shift_a.available_slots).to eq(0)
        expect(shift_a.waitlist_queue.to_a).to eq(
          [ signup_c ]
        )

        # 7. 跳转至班次详情
        expect(response).to redirect_to(
          activity_shift_path(activity_a, shift_a)
        )
        expect(response).to have_http_status(:see_other)
      end

      # ==================================================
      # 自动候补递补测试
      # ==================================================

      # Test 17: 取消正式报名后按照 FIFO 自动递补
      it "promotes the earliest waitlisted volunteer after cancellation" do
        # 1. Volunteer A 正式报名
        signup_a = Signup.create!(
          user: volunteer_a,
          shift: shift_a,
          status: "confirmed"
        )

        # 2. 创建两条候补报名记录
        signup_c = Signup.create!(
          user: volunteer_c,
          shift: shift_a,
          status: "waitlisted"
        )
        signup_b = Signup.create!(
          user: volunteer_b,
          shift: shift_a,
          status: "waitlisted"
        )

        # 3. 明确设置候补顺序
        # Volunteer B 比 Volunteer C 更早进入候补队列
        queue_time = Time.current.change(usec: 0)
        signup_b.update!(waitlisted_at: queue_time - 2.minutes)
        signup_c.update!(waitlisted_at: queue_time - 1.minute)

        expect(shift_a.waitlist_queue.to_a).to eq(
          [ signup_b, signup_c ]
        )
        original_waitlisted_at = signup_c.waitlisted_at

        # 4. Volunteer A 取消正式报名
        expect {
          delete "/activities/#{activity_a.id}/shifts/#{shift_a.id}/signups/#{signup_a.id}"
        }.not_to change(Signup, :count)

        # 5. 检查取消及自动递补结果
        expect(signup_a.reload.status).to eq("cancelled")
        expect(signup_b.reload.status).to eq("confirmed")
        expect(signup_b.waitlisted_at).to be_nil
        expect(signup_b.attendance_status).to eq("pending")

        # 6. Volunteer C 继续保持候补状态
        expect(signup_c.reload.status).to eq("waitlisted")
        expect(signup_c.waitlisted_at).to eq(
          original_waitlisted_at
        )

        # 7. 检查班次容量及候补队列
        expect(shift_a.confirmed_count).to eq(1)
        expect(shift_a.available_slots).to eq(0)
        expect(shift_a.waitlist_queue.to_a).to eq(
          [ signup_c ]
        )

        # 8. 检查取消成功后的跳转
        expect(response).to redirect_to(
          activity_shift_path(activity_a, shift_a)
        )
        expect(response).to have_http_status(:see_other)
      end

      # Test 18: 跳过存在时间冲突的候补用户
      it "skips conflicting waitlisted volunteers during automatic promotion" do
        # 1. Volunteer A 正式报名 Shift A
        signup_a = Signup.create!(
          user: volunteer_a,
          shift: shift_a,
          status: "confirmed"
        )

        # 2. Volunteer B 已经正式报名时间重叠的 Shift B
        conflicting_signup = Signup.create!(
          user: volunteer_b,
          shift: shift_b,
          status: "confirmed"
        )

        # 3. Volunteer B 和 C 进入 Shift A 的候补队列
        signup_b = Signup.create!(
          user: volunteer_b,
          shift: shift_a,
          status: "waitlisted"
        )
        signup_c = Signup.create!(
          user: volunteer_c,
          shift: shift_a,
          status: "waitlisted"
        )

        # 4. 设置 Volunteer B 为第一位候补用户
        queue_time = Time.current.change(usec: 0)
        signup_b.update!(waitlisted_at: queue_time - 2.minutes)
        signup_c.update!(waitlisted_at: queue_time - 1.minute)

        expect(shift_a.waitlist_queue.to_a).to eq(
          [ signup_b, signup_c ]
        )

        original_waitlisted_at = signup_b.waitlisted_at
        original_conflicting_attributes =
          conflicting_signup.attributes

        # 5. Volunteer A 取消正式报名
        expect {
          delete "/activities/#{activity_a.id}/shifts/#{shift_a.id}/signups/#{signup_a.id}"
        }.not_to change(Signup, :count)

        # 6. 检查 Volunteer A 已取消报名
        expect(signup_a.reload.status).to eq("cancelled")

        # 7. Volunteer B 因时间冲突继续保持候补状态
        expect(signup_b.reload.status).to eq("waitlisted")
        expect(signup_b.waitlisted_at).to eq(
          original_waitlisted_at
        )

        # 8. Volunteer C 自动获得释放的名额
        expect(signup_c.reload.status).to eq("confirmed")
        expect(signup_c.waitlisted_at).to be_nil

        # 9. Volunteer B 在其他班次的报名不受影响
        expect(conflicting_signup.reload.attributes).to eq(
          original_conflicting_attributes
        )

        # 10. 检查班次统计及候补队列
        expect(shift_a.confirmed_count).to eq(1)
        expect(shift_a.available_slots).to eq(0)
        expect(shift_a.waitlist_queue.to_a).to eq(
          [ signup_b ]
        )

        # 11. 检查取消成功后的跳转
        expect(response).to redirect_to(
          activity_shift_path(activity_a, shift_a)
        )
        expect(response).to have_http_status(:see_other)
      end

      # ==================================================
      # 非法取消及资源安全测试
      # ==================================================

      # Test 19: 拒绝重复取消报名
      it "rejects cancellation of an already cancelled signup" do
        # 1. 创建已经取消的报名记录
        signup = Signup.create!(
          user: volunteer_a,
          shift: shift_a,
          status: "cancelled"
        )
        original_attributes = signup.attributes

        # 2. 尝试再次取消报名
        expect {
          delete "/activities/#{activity_a.id}/shifts/#{shift_a.id}/signups/#{signup.id}"
        }.not_to change(Signup, :count)

        # 3. 检查 HTTP 响应
        expect(response).to have_http_status(422)

        # 4. 检查错误信息
        page_text = Nokogiri::HTML(response.body).text
        expect(page_text).to include(
          "Status has already been cancelled"
        )

        # 5. 原有报名记录保持不变
        expect(signup.reload.attributes).to eq(
          original_attributes
        )
      end

      # Test 20: 禁止取消其他 Volunteer 的报名
      it "prevents volunteers from cancelling another volunteer's signup" do
        # 1. 创建 Volunteer B 的正式报名
        signup = Signup.create!(
          user: volunteer_b,
          shift: shift_a,
          status: "confirmed"
        )
        original_attributes = signup.attributes

        # 2. Volunteer A 尝试取消 Volunteer B 的报名
        expect {
          delete "/activities/#{activity_a.id}/shifts/#{shift_a.id}/signups/#{signup.id}"
        }.not_to change(Signup, :count)

        # 3. 检查权限拒绝响应
        expect(response).to have_http_status(
          :not_found
        )

        # 4. 其他用户的报名记录不能受到影响
        expect(signup.reload.attributes).to eq(
          original_attributes
        )
        expect(shift_a.confirmed_count).to eq(1)
      end

      # Test 21: 禁止通过错误的 Activity ID 取消报名
      it "rejects cancellation through an incorrect parent activity" do
        # 1. 创建属于 Activity B 的报名
        signup = Signup.create!(
          user: volunteer_a,
          shift: shift_b,
          status: "confirmed"
        )
        original_attributes = signup.attributes

        # 2. 使用 Activity A 的 ID 尝试取消报名
        expect {
          delete "/activities/#{activity_a.id}/shifts/#{shift_b.id}/signups/#{signup.id}"
        }.not_to change(Signup, :count)

        # 3. 检查资源归属错误响应
        expect(response).to have_http_status(
          :not_found
        )

        # 4. 原有报名记录保持不变
        expect(signup.reload.attributes).to eq(
          original_attributes
        )
      end

      # Test 22: 禁止通过错误的 Shift ID 取消报名
      it "rejects cancellation through an incorrect parent shift" do
        # 1. 在 Activity A 中创建另一个班次
        other_shift = Shift.create!(
          activity: activity_a,
          start_time: start_time + 5.hours,
          end_time: start_time + 7.hours,
          capacity: 5
        )

        # 2. Volunteer A 报名原有班次
        signup = Signup.create!(
          user: volunteer_a,
          shift: shift_a,
          status: "confirmed"
        )
        original_attributes = signup.attributes

        # 3. 使用同一活动下错误的 Shift ID
        expect {
          delete "/activities/#{activity_a.id}/shifts/#{other_shift.id}/signups/#{signup.id}"
        }.not_to change(Signup, :count)

        # 4. 检查资源归属错误响应
        expect(response).to have_http_status(
          :not_found
        )

        # 5. 原有报名记录保持不变
        expect(signup.reload.attributes).to eq(
          original_attributes
        )
      end

      # Test 23: 请求不存在的 Signup 时返回 404
      it "returns not found when cancelling a nonexistent signup" do
        nonexistent_signup_id = Signup.maximum(:id).to_i + 1

        expect {
          delete "/activities/#{activity_a.id}/shifts/#{shift_a.id}/signups/#{nonexistent_signup_id}"
        }.not_to change(Signup, :count)

        expect(response).to have_http_status(
          :not_found
        )
      end

      # Test 24: 禁止通过 HTTP 参数修改受保护属性
      it "ignores protected attributes during signup cancellation" do
        # 1. 创建 Volunteer A 自己的报名
        signup = Signup.create!(
          user: volunteer_a,
          shift: shift_a,
          status: "confirmed"
        )
        original_id = signup.id

        # 2. 创建其他 Volunteer 的报名
        other_signup = Signup.create!(
          user: volunteer_b,
          shift: shift_b,
          status: "confirmed"
        )
        original_other_attributes = other_signup.attributes

        # 3. 构造包含受保护属性的请求参数
        malicious_attributes = {
          id: other_signup.id,
          user_id: volunteer_b.id,
          shift_id: shift_b.id,
          status: "confirmed",
          attendance_status: "present",
          waitlisted_at: 1.day.ago.iso8601
        }

        # 4. 提交包含非法属性的取消请求
        expect {
          delete "/activities/#{activity_a.id}/shifts/#{shift_a.id}/signups/#{signup.id}", params: {
            signup: malicious_attributes
          }
        }.not_to change(Signup, :count)

        # 5. 检查原有报名身份及所属班次
        signup.reload
        expect(signup.id).to eq(original_id)
        expect(signup.user_id).to eq(volunteer_a.id)
        expect(signup.shift_id).to eq(shift_a.id)

        # 6. 状态只能由系统决定
        expect(signup.status).to eq("cancelled")
        expect(signup.attendance_status).to eq("pending")
        expect(signup.waitlisted_at).to be_nil

        # 7. 其他用户的报名记录保持不变
        expect(other_signup.reload.attributes).to eq(
          original_other_attributes
        )

        # 8. 跳转至正确的班次详情
        expect(response).to redirect_to(
          activity_shift_path(activity_a, shift_a)
        )
        expect(response).to have_http_status(:see_other)
      end
    end
  end

  # ==================================================
  # 报名状态及操作入口测试
  # ==================================================

  describe "signup display" do
    # 创建额外的 Volunteer，用于候补排位测试
    let(:volunteer_c) do
      User.create!(
        email_address: "volunteer_c@example.com",
        password: "password123",
        role: "volunteer"
      )
    end

    let(:volunteer_d) do
      User.create!(
        email_address: "volunteer_d@example.com",
        password: "password123",
        role: "volunteer"
      )
    end

    # 获取页面中的报名操作表单
    def signup_forms(document)
      signup_path = activity_shift_signups_path(
        activity_a,
        shift_a
      )

      document.css("form").select do |form|
        action = form["action"].to_s
        action == signup_path ||
          action.start_with?("#{signup_path}/")
      end
    end

    # 检查报名按钮、目标地址及请求方式
    def expect_signup_action(document, label, path, method: :post)
      forms = signup_forms(document)

      expect(forms.size).to eq(1)

      form = forms.first

      expect(form["action"]).to eq(path)
      expect(form["method"]).to eq("post")
      expect(form.at_css("button").text.strip).to eq(label)

      # DELETE 请求通过隐藏的 _method 字段实现
      if method == :delete
        method_input = form.at_css(
          'input[name="_method"]'
        )
        expect(method_input).not_to be_nil
        expect(method_input["value"]).to eq("delete")
      else
        expect(
          form.at_css('input[name="_method"]')
        ).to be_nil
      end
    end

    # ==================================================
    # Volunteer 报名状态显示测试
    # ==================================================

    context "volunteer access" do
      before do
        sign_in_as(volunteer_a)
      end

      # Test 25: 未报名且未满员时显示 Sign Up
      it "displays the signup button when capacity is available" do
        get activity_shift_path(activity_a, shift_a)

        expect(response).to have_http_status(:ok)

        document = Nokogiri::HTML(response.body)

        expect(document.text.squish).to include(
          "Signup Status: Not registered"
        )

        expect_signup_action(
          document,
          "Sign Up",
          activity_shift_signups_path(activity_a, shift_a)
        )

        # Volunteer 不应看到编辑入口
        expect(
          document.at_css(
            "a[href='#{edit_activity_shift_path(activity_a, shift_a)}']"
          )
        ).to be_nil
      end

      # Test 26: 未报名且满员时显示 Join Waitlist
      it "displays the join waitlist button when the shift is full" do
        Signup.create!(
          user: volunteer_b,
          shift: shift_a,
          status: "confirmed"
        )

        get activity_shift_path(activity_a, shift_a)

        expect(response).to have_http_status(:ok)

        document = Nokogiri::HTML(response.body)

        expect(document.text.squish).to include(
          "Signup Status: Not registered"
        )

        expect_signup_action(
          document,
          "Join Waitlist",
          activity_shift_signups_path(activity_a, shift_a)
        )
      end

      # Test 27: 正式报名后显示状态及取消按钮
      it "displays confirmed status and the cancellation button" do
        signup = Signup.create!(
          user: volunteer_a,
          shift: shift_a,
          status: "confirmed"
        )

        get activity_shift_path(activity_a, shift_a)

        expect(response).to have_http_status(:ok)

        document = Nokogiri::HTML(response.body)
        page_text = document.text.squish

        expect(page_text).to include(
          "Signup Status: Confirmed"
        )

        expect(page_text).not_to include(
          "Waitlist Position:"
        )

        expect_signup_action(
          document,
          "Cancel Signup",
          activity_shift_signup_path(activity_a, shift_a, signup),
          method: :delete
        )
      end

      # Test 28: 候补报名后显示正确的排位
      it "displays the current volunteer's waitlist position" do
        # 1. Volunteer B 占用唯一正式名额
        Signup.create!(
          user: volunteer_b,
          shift: shift_a,
          status: "confirmed"
        )

        # 2. 创建三条候补记录
        signup_a = Signup.create!(
          user: volunteer_a,
          shift: shift_a,
          status: "waitlisted"
        )
        signup_c = Signup.create!(
          user: volunteer_c,
          shift: shift_a,
          status: "waitlisted"
        )
        signup_d = Signup.create!(
          user: volunteer_d,
          shift: shift_a,
          status: "waitlisted"
        )

        # 3. 设置候补顺序为 C、A、D
        queue_time = Time.current.change(usec: 0)

        signup_c.update!(
          waitlisted_at: queue_time - 3.minutes
        )
        signup_a.update!(
          waitlisted_at: queue_time - 2.minutes
        )
        signup_d.update!(
          waitlisted_at: queue_time - 1.minute
        )

        expect(shift_a.waitlist_queue.to_a).to eq(
          [ signup_c, signup_a, signup_d ]
        )

        # 4. 请求班次详情页面
        get activity_shift_path(activity_a, shift_a)

        expect(response).to have_http_status(:ok)

        document = Nokogiri::HTML(response.body)
        page_text = document.text.squish

        # 5. 检查报名状态及候补排位
        expect(page_text).to include(
          "Signup Status: Waitlisted"
        )
        expect(page_text).to include(
          "Waitlist Position: 2 of 3"
        )

        # 6. 候补用户可以取消自己的报名
        expect_signup_action(
          document,
          "Cancel Signup",
          activity_shift_signup_path(activity_a, shift_a, signup_a),
          method: :delete
        )
      end

      # Test 29: 取消后可以重新报名
      it "displays the signup button again after cancellation" do
        Signup.create!(
          user: volunteer_a,
          shift: shift_a,
          status: "cancelled"
        )

        get activity_shift_path(activity_a, shift_a)

        expect(response).to have_http_status(:ok)

        document = Nokogiri::HTML(response.body)

        expect(document.text.squish).to include(
          "Signup Status: Cancelled"
        )

        expect_signup_action(
          document,
          "Sign Up",
          activity_shift_signups_path(activity_a, shift_a)
        )
      end

      # Test 30: 取消后班次已满可以重新候补
      it "displays the waitlist button for cancelled signups when full" do
        Signup.create!(
          user: volunteer_a,
          shift: shift_a,
          status: "cancelled"
        )
        Signup.create!(
          user: volunteer_b,
          shift: shift_a,
          status: "confirmed"
        )

        get activity_shift_path(activity_a, shift_a)

        expect(response).to have_http_status(:ok)

        document = Nokogiri::HTML(response.body)

        expect(document.text.squish).to include(
          "Signup Status: Cancelled"
        )

        expect_signup_action(
          document,
          "Join Waitlist",
          activity_shift_signups_path(activity_a, shift_a)
        )
      end

      # ==================================================
      # 报名信息隐私保护测试
      # ==================================================

      # Test 32: 不泄露其他 Volunteer 的报名信息
      it "does not expose other volunteers' signup information" do
        # 1. 创建其他用户的正式及候补报名
        signup_b = Signup.create!(
          user: volunteer_b,
          shift: shift_a,
          status: "confirmed"
        )
        signup_c = Signup.create!(
          user: volunteer_c,
          shift: shift_a,
          status: "waitlisted"
        )

        # 2. 当前用户查看班次详情
        get activity_shift_path(activity_a, shift_a)

        expect(response).to have_http_status(:ok)

        document = Nokogiri::HTML(response.body)

        # 3. 不应显示其他用户的电子邮箱
        expect(response.body).not_to include(
          volunteer_b.email_address
        )
        expect(response.body).not_to include(
          volunteer_c.email_address
        )

        # 4. 不应暴露其他用户的报名操作地址
        expect(response.body).not_to include(
          activity_shift_signup_path(activity_a, shift_a, signup_b)
        )
        expect(response.body).not_to include(
          activity_shift_signup_path(activity_a, shift_a, signup_c)
        )

        # 5. 当前用户只能看到自己的报名入口
        expect_signup_action(
          document,
          "Join Waitlist",
          activity_shift_signups_path(activity_a, shift_a)
        )
      end

      # ==================================================
      # 候补排位及状态更新测试
      # ==================================================

      # Test 33: 前面的候补用户取消后更新排位
      it "updates the waitlist position after an earlier signup is cancelled" do
        # 1. Volunteer B 占用正式名额
        Signup.create!(
          user: volunteer_b,
          shift: shift_a,
          status: "confirmed"
        )

        # 2. Volunteer C 和 A 进入候补队列
        signup_c = Signup.create!(
          user: volunteer_c,
          shift: shift_a,
          status: "waitlisted"
        )
        signup_a = Signup.create!(
          user: volunteer_a,
          shift: shift_a,
          status: "waitlisted"
        )

        queue_time = Time.current.change(usec: 0)

        signup_c.update!(
          waitlisted_at: queue_time - 2.minutes
        )
        signup_a.update!(
          waitlisted_at: queue_time - 1.minute
        )

        # 3. 当前用户最初位于候补第 2 位
        get activity_shift_path(activity_a, shift_a)

        expect(response).to have_http_status(:ok)
        expect(Nokogiri::HTML(response.body).text.squish).to include(
          "Waitlist Position: 2 of 2"
        )

        # 4. Volunteer C 取消自己的候补报名
        CancellationService.call(
          user: volunteer_c,
          signup: signup_c
        )

        expect(signup_c.reload.status).to eq("cancelled")

        # 5. 当前用户刷新班次详情
        get activity_shift_path(activity_a, shift_a)

        expect(response).to have_http_status(:ok)

        page_text = Nokogiri::HTML(response.body).text.squish

        expect(page_text).to include(
          "Signup Status: Waitlisted"
        )
        expect(page_text).to include(
          "Waitlist Position: 1 of 1"
        )
        expect(page_text).not_to include(
          "Waitlist Position: 2 of 2"
        )
      end

      # Test 34: 自动递补后正确显示正式报名状态
      it "displays confirmed status after automatic waitlist promotion" do
        # 1. Volunteer B 正式报名
        signup_b = Signup.create!(
          user: volunteer_b,
          shift: shift_a,
          status: "confirmed"
        )

        # 2. Volunteer A 处于候补状态
        signup_a = Signup.create!(
          user: volunteer_a,
          shift: shift_a,
          status: "waitlisted"
        )

        # 3. 检查递补前的报名状态
        get activity_shift_path(activity_a, shift_a)

        expect(response).to have_http_status(:ok)
        expect(Nokogiri::HTML(response.body).text.squish).to include(
          "Signup Status: Waitlisted"
        )

        # 4. Volunteer B 取消报名
        CancellationService.call(
          user: volunteer_b,
          signup: signup_b
        )

        expect(signup_b.reload.status).to eq("cancelled")
        expect(signup_a.reload.status).to eq("confirmed")

        # 5. 当前用户刷新班次详情
        get activity_shift_path(activity_a, shift_a)

        expect(response).to have_http_status(:ok)

        document = Nokogiri::HTML(response.body)
        page_text = document.text.squish

        # 6. 显示最新报名状态
        expect(page_text).to include(
          "Signup Status: Confirmed"
        )
        expect(page_text).not_to include(
          "Waitlist Position:"
        )

        expect_signup_action(
          document,
          "Cancel Signup",
          activity_shift_signup_path(activity_a, shift_a, signup_a),
          method: :delete
        )
      end

      # Test 35: 重新报名失败后正确显示原有取消状态
      it "displays persisted signup status when re-registration fails" do
        # 1. 创建当前用户已取消的报名记录
        signup_a = Signup.create!(
          user: volunteer_a,
          shift: shift_a,
          status: "cancelled"
        )

        # 2. 当前用户已报名另一个时间重叠的班次
        Signup.create!(
          user: volunteer_a,
          shift: shift_b,
          status: "confirmed"
        )

        original_attributes = signup_a.attributes

        # 3. 尝试重新报名 Shift A
        expect {
          post activity_shift_signups_path(activity_a, shift_a)
        }.not_to change(Signup, :count)

        expect(response).to have_http_status(422)

        document = Nokogiri::HTML(response.body)
        page_text = document.text.squish

        # 4. 显示时间冲突错误
        expect(page_text).to include(
          "Shift overlaps with another confirmed signup"
        )

        # 5. 显示数据库中的真实报名状态
        expect(page_text).to include(
          "Signup Status: Cancelled"
        )
        expect(page_text).not_to include(
          "Signup Status: Confirmed"
        )

        # 6. 原有报名记录保持不变
        expect(signup_a.reload.attributes).to eq(
          original_attributes
        )

        # 7. 仍然显示重新报名入口
        expect_signup_action(
          document,
          "Sign Up",
          activity_shift_signups_path(activity_a, shift_a)
        )
      end
    end

    # ==================================================
    # Organizer 页面操作权限测试
    # ==================================================

    context "organizer access" do
      before do
        sign_in_as(organizer_a)
      end

      # Test 31: Organizer 不显示报名操作
      it "displays management actions without volunteer signup buttons" do
        get activity_shift_path(activity_a, shift_a)

        expect(response).to have_http_status(:ok)

        document = Nokogiri::HTML(response.body)

        # 1. Organizer 不应看到个人报名区域
        expect(document.text).not_to include(
          "My Signup"
        )

        # 2. Organizer 不应看到任何报名操作表单
        expect(signup_forms(document)).to be_empty

        # 3. Organizer 应看到编辑班次入口
        edit_link = document.at_css(
          "a[href='#{edit_activity_shift_path(activity_a, shift_a)}']"
        )

        expect(edit_link).not_to be_nil
        expect(edit_link.text.strip).to eq("Edit Shift")
      end
    end
  end
end
