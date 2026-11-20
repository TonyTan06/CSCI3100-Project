
require 'rails_helper'
require 'rails_helper'
require 'nokogiri'

RSpec.describe "HTTP Security", type: :request do
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

  let!(:activity) do
    Activity.create!(
      title: "Campus Cleaning",
      description: "Campus cleaning volunteer activity",
      location: "CUHK Campus",
      organization: organization
    )
  end

  let(:start_time) do
    Time.current.change(usec: 0) + 1.day
  end

  let!(:shift) do
    Shift.create!(
      activity: activity,
      start_time: start_time,
      end_time: start_time + 3.hours,
      capacity: 5
    )
  end

  let!(:signup) do
    Signup.create!(
      user: volunteer,
      shift: shift,
      status: "confirmed",
      attendance_status: "pending"
    )
  end

  # ==================================================
  # 辅助方法
  # ==================================================

  # 通过 HTTP 请求登录用户
  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password123"
    }
    expect(response).to have_http_status(:redirect)
  end

  # 获取业务数据库记录的完整快照
  def database_snapshot
    {
      activities: Activity.order(:id).map(&:attributes),
      shifts: Shift.order(:id).map(&:attributes),
      signups: Signup.order(:id).map(&:attributes)
    }
  end

  # 检查非法参数请求是否被正确拒绝
  def expect_bad_request(method, path, payload)
    # 1. 保存请求前的数据库状态
    original_snapshot = database_snapshot
    # 2. 发送非法参数请求
    public_send(method, path, params: payload)
    # 3. 检查数据库记录没有发生变化
    expect(database_snapshot).to eq(original_snapshot)
    # 4. 检查 HTTP 响应状态码
    expect(response).to have_http_status(:bad_request)
  end

  # ==================================================
  # 可复用的非法参数结构测试
  # ==================================================

  shared_examples "rejects malformed parameter objects" do |parameter_key|
    # 检查缺少必要参数对象的情况
    it "rejects requests with a missing parameter object" do
      expect_bad_request(
        request_method,
        request_path,
        {}
      )
    end

    # 检查参数对象被替换为 String 的情况
    it "rejects requests with a string parameter object" do
      expect_bad_request(
        request_method,
        request_path,
        {
          parameter_key => "invalid"
        }
      )
    end

    # 检查参数对象被替换为 Array 的情况
    it "rejects requests with an array parameter object" do
      expect_bad_request(
        request_method,
        request_path,
        {
          parameter_key => ["invalid", "data"]
        }
      )
    end
  end

  # ==================================================
  # HTTP 非法参数结构测试
  # ==================================================

  describe "malformed request parameters" do
    before do
      sign_in_as(organizer)
    end

    # ==================================================
    # Activity 参数安全测试
    # ==================================================

    # Test 1-3: 创建活动时拒绝非法参数结构
    context "creating an activity" do
      let(:request_method) { :post }
      let(:request_path) { activities_path }

      include_examples "rejects malformed parameter objects",
                       :activity
    end

    # Test 4-6: 修改活动时拒绝非法参数结构
    context "updating an activity" do
      let(:request_method) { :patch }
      let(:request_path) { activity_path(activity) }

      include_examples "rejects malformed parameter objects",
                       :activity
    end

    # ==================================================
    # Shift 参数安全测试
    # ==================================================

    # Test 7-9: 创建班次时拒绝非法参数结构
    context "creating a shift" do
      let(:request_method) { :post }
      let(:request_path) do
        activity_shifts_path(activity)
      end

      include_examples "rejects malformed parameter objects",
                       :shift
    end

    # Test 10-12: 修改班次时拒绝非法参数结构
    context "updating a shift" do
      let(:request_method) { :patch }
      let(:request_path) do
        activity_shift_path(activity, shift)
      end

      include_examples "rejects malformed parameter objects",
                       :shift
    end

    # ==================================================
    # Attendance 参数安全测试
    # ==================================================

    # Test 13-15: 修改出勤时拒绝非法参数结构
    context "updating attendance" do
      let(:request_method) { :patch }
      let(:request_path) do
        activity_shift_attendance_path(
          activity,
          shift,
          signup
        )
      end

      include_examples "rejects malformed parameter objects",
                       :attendance
    end
  end

  # ==================================================
  # 权限及恶意参数安全测试
  # ==================================================

  describe "authorization and malicious parameters" do
    # ==================================================
    # 补充测试数据
    # ==================================================

    let(:other_organization) do
      Organization.create!(
        name: "CUHK Community Service"
      )
    end

    let(:other_organizer) do
      User.create!(
        email_address: "other_organizer@example.com",
        password: "password123",
        role: "organizer",
        organization: other_organization
      )
    end

    let(:other_volunteer) do
      User.create!(
        email_address: "other_volunteer@example.com",
        password: "password123",
        role: "volunteer"
      )
    end

    let(:other_activity) do
      Activity.create!(
        title: "Community Service",
        description: "Community volunteer activity",
        location: "Sha Tin",
        organization: other_organization
      )
    end

    # ==================================================
    # 辅助方法
    # ==================================================

    # 检查未授权请求是否被拒绝且没有修改数据库
    def expect_rejected_request(method, path, payload, status)
      # 1. 保存请求前的数据库状态
      original_snapshot = database_snapshot
      # 2. 发送未授权请求
      public_send(method, path, params: payload)
      # 3. 检查 HTTP 响应状态
      expect(response).to have_http_status(status)
      # 4. 检查数据库记录没有发生变化
      expect(database_snapshot).to eq(original_snapshot)
    end

    # ==================================================
    # Volunteer 非法管理请求测试
    # ==================================================

    context "unauthorized volunteer requests" do
      before do
        sign_in_as(volunteer)
      end

      # Test 16: Volunteer 非法创建活动
      it "rejects unauthorized activity creation before parameter validation" do
        expect_rejected_request(
          :post,
          activities_path,
          { activity: "invalid" },
          :forbidden
        )
      end

      # Test 17: Volunteer 非法修改活动
      it "rejects unauthorized activity updates before parameter validation" do
        expect_rejected_request(
          :patch,
          activity_path(activity),
          { activity: ["invalid"] },
          :forbidden
        )
      end

      # Test 18: Volunteer 非法创建班次
      it "rejects unauthorized shift creation before parameter validation" do
        expect_rejected_request(
          :post,
          activity_shifts_path(activity),
          { shift: "invalid" },
          :forbidden
        )
      end

      # Test 19: Volunteer 非法修改班次
      it "rejects unauthorized shift updates before parameter validation" do
        expect_rejected_request(
          :patch,
          activity_shift_path(activity, shift),
          { shift: ["invalid"] },
          :forbidden
        )
      end

      # Test 20: Volunteer 非法修改出勤
      it "rejects unauthorized attendance updates before parameter validation" do
        expect_rejected_request(
          :patch,
          activity_shift_attendance_path(
            activity,
            shift,
            signup
          ),
          { attendance: "invalid" },
          :forbidden
        )
      end
    end

    # ==================================================
    # 跨组织非法请求测试
    # ==================================================

    context "cross-organization requests" do
      before do
        sign_in_as(other_organizer)
      end

      # Test 21: 跨组织修改活动时优先检查权限
      it "rejects cross-organization activity updates before parameter validation" do
        expect_rejected_request(
          :patch,
          activity_path(activity),
          { activity: "invalid" },
          :not_found
        )
      end

      # Test 22: 跨组织修改班次时优先检查权限
      it "rejects cross-organization shift updates before parameter validation" do
        expect_rejected_request(
          :patch,
          activity_shift_path(activity, shift),
          { shift: ["invalid"] },
          :not_found
        )
      end

      # Test 23: 跨组织修改出勤时优先检查权限
      it "rejects cross-organization attendance updates before parameter validation" do
        expect_rejected_request(
          :patch,
          activity_shift_attendance_path(
            activity,
            shift,
            signup
          ),
          { attendance: "invalid" },
          :not_found
        )
      end
    end

    # ==================================================
    # 父子资源关系安全测试
    # ==================================================

    context "malicious resource identifiers" do
      # Test 24: 伪造父级 Activity ID
      it "rejects attendance updates through an incorrect parent activity" do
        # 1. 创建同一组织下的另一个活动
        incorrect_activity = Activity.create!(
          title: "Food Distribution",
          description: "Food distribution volunteer activity",
          location: "Sha Tin",
          organization: organization
        )
        # 2. 登录当前组织的 Organizer
        sign_in_as(organizer)
        # 3. 使用错误的 Activity ID 修改真实出勤记录
        expect_rejected_request(
          :patch,
          activity_shift_attendance_path(
            incorrect_activity,
            shift,
            signup
          ),
          {
            attendance: {
              attendance_status: "present"
            }
          },
          :not_found
        )
      end
    end

    # ==================================================
    # Dashboard 身份及组织伪造测试
    # ==================================================

    context "dashboard parameter tampering" do
      # Test 25: Volunteer Dashboard 身份伪造
      it "ignores forged user identifiers in volunteer dashboard requests" do
        # 1. 创建其他 Volunteer 的报名记录
        other_signup = Signup.create!(
          user: other_volunteer,
          shift: shift,
          status: "confirmed",
          attendance_status: "absent"
        )
        # 2. 登录当前 Volunteer
        sign_in_as(volunteer)
        original_snapshot = database_snapshot
        # 3. 尝试通过 URL 参数访问其他用户的数据
        get dashboard_path, params: {
          user_id: other_volunteer.id,
          role: "organizer",
          organization_id: organization.id
        }
        expect(response).to have_http_status(:ok)
        # 4. 仍然显示当前用户的个人 Dashboard
        expect(response.body).to include("My Dashboard")
        expect(response.body).to include(
          "id=\"signup-#{signup.id}\""
        )
        # 5. 不泄露其他用户的报名及个人信息
        expect(response.body).not_to include(
          "id=\"signup-#{other_signup.id}\""
        )
        expect(response.body).not_to include(
          other_volunteer.email_address
        )
        # 6. 不允许通过参数切换用户角色
        expect(response.body).not_to include(
          "Organization Dashboard"
        )
        expect(volunteer.reload.role).to eq("volunteer")
        expect(database_snapshot).to eq(original_snapshot)
      end

      # Test 26: Organizer Dashboard 组织伪造
      it "ignores forged organization identifiers in organizer dashboard requests" do
        # 1. 确保另一个组织的活动已经创建
        other_activity
        # 2. 登录当前组织的 Organizer
        sign_in_as(organizer)
        original_snapshot = database_snapshot
        # 3. 尝试通过 URL 参数访问其他组织的数据
        get dashboard_path, params: {
          organization_id: other_organization.id,
          user_id: other_organizer.id,
          role: "volunteer"
        }
        expect(response).to have_http_status(:ok)
        # 4. 仍然显示当前组织的 Dashboard
        expect(response.body).to include(
          "Organization Dashboard"
        )
        expect(response.body).to include(organization.name)
        expect(response.body).to include(
          "id=\"activity-#{activity.id}\""
        )
        # 5. 不泄露其他组织的数据
        expect(response.body).not_to include(
          other_organization.name
        )
        expect(response.body).not_to include(
          "id=\"activity-#{other_activity.id}\""
        )
        # 6. 用户角色及组织归属保持不变
        organizer.reload
        expect(organizer.role).to eq("organizer")
        expect(organizer.organization_id).to eq(organization.id)
        expect(database_snapshot).to eq(original_snapshot)
      end
    end

    # ==================================================
    # 报名参数伪造测试
    # ==================================================

    context "signup parameter tampering" do
      # Test 27: 报名时伪造用户、班次及报名状态
      it "ignores forged signup ownership and status attributes" do
        # 1. 创建不存在时间冲突的新班次
        target_shift = Shift.create!(
          activity: activity,
          start_time: shift.end_time + 2.hours,
          end_time: shift.end_time + 5.hours,
          capacity: 5
        )
        forged_user_id = other_volunteer.id
        # 2. 登录当前 Volunteer
        sign_in_as(volunteer)
        original_snapshot = database_snapshot
        original_signup_count = Signup.count
        # 3. 提交包含伪造字段的报名请求
        post activity_shift_signups_path(activity, target_shift),
             params: {
               user_id: forged_user_id,
               shift_id: shift.id,
               status: "cancelled",
               attendance_status: "present",
               signup: {
                 user_id: forged_user_id,
                 shift_id: shift.id,
                 status: "cancelled",
                 attendance_status: "present",
                 waitlisted_at: start_time.iso8601
               }
             }
        # 4. 合法报名正常完成
        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(
          activity_shift_path(activity, target_shift)
        )
        expect(Signup.count).to eq(original_signup_count + 1)
        # 5. 报名必须属于当前登录用户及路由指定的班次
        created_signup = Signup.find_by!(
          user: volunteer,
          shift: target_shift
        )
        expect(created_signup.user_id).to eq(volunteer.id)
        expect(created_signup.shift_id).to eq(target_shift.id)
        # 6. 报名状态由业务逻辑决定
        expect(created_signup.status).to eq("confirmed")
        expect(created_signup.attendance_status).to eq("pending")
        expect(created_signup.waitlisted_at).to be_nil
        # 7. 不允许为其他用户创建报名记录
        expect(
          Signup.where(user_id: forged_user_id)
        ).to be_empty
        # 8. 原有活动、班次及报名记录保持不变
        current_snapshot = database_snapshot
        expect(current_snapshot[:activities]).to eq(
          original_snapshot[:activities]
        )
        expect(current_snapshot[:shifts]).to eq(
          original_snapshot[:shifts]
        )
        expect(
          current_snapshot[:signups].reject do |attributes|
            attributes["id"] == created_signup.id
          end
        ).to eq(original_snapshot[:signups])
      end
    end
  end

  # ==================================================
  # 日期时间及表单边界测试
  # ==================================================

  describe "date time and form boundaries" do
    before do
      sign_in_as(organizer)
    end

    # ==================================================
    # 辅助方法
    # ==================================================

    # 获取合法的班次表单参数
    def valid_shift_attributes
      {
        start_time: (start_time + 2.days).iso8601,
        end_time: (start_time + 2.days + 3.hours).iso8601,
        capacity: "5"
      }
    end

    # 检查非法班次参数是否被拒绝
    def expect_invalid_shift_request(method, path, attributes)
      # 1. 保存请求前的数据库状态
      original_snapshot = database_snapshot
      # 2. 发送包含非法参数的请求
      public_send(method, path, params: {
        shift: attributes
      })
      # 3. 检查业务验证失败的 HTTP 状态码
      expect(response).to have_http_status(422)
      # 4. 检查数据库记录没有发生变化
      expect(database_snapshot).to eq(original_snapshot)
    end

    # ==================================================
    # 非法日期时间测试
    # ==================================================

    # Test 28: 创建班次时提交非法开始时间
    it "rejects invalid start time strings when creating a shift" do
      attributes = valid_shift_attributes.merge(
        start_time: "not-a-date"
      )
      expect_invalid_shift_request(
        :post,
        activity_shifts_path(activity),
        attributes
      )
    end

    # Test 29: 创建班次时提交非法结束时间
    it "rejects invalid end time strings when creating a shift" do
      attributes = valid_shift_attributes.merge(
        end_time: "not-a-date"
      )
      expect_invalid_shift_request(
        :post,
        activity_shifts_path(activity),
        attributes
      )
    end

    # Test 30: 修改班次时清空开始时间
    it "rejects blank start times when updating a shift" do
      expect_invalid_shift_request(
        :patch,
        activity_shift_path(activity, shift),
        {
          start_time: ""
        }
      )
    end

    # Test 31: 修改班次时清空结束时间
    it "rejects blank end times when updating a shift" do
      expect_invalid_shift_request(
        :patch,
        activity_shift_path(activity, shift),
        {
          end_time: ""
        }
      )
    end

    # ==================================================
    # 容量表单边界测试
    # ==================================================

    # Test 32: 创建班次时提交小数容量
    it "rejects fractional capacity values when creating a shift" do
      attributes = valid_shift_attributes.merge(
        capacity: "3.5"
      )
      expect_invalid_shift_request(
        :post,
        activity_shifts_path(activity),
        attributes
      )
    end

    # Test 33: 修改班次时提交小数容量
    it "rejects fractional capacity values when updating a shift" do
      expect_invalid_shift_request(
        :patch,
        activity_shift_path(activity, shift),
        {
          capacity: "5.5"
        }
      )
    end

    # ==================================================
    # 日期时间解析测试
    # ==================================================

    # Test 34: 正确解析带时区的日期时间
    it "correctly preserves timestamps submitted with a timezone offset" do
      # 1. 生成包含香港时区偏移量的时间
      expected_start = (start_time + 2.days)
        .in_time_zone("Hong Kong")
        .change(sec: 0, usec: 0)
      expected_end = expected_start + 3.hours
      original_shift_count = Shift.count
      original_snapshot = database_snapshot
      # 2. 提交包含 +08:00 时区偏移量的时间
      post activity_shifts_path(activity), params: {
        shift: {
          start_time: expected_start.iso8601,
          end_time: expected_end.iso8601,
          capacity: "5"
        }
      }
      # 3. 检查班次创建成功
      expect(response).to have_http_status(:see_other)
      expect(Shift.count).to eq(original_shift_count + 1)
      created_shift = activity.shifts.find_by!(
        start_time: expected_start
      )
      # 4. 检查保存的实际时间点
      expect(created_shift.start_time.utc).to eq(
        expected_start.utc
      )
      expect(created_shift.end_time.utc).to eq(
        expected_end.utc
      )
      expect(created_shift.capacity).to eq(5)
      # 5. 检查成功跳转
      expect(response).to redirect_to(
        activity_shift_path(activity, created_shift)
      )
      # 6. 检查页面显示的机器可读时间
      follow_redirect!
      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      datetime_values = document.css("time").map do |element|
        Time.iso8601(element["datetime"]).utc
      end
      expect(datetime_values).to include(
        expected_start.utc,
        expected_end.utc
      )
      # 7. 原有活动、班次及报名记录保持不变
      current_snapshot = database_snapshot
      expect(current_snapshot[:activities]).to eq(
        original_snapshot[:activities]
      )
      expect(current_snapshot[:signups]).to eq(
        original_snapshot[:signups]
      )
      expect(
        current_snapshot[:shifts].reject do |attributes|
          attributes["id"] == created_shift.id
        end
      ).to eq(original_snapshot[:shifts])
    end

    # Test 35: 正确解析浏览器提交的本地时间
    it "interprets datetime-local values using the application timezone" do
      # 1. 生成应用时区下的开始及结束时间
      expected_start = (start_time + 3.days)
        .in_time_zone
        .change(sec: 0, usec: 0)
      expected_end = expected_start + 3.hours
      original_signup = signup.attributes
      original_shift_count = Shift.count
      # 2. 模拟 datetime-local 输入框提交的数据
      patch activity_shift_path(activity, shift), params: {
        shift: {
          start_time: expected_start.strftime("%Y-%m-%dT%H:%M"),
          end_time: expected_end.strftime("%Y-%m-%dT%H:%M"),
          capacity: "5"
        }
      }
      # 3. 检查班次更新成功
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(
        activity_shift_path(activity, shift)
      )
      # 4. 检查日期时间被正确解析
      shift.reload
      expect(shift.start_time).to eq(expected_start)
      expect(shift.end_time).to eq(expected_end)
      expect(shift.capacity).to eq(5)
      # 5. 更新操作不能创建额外班次或修改报名记录
      expect(Shift.count).to eq(original_shift_count)
      expect(signup.reload.attributes).to eq(original_signup)
    end

    # ==================================================
    # HTML 表单边界测试
    # ==================================================

    # Test 36: 创建班次表单的输入框类型
    it "displays appropriate input types on the shift creation form" do
      # 1. 请求创建班次页面
      get new_activity_shift_path(activity)
      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      # 2. 获取班次表单
      form = document.at_css(
        "form[action='#{activity_shifts_path(activity)}']"
      )
      expect(form).not_to be_nil
      # 3. 获取三个表单输入框
      start_input = form.at_css(
        'input[name="shift[start_time]"]'
      )
      end_input = form.at_css(
        'input[name="shift[end_time]"]'
      )
      capacity_input = form.at_css(
        'input[name="shift[capacity]"]'
      )
      expect(start_input).not_to be_nil
      expect(end_input).not_to be_nil
      expect(capacity_input).not_to be_nil
      # 4. 检查 HTML 输入框类型
      expect(start_input["type"]).to eq("datetime-local")
      expect(end_input["type"]).to eq("datetime-local")
      expect(capacity_input["type"]).to eq("number")
    end

    # Test 37: 编辑班次表单的初始值
    it "displays persisted shift values on the shift editing form" do
      # 1. 将测试时间精确到分钟
      shift.update!(
        start_time: shift.start_time.change(sec: 0, usec: 0),
        end_time: shift.end_time.change(sec: 0, usec: 0)
      )
      original_snapshot = database_snapshot
      # 2. 请求编辑班次页面
      get edit_activity_shift_path(activity, shift)
      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      # 3. 获取班次编辑表单
      form = document.at_css(
        "form[action='#{activity_shift_path(activity, shift)}']"
      )
      expect(form).not_to be_nil
      # 4. 检查开始时间及结束时间输入框
      start_input = form.at_css(
        'input[name="shift[start_time]"]'
      )
      end_input = form.at_css(
        'input[name="shift[end_time]"]'
      )
      expect(start_input).not_to be_nil
      expect(end_input).not_to be_nil
      expect(start_input["type"]).to eq("datetime-local")
      expect(end_input["type"]).to eq("datetime-local")
      # 5. 检查表单时间与数据库时间一致
      expect(
        Time.zone.parse(start_input["value"])
      ).to eq(shift.start_time)
      expect(
        Time.zone.parse(end_input["value"])
      ).to eq(shift.end_time)
      # 6. 检查容量输入框的初始值
      capacity_input = form.at_css(
        'input[name="shift[capacity]"]'
      )
      expect(capacity_input).not_to be_nil
      expect(capacity_input["type"]).to eq("number")
      expect(capacity_input["value"]).to eq(
        shift.capacity.to_s
      )
      # 7. 查看编辑页面不能修改数据库
      expect(database_snapshot).to eq(original_snapshot)
    end
  end

end

