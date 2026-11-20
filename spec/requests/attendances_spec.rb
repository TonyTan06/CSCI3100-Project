
require 'rails_helper'
require 'nokogiri'

RSpec.describe "Attendances", type: :request do
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

  let(:volunteer_a) { create_volunteer("a") }
  let(:volunteer_b) { create_volunteer("b") }
  let(:volunteer_c) { create_volunteer("c") }
  let(:volunteer_d) { create_volunteer("d") }
  let(:volunteer_e) { create_volunteer("e") }
  let(:volunteer_f) { create_volunteer("f") }

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

  let!(:shift_a) do
    Shift.create!(
      activity: activity_a,
      start_time: start_time,
      end_time: start_time + 3.hours,
      capacity: 3
    )
  end

  let!(:shift_b) do
    Shift.create!(
      activity: activity_b,
      start_time: start_time,
      end_time: start_time + 3.hours,
      capacity: 5
    )
  end

  # ==================================================
  # 公共报名记录
  # ==================================================

  # 正式报名，尚未登记出勤
  let!(:signup_a) do
    Signup.create!(
      user: volunteer_a,
      shift: shift_a,
      status: "confirmed",
      attendance_status: "pending"
    )
  end

  # 正式报名，已出席
  let!(:signup_b) do
    Signup.create!(
      user: volunteer_b,
      shift: shift_a,
      status: "confirmed",
      attendance_status: "present"
    )
  end

  # 正式报名，未出席
  let!(:signup_c) do
    Signup.create!(
      user: volunteer_c,
      shift: shift_a,
      status: "confirmed",
      attendance_status: "absent"
    )
  end

  # 候补报名
  let!(:signup_d) do
    Signup.create!(
      user: volunteer_d,
      shift: shift_a,
      status: "waitlisted"
    )
  end

  # 已取消报名
  let!(:signup_e) do
    Signup.create!(
      user: volunteer_e,
      shift: shift_a,
      status: "cancelled"
    )
  end

  # 其他组织的正式报名
  let!(:signup_f) do
    Signup.create!(
      user: volunteer_f,
      shift: shift_b,
      status: "confirmed"
    )
  end

  # ==================================================
  # 辅助方法
  # ==================================================

  # 创建测试 Volunteer
  def create_volunteer(identifier)
    User.create!(
      email_address: "volunteer_#{identifier}@example.com",
      password: "password123",
      role: "volunteer"
    )
  end

  # 通过 HTTP 请求登录用户
  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password123"
    }
    expect(response).to have_http_status(:redirect)
  end

  # ==================================================
  # 出勤名单查看测试
  # ==================================================

  describe "attendance listing" do
    # ==================================================
    # 未登录用户权限测试
    # ==================================================

    context "unauthenticated access" do
      # Test 1: 未登录用户不能查看出勤名单
      it "redirects unauthenticated users when viewing attendance" do
        get "/activities/#{activity_a.id}/shifts/#{shift_a.id}/attendances"

        expect(response).to redirect_to(
          new_session_path
        )
      end
    end

    # ==================================================
    # Volunteer 权限测试
    # ==================================================

    context "volunteer access" do
      before do
        sign_in_as(volunteer_a)
      end

      # Test 2: Volunteer 不能查看出勤名单
      it "prevents volunteers from viewing attendance records" do
        get "/activities/#{activity_a.id}/shifts/#{shift_a.id}/attendances"

        expect(response).to have_http_status(
          :forbidden
        )

        expect(response.body).not_to include(
          volunteer_b.email_address
        )
        expect(response.body).not_to include(
          volunteer_c.email_address
        )
      end
    end

    # ==================================================
    # Organizer 出勤名单查看测试
    # ==================================================

    context "organizer access" do
      before do
        sign_in_as(organizer_a)
      end

      # Test 3: Organizer 可以查看正式报名人员及出勤状态
      it "displays confirmed volunteers and their attendance statuses" do
        # 1. 请求出勤名单页面
        get "/activities/#{activity_a.id}/shifts/#{shift_a.id}/attendances"

        expect(response).to have_http_status(:ok)

        # 2. 解析 HTML 页面
        document = Nokogiri::HTML(response.body)
        page_text = document.text.squish

        # 3. 检查页面所属活动及组织
        expect(page_text).to include(activity_a.title)
        expect(page_text).to include(organization_a.name)

        # 4. 获取出勤名单表格中的数据行
        rows = document.css("table tr")

        # 5. 检查每位正式报名用户的出勤状态
        [signup_a, signup_b, signup_c].each do |signup|
          row = rows.find do |element|
            element.text.include?(
              signup.user.email_address
            )
          end

          expect(row).not_to be_nil
          expect(row.text.squish).to include(
            signup.attendance_status.humanize
          )
        end
      end

      # Test 4: 不显示候补及已取消的报名人员
      it "excludes waitlisted and cancelled signups from attendance" do
        get "/activities/#{activity_a.id}/shifts/#{shift_a.id}/attendances"

        expect(response).to have_http_status(:ok)

        # 正式报名人员应该显示
        expect(response.body).to include(
          volunteer_a.email_address
        )
        expect(response.body).to include(
          volunteer_b.email_address
        )
        expect(response.body).to include(
          volunteer_c.email_address
        )

        # 候补及已取消人员不应该显示
        expect(response.body).not_to include(
          volunteer_d.email_address
        )
        expect(response.body).not_to include(
          volunteer_e.email_address
        )
      end

      # Test 5: 不显示其他班次的报名人员
      it "excludes signups belonging to other shifts" do
        # 1. 创建同一活动下的另一个班次
        other_shift = Shift.create!(
          activity: activity_a,
          start_time: start_time + 5.hours,
          end_time: start_time + 7.hours,
          capacity: 5
        )

        # 2. 创建该班次的正式报名
        other_volunteer = create_volunteer("other")

        Signup.create!(
          user: other_volunteer,
          shift: other_shift,
          status: "confirmed"
        )

        # 3. 查看 Shift A 的出勤名单
        get "/activities/#{activity_a.id}/shifts/#{shift_a.id}/attendances"

        expect(response).to have_http_status(:ok)

        # 4. 应显示当前班次的正式报名人员
        expect(response.body).to include(
          volunteer_a.email_address
        )

        # 5. 不应显示同一活动下其他班次的人员
        expect(response.body).not_to include(
          other_volunteer.email_address
        )

        # 6. 不应显示其他组织的报名人员
        expect(response.body).not_to include(
          volunteer_f.email_address
        )
      end

      # Test 6: Organizer 不能查看其他组织的出勤名单
      it "prevents organizers from viewing attendance belonging to another organization" do
        get "/activities/#{activity_b.id}/shifts/#{shift_b.id}/attendances"

        expect(response).to have_http_status(
          :not_found
        )

        expect(response.body).not_to include(
          volunteer_f.email_address
        )
        expect(response.body).not_to include(
          activity_b.title
        )
      end

      # Test 7: 禁止使用错误的 Activity ID 访问出勤名单
      it "rejects attendance requests through an incorrect parent activity" do
        # 1. 创建同一组织下的另一个活动
        other_activity = Activity.create!(
          title: "Tree Planting",
          description: "Plant trees around campus",
          location: "CUHK Campus",
          organization: organization_a
        )

        # 2. 使用错误的 Activity ID 请求名单
        get "/activities/#{other_activity.id}/shifts/#{shift_a.id}/attendances"

        expect(response).to have_http_status(
          :not_found
        )

        expect(response.body).not_to include(
          volunteer_a.email_address
        )
      end

      # Test 8: 请求不存在的班次时返回 404
      it "returns not found when the requested shift does not exist" do
        nonexistent_shift_id = Shift.maximum(:id) + 1

        get "/activities/#{activity_a.id}/shifts/#{nonexistent_shift_id}/attendances"

        expect(response).to have_http_status(
          :not_found
        )
      end

      # Test 9: 没有正式报名人员时正确显示空名单
      it "displays an empty attendance list when there are no confirmed signups" do
        # 1. 创建另一个班次
        empty_shift = Shift.create!(
          activity: activity_a,
          start_time: start_time + 5.hours,
          end_time: start_time + 7.hours,
          capacity: 5
        )

        # 2. 创建一条已取消的报名记录
        Signup.create!(
          user: volunteer_a,
          shift: empty_shift,
          status: "cancelled"
        )

        # 3. 请求出勤名单
        get "/activities/#{activity_a.id}/shifts/#{empty_shift.id}/attendances"

        expect(response).to have_http_status(:ok)

        page_text = Nokogiri::HTML(response.body).text.squish

        # 4. 显示空名单提示
        expect(page_text).to include(
          "No confirmed signups."
        )

        # 5. 不显示已取消的报名人员
        expect(response.body).not_to include(
          volunteer_a.email_address
        )
      end
    end
  end

  # ==================================================
  # 出勤管理入口测试
  # ==================================================

  describe "attendance management navigation" do
    # Test 10: Organizer 可以看到出勤管理入口
    it "displays the attendance management link for organizers" do
      sign_in_as(organizer_a)

      get activity_shift_path(activity_a, shift_a)

      expect(response).to have_http_status(:ok)

      document = Nokogiri::HTML(response.body)

      attendance_path =
        "/activities/#{activity_a.id}/shifts/#{shift_a.id}/attendances"

      attendance_link = document.at_css(
        "a[href='#{attendance_path}']"
      )

      expect(attendance_link).not_to be_nil
      expect(attendance_link.text.strip).to eq(
        "Manage Attendance"
      )
    end

    # Test 11: Volunteer 不会看到出勤管理入口
    it "does not display the attendance management link for volunteers" do
      sign_in_as(volunteer_a)

      get activity_shift_path(activity_a, shift_a)

      expect(response).to have_http_status(:ok)

      document = Nokogiri::HTML(response.body)

      attendance_path =
        "/activities/#{activity_a.id}/shifts/#{shift_a.id}/attendances"

      expect(
        document.at_css(
          "a[href='#{attendance_path}']"
        )
      ).to be_nil

      expect(document.text).not_to include(
        "Manage Attendance"
      )
    end
  end

  # ==================================================
  # 出勤状态修改测试
  # ==================================================

  describe "attendance updating" do
    # 提交出勤状态修改请求
    def update_attendance(signup, status, activity: activity_a, shift: shift_a, extra: {})
      patch "/activities/#{activity.id}/shifts/#{shift.id}/attendances/#{signup.id}", params: {
        attendance: extra.merge(
          attendance_status: status
        )
      }
    end

    # 检查出勤修改成功且其他属性保持不变
    def expect_attendance_updated(signup, original_attributes, status)
      signup.reload

      expect(signup.attendance_status).to eq(status)

      expect(
        signup.attributes.except("attendance_status", "updated_at")
      ).to eq(
        original_attributes.except("attendance_status", "updated_at")
      )

      expect(response).to redirect_to(
        activity_shift_attendances_path(activity_a, shift_a)
      )
      expect(response).to have_http_status(:see_other)
    end

    # ==================================================
    # 未登录用户权限测试
    # ==================================================

    context "unauthenticated access" do
      # Test 12: 未登录用户不能修改出勤
      it "prevents unauthenticated users from updating attendance" do
        # 1. 保存原有报名数据
        original_attributes = signup_a.attributes

        # 2. 尝试修改出勤状态
        update_attendance(signup_a, "present")

        # 3. 检查是否跳转至登录页面
        expect(response).to redirect_to(
          new_session_path
        )

        # 4. 原有报名数据保持不变
        expect(signup_a.reload.attributes).to eq(
          original_attributes
        )
      end
    end

    # ==================================================
    # Volunteer 权限测试
    # ==================================================

    context "volunteer access" do
      before do
        sign_in_as(volunteer_a)
      end

      # Test 13: Volunteer 不能修改出勤
      it "prevents volunteers from updating their own attendance" do
        # 1. 保存原有报名数据
        original_attributes = signup_a.attributes

        # 2. Volunteer 尝试修改自己的出勤
        update_attendance(signup_a, "present")

        # 3. 检查权限拒绝响应
        expect(response).to have_http_status(
          :forbidden
        )

        # 4. 原有报名数据保持不变
        expect(signup_a.reload.attributes).to eq(
          original_attributes
        )
      end
    end

    # ==================================================
    # Organizer 出勤修改测试
    # ==================================================

    context "organizer access" do
      before do
        sign_in_as(organizer_a)
      end

      # Test 14: Organizer 可以标记已出席
      it "allows organizers to mark confirmed volunteers as present" do
        # 1. 检查原有出勤状态
        expect(signup_a.attendance_status).to eq("pending")
        original_attributes = signup_a.attributes

        # 2. 提交出勤修改请求
        expect {
          update_attendance(signup_a, "present")
        }.not_to change(Signup, :count)

        # 3. 检查修改结果
        expect_attendance_updated(
          signup_a,
          original_attributes,
          "present"
        )
      end

      # Test 15: Organizer 可以标记未出席
      it "allows organizers to mark confirmed volunteers as absent" do
        # 1. 检查原有出勤状态
        expect(signup_b.attendance_status).to eq("present")
        original_attributes = signup_b.attributes

        # 2. 提交出勤修改请求
        expect {
          update_attendance(signup_b, "absent")
        }.not_to change(Signup, :count)

        # 3. 检查修改结果
        expect_attendance_updated(
          signup_b,
          original_attributes,
          "absent"
        )
      end

      # Test 16: Organizer 可以恢复为 pending
      it "allows organizers to reset attendance to pending" do
        # 1. 检查原有出勤状态
        expect(signup_c.attendance_status).to eq("absent")
        original_attributes = signup_c.attributes

        # 2. 将出勤状态恢复为 pending
        expect {
          update_attendance(signup_c, "pending")
        }.not_to change(Signup, :count)

        # 3. 检查修改结果
        expect_attendance_updated(
          signup_c,
          original_attributes,
          "pending"
        )
      end

      # ==================================================
      # 出勤业务规则测试
      # ==================================================

      # Test 17: 拒绝非法出勤状态
      it "rejects invalid attendance statuses" do
        # 1. 保存原有报名数据
        original_attributes = signup_a.attributes

        # 2. 提交不存在的出勤状态
        update_attendance(signup_a, "unknown")

        # 3. 检查 HTTP 响应
        expect(response).to have_http_status(422)

        # 4. 检查错误信息
        page_text = Nokogiri::HTML(response.body).text.squish

        expect(page_text).to include(
          "Attendance status is not included in the list"
        )

        # 5. 原有出勤状态及报名数据保持不变
        expect(signup_a.reload.attributes).to eq(
          original_attributes
        )

        # 6. 失败后仍显示正式报名人员名单
        expect(response.body).to include(
          volunteer_a.email_address
        )
        expect(response.body).to include(
          volunteer_b.email_address
        )
        expect(response.body).to include(
          volunteer_c.email_address
        )
      end

      # Test 18: 禁止修改候补人员出勤
      it "rejects attendance updates for waitlisted signups" do
        # 1. 确认报名处于候补状态
        expect(signup_d.status).to eq("waitlisted")
        original_attributes = signup_d.attributes

        # 2. 尝试将候补用户标记为已出席
        update_attendance(signup_d, "present")

        # 3. 检查 HTTP 响应
        expect(response).to have_http_status(422)

        # 4. 检查错误信息
        page_text = Nokogiri::HTML(response.body).text.squish

        expect(page_text).to include(
          "Status must be confirmed to manage attendance"
        )

        # 5. 候补状态及排队时间保持不变
        expect(signup_d.reload.attributes).to eq(
          original_attributes
        )

        # 6. 候补人员仍不出现在出勤名单
        expect(response.body).not_to include(
          volunteer_d.email_address
        )
      end

      # Test 19: 禁止修改已取消人员出勤
      it "rejects attendance updates for cancelled signups" do
        # 1. 确认报名已经取消
        expect(signup_e.status).to eq("cancelled")
        original_attributes = signup_e.attributes

        # 2. 尝试修改已取消人员的出勤
        update_attendance(signup_e, "present")

        # 3. 检查 HTTP 响应
        expect(response).to have_http_status(422)

        # 4. 检查错误信息
        page_text = Nokogiri::HTML(response.body).text.squish

        expect(page_text).to include(
          "Status must be confirmed to manage attendance"
        )

        # 5. 原有报名记录保持不变
        expect(signup_e.reload.attributes).to eq(
          original_attributes
        )

        # 6. 已取消人员仍不出现在出勤名单
        expect(response.body).not_to include(
          volunteer_e.email_address
        )
      end

      # ==================================================
      # 组织隔离及资源安全测试
      # ==================================================

      # Test 20: 禁止跨组织修改出勤
      it "prevents organizers from updating attendance belonging to another organization" do
        # 1. 保存其他组织的报名数据
        original_attributes = signup_f.attributes

        # 2. 尝试修改其他组织人员的出勤
        update_attendance(
          signup_f,
          "present",
          activity: activity_b,
          shift: shift_b
        )

        # 3. 检查权限拒绝响应
        expect(response).to have_http_status(
          :not_found
        )

        # 4. 其他组织的报名数据保持不变
        expect(signup_f.reload.attributes).to eq(
          original_attributes
        )

        # 5. 不泄露其他组织的用户信息
        expect(response.body).not_to include(
          volunteer_f.email_address
        )
      end

      # Test 21: 禁止通过错误的 Activity ID 修改出勤
      it "rejects attendance updates through an incorrect parent activity" do
        # 1. 创建同一组织下的另一个活动
        other_activity = Activity.create!(
          title: "Tree Planting",
          description: "Plant trees around campus",
          location: "CUHK Campus",
          organization: organization_a
        )

        # 2. 保存原有报名数据
        original_attributes = signup_a.attributes

        # 3. 使用错误的 Activity ID 修改出勤
        update_attendance(
          signup_a,
          "present",
          activity: other_activity
        )

        # 4. 检查资源归属错误响应
        expect(response).to have_http_status(
          :not_found
        )

        # 5. 原有报名数据保持不变
        expect(signup_a.reload.attributes).to eq(
          original_attributes
        )
      end

      # Test 22: 禁止通过错误的 Shift ID 修改出勤
      it "rejects attendance updates through an incorrect parent shift" do
        # 1. 创建同一活动下的另一个班次
        other_shift = Shift.create!(
          activity: activity_a,
          start_time: start_time + 5.hours,
          end_time: start_time + 7.hours,
          capacity: 5
        )

        # 2. 保存原有报名数据
        original_attributes = signup_a.attributes

        # 3. 使用错误的 Shift ID 修改出勤
        update_attendance(
          signup_a,
          "present",
          shift: other_shift
        )

        # 4. 检查资源归属错误响应
        expect(response).to have_http_status(
          :not_found
        )

        # 5. 原有报名数据保持不变
        expect(signup_a.reload.attributes).to eq(
          original_attributes
        )
      end

      # Test 23: 请求不存在的 Signup 时返回 404
      it "returns not found when updating attendance for a nonexistent signup" do
        nonexistent_signup_id = Signup.maximum(:id) + 1

        expect {
          patch "/activities/#{activity_a.id}/shifts/#{shift_a.id}/attendances/#{nonexistent_signup_id}", params: {
            attendance: {
              attendance_status: "present"
            }
          }
        }.not_to change(Signup, :count)

        expect(response).to have_http_status(
          :not_found
        )
      end

      # Test 24: 防止修改受保护属性及影响候补队列
      it "ignores protected attributes and preserves signup and waitlist consistency" do
        # 1. 保存目标报名的原有数据
        original_attributes = signup_a.attributes

        # 2. 保存其他报名记录的数据
        other_signups = [
          signup_b,
          signup_c,
          signup_d,
          signup_e,
          signup_f
        ]

        original_other_attributes = other_signups.map(&:attributes)

        # 3. 保存班次数据及候补队列
        original_shift_attributes = shift_a.attributes
        original_other_shift_attributes = shift_b.attributes
        original_waitlist_ids = shift_a.waitlist_queue.pluck(:id)

        expect(shift_a.confirmed_count).to eq(3)
        expect(shift_a.available_slots).to eq(0)

        # 4. 构造包含受保护属性的请求参数
        malicious_attributes = {
          id: signup_f.id,
          user_id: volunteer_f.id,
          shift_id: shift_b.id,
          status: "cancelled",
          waitlisted_at: 1.day.ago.iso8601
        }

        # 5. 提交出勤修改请求
        expect {
          update_attendance(
            signup_a,
            "present",
            extra: malicious_attributes
          )
        }.not_to change(Signup, :count)

        # 6. 只有出勤状态及更新时间可以改变
        expect_attendance_updated(
          signup_a,
          original_attributes,
          "present"
        )

        expect(signup_a.status).to eq("confirmed")
        expect(signup_a.user_id).to eq(volunteer_a.id)
        expect(signup_a.shift_id).to eq(shift_a.id)
        expect(signup_a.waitlisted_at).to be_nil

        # 7. 其他报名记录保持不变
        expect(
          other_signups.map { |signup| signup.reload.attributes }
        ).to eq(
          original_other_attributes
        )

        # 8. 班次数据保持不变
        expect(shift_a.reload.attributes).to eq(
          original_shift_attributes
        )
        expect(shift_b.reload.attributes).to eq(
          original_other_shift_attributes
        )

        # 9. 正式报名人数及剩余名额保持不变
        expect(shift_a.confirmed_count).to eq(3)
        expect(shift_a.available_slots).to eq(0)
        expect(shift_a.full?).to be true

        # 10. 候补队列及排队顺序保持不变
        expect(shift_a.waitlist_queue.pluck(:id)).to eq(
          original_waitlist_ids
        )
        expect(signup_d.reload.status).to eq("waitlisted")
      end
    end
  end

  # ==================================================
  # 出勤显示及统计测试
  # ==================================================

  describe "attendance display and statistics" do
    # 检查出勤统计数据
    def expect_attendance_summary(document, confirmed:, present:, absent:, pending:)
      summary = document.at_css("#attendance-summary")
      expect(summary).not_to be_nil

      summary_text = summary.text.squish
      expect(summary_text).to include("Confirmed: #{confirmed}")
      expect(summary_text).to include("Present: #{present}")
      expect(summary_text).to include("Absent: #{absent}")
      expect(summary_text).to include("Pending: #{pending}")
    end

    # 查找指定报名记录对应的出勤表单
    def attendance_form(document, signup)
      path = activity_shift_attendance_path(
        activity_a,
        shift_a,
        signup
      )
      document.at_css("form[action='#{path}']")
    end

    # ==================================================
    # Organizer 出勤统计测试
    # ==================================================

    context "organizer access" do
      before do
        sign_in_as(organizer_a)
      end

      # Test 25: 正确显示出勤人数统计
      it "displays accurate attendance statistics" do
        # 1. 请求出勤管理页面
        get activity_shift_attendances_path(activity_a, shift_a)

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)

        # 2. 统计中只包含正式报名人员
        expect_attendance_summary(
          document,
          confirmed: 3,
          present: 1,
          absent: 1,
          pending: 1
        )
      end

      # Test 26: 没有正式报名时统计全部为零
      it "displays zero attendance counts when there are no confirmed signups" do
        # 1. 创建没有正式报名人员的班次
        empty_shift = Shift.create!(
          activity: activity_a,
          start_time: start_time + 5.hours,
          end_time: start_time + 7.hours,
          capacity: 5
        )

        # 2. 创建已取消的报名记录
        Signup.create!(
          user: volunteer_a,
          shift: empty_shift,
          status: "cancelled"
        )

        # 3. 请求出勤管理页面
        get activity_shift_attendances_path(activity_a, empty_shift)

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)

        # 4. 所有出勤统计均为零
        expect_attendance_summary(
          document,
          confirmed: 0,
          present: 0,
          absent: 0,
          pending: 0
        )

        expect(document.text.squish).to include(
          "No confirmed signups."
        )
      end

      # Test 27: 出勤修改成功后更新统计
      it "updates attendance statistics after a successful attendance update" do
        # 1. 将 Volunteer A 标记为已出席
        patch activity_shift_attendance_path(activity_a, shift_a, signup_a),
              params: {
                attendance: {
                  attendance_status: "present"
                }
              }

        expect(response).to have_http_status(:see_other)
        expect(signup_a.reload.attendance_status).to eq("present")

        # 2. 跟随跳转至出勤管理页面
        follow_redirect!

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)

        # 3. 检查更新后的出勤统计
        expect_attendance_summary(
          document,
          confirmed: 3,
          present: 2,
          absent: 1,
          pending: 0
        )
      end

      # Test 28: 修改失败后统计及表单保持真实状态
      it "preserves persisted attendance statistics and form values after a failed update" do
        # 1. 保存原有报名数据
        original_attributes = signup_a.attributes

        # 2. 提交非法出勤状态
        patch activity_shift_attendance_path(activity_a, shift_a, signup_a),
              params: {
                attendance: {
                  attendance_status: "unknown"
                }
              }

        expect(response).to have_http_status(422)
        document = Nokogiri::HTML(response.body)

        # 3. 检查错误信息
        expect(document.text.squish).to include(
          "Attendance status is not included in the list"
        )

        # 4. 出勤统计保持不变
        expect_attendance_summary(
          document,
          confirmed: 3,
          present: 1,
          absent: 1,
          pending: 1
        )

        # 5. 检查表单显示数据库中的真实出勤状态
        form = attendance_form(document, signup_a)
        expect(form).not_to be_nil

        select = form.at_css(
          'select[name="attendance[attendance_status]"]'
        )
        expect(select).not_to be_nil

        selected_option = select.at_css("option[selected]")
        expect(selected_option).not_to be_nil
        expect(selected_option["value"]).to eq("pending")

        # 6. 数据库中的报名记录保持不变
        expect(signup_a.reload.attributes).to eq(
          original_attributes
        )
      end

      # ==================================================
      # 出勤表单专项测试
      # ==================================================

      # Test 29: 每位正式报名人员具有独立的出勤表单
      it "displays an independent attendance form for each confirmed signup" do
        get activity_shift_attendances_path(activity_a, shift_a)

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)

        # 1. 获取正式报名人员对应的表单
        [signup_a, signup_b, signup_c].each do |signup|
          form = attendance_form(document, signup)
          expect(form).not_to be_nil

          # 2. 检查表单的 HTTP 请求方式
          expect(form["method"]).to eq("post")

          method_input = form.at_css(
            'input[name="_method"]'
          )
          expect(method_input).not_to be_nil
          expect(method_input["value"]).to eq("patch")

          # 3. 检查提交按钮
          submit_input = form.at_css(
            'input[type="submit"]'
          )
          expect(submit_input).not_to be_nil
          expect(submit_input["value"]).to eq(
            "Update Attendance"
          )

          # 4. 检查表单属于正确的用户
          row = form.ancestors("tr").first
          expect(row).not_to be_nil
          expect(row.text).to include(
            signup.user.email_address
          )
        end

        # 5. 候补及已取消用户不具有出勤表单
        expect(
          attendance_form(document, signup_d)
        ).to be_nil
        expect(
          attendance_form(document, signup_e)
        ).to be_nil
      end

      # Test 30: 出勤表单只允许三个合法状态
      it "displays only valid attendance options with the correct selected status" do
        get activity_shift_attendances_path(activity_a, shift_a)

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)

        [signup_a, signup_b, signup_c].each do |signup|
          # 1. 获取对应的出勤表单
          form = attendance_form(document, signup)
          expect(form).not_to be_nil

          # 2. 获取出勤状态下拉菜单
          select = form.at_css(
            'select[name="attendance[attendance_status]"]'
          )
          expect(select).not_to be_nil

          # 3. 检查下拉菜单仅包含合法状态
          option_values = select.css("option").map do |option|
            option["value"]
          end

          expect(option_values).to eq(
            ["pending", "present", "absent"]
          )

          # 4. 检查默认选项与数据库一致
          selected_option = select.at_css("option[selected]")
          expect(selected_option).not_to be_nil
          expect(selected_option["value"]).to eq(
            signup.attendance_status
          )

          # 5. 每个下拉菜单使用独立的 ID
          expect(select["id"]).to eq(
            "attendance_status_#{signup.id}"
          )
        end
      end
    end

    # ==================================================
    # Volunteer 个人出勤状态测试
    # ==================================================

    context "volunteer access" do
      # Test 31: Volunteer 可以查看自己的出勤状态
      it "allows volunteers to view their own attendance status" do
        sign_in_as(volunteer_a)

        # 检查三种合法出勤状态的页面显示
        ["pending", "present", "absent"].each do |status|
          # 1. 设置测试所需的出勤状态
          signup_a.update!(
            attendance_status: status
          )

          # 2. 请求班次详情页面
          get activity_shift_path(activity_a, shift_a)

          expect(response).to have_http_status(:ok)
          page_text = Nokogiri::HTML(response.body).text.squish

          # 3. 报名状态保持为 Confirmed
          expect(page_text).to include(
            "Signup Status: Confirmed"
          )

          # 4. 显示当前用户的真实出勤状态
          expect(page_text).to include(
            "Attendance Status: #{status.humanize}"
          )
        end
      end

      # Test 32: Volunteer 不会看到其他人的出勤信息
      it "does not expose other volunteers' attendance information" do
        sign_in_as(volunteer_a)

        get activity_shift_path(activity_a, shift_a)

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)
        page_text = document.text.squish

        # 1. 只显示当前用户的出勤状态
        expect(page_text).to include(
          "Attendance Status: Pending"
        )
        expect(page_text).not_to include(
          "Attendance Status: Present"
        )
        expect(page_text).not_to include(
          "Attendance Status: Absent"
        )

        # 2. 不显示其他用户的个人信息
        expect(response.body).not_to include(
          volunteer_b.email_address
        )
        expect(response.body).not_to include(
          volunteer_c.email_address
        )

        # 3. 不显示 Organizer 的出勤管理入口
        expect(document.at_css("#attendance-summary")).to be_nil
        expect(page_text).not_to include("Manage Attendance")

        # 4. 不显示任何出勤修改表单
        attendance_path = activity_shift_attendances_path(
          activity_a,
          shift_a
        )

        attendance_forms = document.css("form").select do |form|
          form["action"].to_s.start_with?(attendance_path)
        end

        expect(attendance_forms).to be_empty
      end

      # Test 33: 候补及已取消用户不显示出勤状态
      it "does not display attendance status for waitlisted or cancelled signups" do
        sign_in_as(volunteer_d)

        # 1. 检查候补报名状态
        get activity_shift_path(activity_a, shift_a)

        expect(response).to have_http_status(:ok)
        page_text = Nokogiri::HTML(response.body).text.squish

        expect(page_text).to include(
          "Signup Status: Waitlisted"
        )
        expect(page_text).not_to include(
          "Attendance Status:"
        )

        # 2. 取消候补报名
        CancellationService.call(
          user: volunteer_d,
          signup: signup_d
        )

        expect(signup_d.reload.status).to eq("cancelled")

        # 3. 检查已取消报名状态
        get activity_shift_path(activity_a, shift_a)

        expect(response).to have_http_status(:ok)
        page_text = Nokogiri::HTML(response.body).text.squish

        expect(page_text).to include(
          "Signup Status: Cancelled"
        )
        expect(page_text).not_to include(
          "Attendance Status:"
        )
      end

      # Test 34: 未报名用户不显示出勤状态
      it "does not display attendance status for unregistered volunteers" do
        # 1. 创建尚未报名的 Volunteer
        unregistered_volunteer = create_volunteer("unregistered")
        sign_in_as(unregistered_volunteer)

        # 2. 请求班次详情页面
        get activity_shift_path(activity_a, shift_a)

        expect(response).to have_http_status(:ok)
        page_text = Nokogiri::HTML(response.body).text.squish

        # 3. 显示未报名状态，但不显示出勤状态
        expect(page_text).to include(
          "Signup Status: Not registered"
        )
        expect(page_text).not_to include(
          "Attendance Status:"
        )
      end
    end
  end

end
