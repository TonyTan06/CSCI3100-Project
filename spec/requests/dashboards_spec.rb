
require 'rails_helper'
require 'nokogiri'

RSpec.describe "Dashboards", type: :request do
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

  let(:volunteer_a) { create_volunteer("a") }
  let(:volunteer_b) { create_volunteer("b") }
  let(:volunteer_c) { create_volunteer("c") }

  let(:organizer_a) do
    User.create!(
      email_address: "organizer_a@example.com",
      password: "password123",
      role: "organizer",
      organization: organization_a
    )
  end

  let(:organizer_b) do
    User.create!(
      email_address: "organizer_b@example.com",
      password: "password123",
      role: "organizer",
      organization: organization_b
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

  let(:activity_c) do
    Activity.create!(
      title: "Tree Planting",
      description: "Plant trees around campus",
      location: "University Campus",
      organization: organization_a
    )
  end

  let(:start_time) do
    Time.current.change(usec: 0) + 1.day
  end

  # 故意不按照班次开始时间创建数据
  let!(:shift_a) do
    Shift.create!(
      activity: activity_a,
      start_time: start_time + 1.day,
      end_time: start_time + 1.day + 3.hours,
      capacity: 3
    )
  end

  let!(:shift_b) do
    Shift.create!(
      activity: activity_b,
      start_time: start_time,
      end_time: start_time + 3.hours,
      capacity: 1
    )
  end

  let!(:shift_c) do
    Shift.create!(
      activity: activity_c,
      start_time: start_time + 2.days,
      end_time: start_time + 2.days + 3.hours,
      capacity: 5
    )
  end

  # ==================================================
  # 公共报名记录
  # ==================================================

  # Volunteer A：正式报名
  let!(:signup_a) do
    Signup.create!(
      user: volunteer_a,
      shift: shift_a,
      status: "confirmed",
      attendance_status: "present"
    )
  end

  # Volunteer B：占用 Shift B 的唯一正式名额
  let!(:signup_b) do
    Signup.create!(
      user: volunteer_b,
      shift: shift_b,
      status: "confirmed"
    )
  end

  # Volunteer A：候补报名
  let!(:signup_c) do
    Signup.create!(
      user: volunteer_a,
      shift: shift_b,
      status: "waitlisted"
    )
  end

  # Volunteer A：已取消报名
  let!(:signup_d) do
    Signup.create!(
      user: volunteer_a,
      shift: shift_c,
      status: "cancelled"
    )
  end

  # Volunteer B：其他正式报名
  let!(:signup_e) do
    Signup.create!(
      user: volunteer_b,
      shift: shift_c,
      status: "confirmed",
      attendance_status: "absent"
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

  # 获取指定报名记录对应的页面区域
  def signup_item(document, signup)
    document.at_css("#signup-#{signup.id}")
  end

  # 检查个人报名统计
  def expect_signup_summary(document, confirmed:, waitlisted:, cancelled:)
    summary = document.at_css("#signup-summary")
    expect(summary).not_to be_nil
    summary_text = summary.text.squish
    expect(summary_text).to include("Confirmed: #{confirmed}")
    expect(summary_text).to include("Waitlisted: #{waitlisted}")
    expect(summary_text).to include("Cancelled: #{cancelled}")
  end

  # ==================================================
  # Volunteer Dashboard 测试
  # ==================================================

  describe "volunteer dashboard" do
    # ==================================================
    # 未登录用户权限测试
    # ==================================================

    context "unauthenticated access" do
      # Test 1: 未登录用户不能查看 Dashboard
      it "redirects unauthenticated users when viewing the dashboard" do
        get "/dashboard"

        expect(response).to redirect_to(
          new_session_path
        )
      end
    end

    # ==================================================
    # Volunteer 个人 Dashboard 测试
    # ==================================================

    context "volunteer access" do
      before do
        sign_in_as(volunteer_a)
      end

      # Test 2: Volunteer 可以查看个人 Dashboard
      it "allows volunteers to view their personal dashboard" do
        get "/dashboard"

        expect(response).to have_http_status(:ok)
        page_text = Nokogiri::HTML(response.body).text.squish

        expect(page_text).to include("My Dashboard")
        expect(page_text).to include(volunteer_a.email_address)
        expect(page_text).to include("My Signups")
      end

      # Test 3: 显示个人报名及活动信息
      it "displays activity and shift information for personal signups" do
        get "/dashboard"

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)

        # 1. 检查个人报名列表
        expect(document.at_css("#my-signups")).not_to be_nil

        # 2. 检查每条报名记录对应的活动及班次信息
        [ signup_a, signup_c, signup_d ].each do |signup|
          item = signup_item(document, signup)
          expect(item).not_to be_nil
          item_text = item.text.squish
          shift = signup.shift
          activity = shift.activity

          expect(item_text).to include(activity.title)
          expect(item_text).to include(activity.organization.name)
          expect(item_text).to include(activity.location)
          expect(item_text).to include(
            shift.start_time.strftime("%Y-%m-%d %H:%M")
          )
          expect(item_text).to include(
            shift.end_time.strftime("%Y-%m-%d %H:%M")
          )

          # 3. 检查机器可读的时间信息
          datetime_values = item.css("time").map do |element|
            element["datetime"]
          end
          expect(datetime_values).to include(
            shift.start_time.iso8601,
            shift.end_time.iso8601
          )
        end
      end

      # Test 4: 显示跨组织的个人报名记录
      it "displays personal signups across different organizations" do
        get "/dashboard"

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)

        # 1. 显示 Organization A 的报名
        item_a = signup_item(document, signup_a)
        expect(item_a).not_to be_nil
        expect(item_a.text).to include(organization_a.name)

        # 2. 显示 Organization B 的报名
        item_c = signup_item(document, signup_c)
        expect(item_c).not_to be_nil
        expect(item_c.text).to include(organization_b.name)
      end

      # Test 5: 正确显示三种报名状态
      it "displays confirmed, waitlisted and cancelled signup statuses" do
        get "/dashboard"

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)

        [ signup_a, signup_c, signup_d ].each do |signup|
          item = signup_item(document, signup)
          expect(item).not_to be_nil
          expect(item.text.squish).to include(
            "Signup Status: #{signup.status.humanize}"
          )
        end
      end

      # Test 6: 仅正式报名显示出勤状态
      it "displays attendance status only for confirmed signups" do
        # 检查三种合法出勤状态
        [ "pending", "present", "absent" ].each do |status|
          signup_a.update!(attendance_status: status)

          get "/dashboard"

          expect(response).to have_http_status(:ok)
          document = Nokogiri::HTML(response.body)

          confirmed_item = signup_item(document, signup_a)
          waitlisted_item = signup_item(document, signup_c)
          cancelled_item = signup_item(document, signup_d)

          expect(confirmed_item).not_to be_nil
          expect(waitlisted_item).not_to be_nil
          expect(cancelled_item).not_to be_nil

          expect(confirmed_item.text.squish).to include(
            "Attendance Status: #{status.humanize}"
          )
          expect(waitlisted_item.text).not_to include(
            "Attendance Status:"
          )
          expect(cancelled_item.text).not_to include(
            "Attendance Status:"
          )
        end
      end

      # Test 7: 正确统计个人报名记录
      it "displays accurate personal signup statistics" do
        get "/dashboard"

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)

        expect_signup_summary(
          document,
          confirmed: 1,
          waitlisted: 1,
          cancelled: 1
        )
      end

      # Test 8: 不泄露其他 Volunteer 的信息
      it "does not expose signups belonging to other volunteers" do
        get "/dashboard"

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)

        # 1. 当前用户的报名记录应该显示
        [ signup_a, signup_c, signup_d ].each do |signup|
          expect(signup_item(document, signup)).not_to be_nil
        end

        # 2. 其他用户的报名记录不能显示
        expect(signup_item(document, signup_b)).to be_nil
        expect(signup_item(document, signup_e)).to be_nil

        # 3. 不泄露其他用户的电子邮箱
        expect(response.body).not_to include(
          volunteer_b.email_address
        )

        # 4. 不显示其他用户的出勤状态
        expect(document.text.squish).not_to include(
          "Attendance Status: Absent"
        )

        # 5. 不显示 Organizer 的出勤管理入口
        expect(document.text).not_to include(
          "Manage Attendance"
        )
      end

      # Test 9: 按班次开始时间排序
      it "orders personal signups by shift start time" do
        get "/dashboard"

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)

        # 获取个人报名列表中的所有 Signup ID
        signup_ids = document.css(
          '#my-signups [id^="signup-"]'
        ).map do |item|
          item["id"].delete_prefix("signup-").to_i
        end

        # Shift B 最早，Shift A 其次，Shift C 最晚
        expect(signup_ids).to eq(
          [ signup_c.id, signup_a.id, signup_d.id ]
        )
      end

      # Test 10: 正确显示班次及活动导航入口
      it "displays links to shift details and activity browsing" do
        get "/dashboard"

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)

        # 1. 每条报名记录均有班次详情入口
        [ signup_a, signup_c, signup_d ].each do |signup|
          item = signup_item(document, signup)
          expect(item).not_to be_nil
          shift_path = activity_shift_path(
            signup.shift.activity,
            signup.shift
          )
          shift_link = item.at_css(
            "a[href='#{shift_path}']"
          )
          expect(shift_link).not_to be_nil
          expect(shift_link.text.strip).to eq("View Shift")
        end

        # 2. 显示浏览活动入口
        activities_link = document.at_css(
          "a[href='#{activities_path}']"
        )
        expect(activities_link).not_to be_nil
        expect(activities_link.text.strip).to eq(
          "Browse Activities"
        )
      end
    end

    # ==================================================
    # 空报名列表测试
    # ==================================================

    context "volunteers without signups" do
      # Test 11: 未报名用户正确显示空列表及零统计
      it "displays an empty signup list and zero counts for unregistered volunteers" do
        # 1. 登录尚未报名的 Volunteer
        sign_in_as(volunteer_c)

        # 2. 请求个人 Dashboard
        get "/dashboard"

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)
        page_text = document.text.squish

        # 3. 检查空列表提示
        expect(page_text).to include(
          "You have no signups yet."
        )

        # 4. 所有个人报名统计均为零
        expect_signup_summary(
          document,
          confirmed: 0,
          waitlisted: 0,
          cancelled: 0
        )

        # 5. 不显示其他 Volunteer 的报名记录
        expect(
          document.css('#my-signups [id^="signup-"]')
        ).to be_empty
        expect(response.body).not_to include(
          volunteer_a.email_address
        )
        expect(response.body).not_to include(
          volunteer_b.email_address
        )
      end
    end
  end

  # ==================================================
  # Organizer Dashboard 测试
  # ==================================================

  describe "organizer dashboard" do
    # 获取指定活动对应的页面区域
    def activity_item(document, activity)
      document.at_css("#activity-#{activity.id}")
    end

    # 获取指定班次对应的页面区域
    def shift_item(document, shift)
      document.at_css("#shift-#{shift.id}")
    end

    # 检查组织整体统计
    def expect_organization_summary(document, activities:, shifts:, confirmed:, waitlisted:, cancelled:)
      summary = document.at_css("#organization-summary")
      expect(summary).not_to be_nil
      summary_text = summary.text.squish
      expect(summary_text).to include("Activities: #{activities}")
      expect(summary_text).to include("Shifts: #{shifts}")
      expect(summary_text).to include("Confirmed Signups: #{confirmed}")
      expect(summary_text).to include("Waitlisted Signups: #{waitlisted}")
      expect(summary_text).to include("Cancelled Signups: #{cancelled}")
    end

    # 检查页面中的导航链接
    def expect_dashboard_link(document, label, path)
      link = document.at_css("a[href='#{path}']")
      expect(link).not_to be_nil
      expect(link.text.strip).to eq(label)
    end

    # ==================================================
    # Organizer 组织 Dashboard 测试
    # ==================================================

    context "organizer access" do
      before do
        sign_in_as(organizer_a)
      end

      # Test 12: Organizer 可以查看组织 Dashboard
      it "allows organizers to view their organization dashboard" do
        get "/dashboard"

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)
        page_text = document.text.squish

        expect(page_text).to include("Organization Dashboard")
        expect(page_text).to include(organization_a.name)
        expect(page_text).to include(organizer_a.email_address)
        expect(page_text).to include("My Activities")

        # 不应显示 Volunteer 专属页面
        expect(document.at_css("#my-signups")).to be_nil
        expect(document.at_css("#signup-summary")).to be_nil
      end

      # Test 13: 正确显示组织的整体统计
      it "displays accurate organization statistics" do
        get "/dashboard"

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)

        # Organization A 拥有两个活动及两个班次
        # 正式报名两条，候补零条，已取消一条
        expect_organization_summary(
          document,
          activities: 2,
          shifts: 2,
          confirmed: 2,
          waitlisted: 0,
          cancelled: 1
        )
      end

      # Test 14: 显示组织所属活动及班次信息
      it "displays activities and their associated shifts" do
        get "/dashboard"

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)

        # 1. 检查活动列表区域
        expect(document.at_css("#my-activities")).not_to be_nil

        # 2. 检查当前组织的两个活动
        [ activity_a, activity_c ].each do |activity|
          item = activity_item(document, activity)
          expect(item).not_to be_nil
          item_text = item.text.squish

          expect(item_text).to include(activity.title)
          expect(item_text).to include(activity.location)
        end

        # 3. 检查每个班次的信息及所属活动
        [ shift_a, shift_c ].each do |shift|
          item = shift_item(document, shift)
          expect(item).not_to be_nil
          item_text = item.text.squish

          expect(item_text).to include(
            "Shift ##{shift.id}"
          )
          expect(item_text).to include(
            shift.start_time.strftime("%Y-%m-%d %H:%M")
          )
          expect(item_text).to include(
            shift.end_time.strftime("%Y-%m-%d %H:%M")
          )

          # 4. 检查机器可读的时间信息
          datetime_values = item.css("time").map do |element|
            element["datetime"]
          end
          expect(datetime_values).to include(
            shift.start_time.iso8601,
            shift.end_time.iso8601
          )

          # 5. 班次必须位于所属活动的页面区域内
          parent_activity = activity_item(
            document,
            shift.activity
          )
          expect(
            parent_activity.at_css("#shift-#{shift.id}")
          ).not_to be_nil
        end
      end

      # Test 15: 正确显示班次容量、候补及出勤统计
      it "displays accurate signup and attendance statistics for each shift" do
        # 1. 降低 Shift A 的容量，使班次满员
        shift_a.update!(capacity: 1)

        # 2. 添加一位候补用户
        Signup.create!(
          user: volunteer_c,
          shift: shift_a,
          status: "waitlisted"
        )

        # 3. 请求组织 Dashboard
        get "/dashboard"

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)

        # 4. 检查 Shift A 的报名统计
        item_a = shift_item(document, shift_a)
        expect(item_a).not_to be_nil
        text_a = item_a.text.squish

        expect(text_a).to include("Capacity: 1")
        expect(text_a).to include("Confirmed Signups: 1")
        expect(text_a).to include("Available Slots: 0")
        expect(text_a).to include("Waitlisted Signups: 1")

        # 5. Shift A 的正式报名人员已出席
        expect(text_a).to include("Present: 1")
        expect(text_a).to include("Absent: 0")
        expect(text_a).to include("Pending: 0")

        # 6. 检查 Shift C 的报名统计
        item_c = shift_item(document, shift_c)
        expect(item_c).not_to be_nil
        text_c = item_c.text.squish

        expect(text_c).to include("Capacity: 5")
        expect(text_c).to include("Confirmed Signups: 1")
        expect(text_c).to include("Available Slots: 4")
        expect(text_c).to include("Waitlisted Signups: 0")

        # 7. Shift C 的正式报名人员未出席
        # 已取消的报名记录不应计入出勤统计
        expect(text_c).to include("Present: 0")
        expect(text_c).to include("Absent: 1")
        expect(text_c).to include("Pending: 0")

        # 8. 检查组织的整体统计
        expect_organization_summary(
          document,
          activities: 2,
          shifts: 2,
          confirmed: 2,
          waitlisted: 1,
          cancelled: 1
        )
      end

      # Test 16: 班次按照开始时间排序
      it "orders shifts within each activity by start time" do
        # 1. 创建开始时间早于现有班次的 Shift
        earlier_shift = Shift.create!(
          activity: activity_a,
          start_time: shift_a.start_time - 5.hours,
          end_time: shift_a.start_time - 2.hours,
          capacity: 5
        )

        # 2. 创建开始时间晚于现有班次的 Shift
        later_shift = Shift.create!(
          activity: activity_a,
          start_time: shift_a.end_time + 2.hours,
          end_time: shift_a.end_time + 5.hours,
          capacity: 5
        )

        # 3. 请求组织 Dashboard
        get "/dashboard"

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)

        # 4. 获取 Activity A 的班次显示顺序
        item = activity_item(document, activity_a)
        expect(item).not_to be_nil

        shift_ids = item.css('[id^="shift-"]').map do |element|
          element["id"].delete_prefix("shift-").to_i
        end

        # 5. 按开始时间排序，而不是按照创建顺序排序
        expect(shift_ids).to eq(
          [ earlier_shift.id, shift_a.id, later_shift.id ]
        )
      end

      # Test 17: 正确显示活动、班次及出勤管理入口
      it "displays management links for activities, shifts and attendance" do
        get "/dashboard"

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)

        # 1. 创建活动及活动列表入口
        expect_dashboard_link(
          document,
          "New Activity",
          new_activity_path
        )
        expect_dashboard_link(
          document,
          "View All Activities",
          activities_path
        )

        # 2. 每个活动的管理入口
        [ activity_a, activity_c ].each do |activity|
          item = activity_item(document, activity)
          expect(item).not_to be_nil

          expect_dashboard_link(
            item,
            "View Activity",
            activity_path(activity)
          )
          expect_dashboard_link(
            item,
            "Edit Activity",
            edit_activity_path(activity)
          )
          expect_dashboard_link(
            item,
            "New Shift",
            new_activity_shift_path(activity)
          )
        end

        # 3. 每个班次的管理入口
        [ shift_a, shift_c ].each do |shift|
          item = shift_item(document, shift)
          expect(item).not_to be_nil
          activity = shift.activity

          expect_dashboard_link(
            item,
            "View Shift",
            activity_shift_path(activity, shift)
          )
          expect_dashboard_link(
            item,
            "Edit Shift",
            edit_activity_shift_path(activity, shift)
          )
          expect_dashboard_link(
            item,
            "Manage Attendance",
            activity_shift_attendances_path(activity, shift)
          )
        end
      end

      # ==================================================
      # 组织隔离测试
      # ==================================================

      # Test 18: 不泄露其他组织的数据
      it "does not expose activities or shifts belonging to other organizations" do
        get "/dashboard"

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)
        page_text = document.text.squish

        # 1. 当前组织的活动及班次正常显示
        expect(activity_item(document, activity_a)).not_to be_nil
        expect(activity_item(document, activity_c)).not_to be_nil
        expect(shift_item(document, shift_a)).not_to be_nil
        expect(shift_item(document, shift_c)).not_to be_nil

        # 2. 不显示其他组织的活动及班次
        expect(activity_item(document, activity_b)).to be_nil
        expect(shift_item(document, shift_b)).to be_nil
        expect(page_text).not_to include(organization_b.name)
        expect(page_text).not_to include(activity_b.title)

        # 3. 不暴露其他组织的管理入口
        expect(
          document.at_css(
            "a[href='#{edit_activity_path(activity_b)}']"
          )
        ).to be_nil
        expect(
          document.at_css(
            "a[href='#{edit_activity_shift_path(activity_b, shift_b)}']"
          )
        ).to be_nil
        expect(
          document.at_css(
            "a[href='#{activity_shift_attendances_path(activity_b, shift_b)}']"
          )
        ).to be_nil

        # 4. Dashboard 只显示统计信息，不显示 Volunteer 个人邮箱
        expect(response.body).not_to include(volunteer_a.email_address)
        expect(response.body).not_to include(volunteer_b.email_address)
      end

      # Test 21: 没有班次的活动仍然正常显示
      it "displays activities without shifts" do
        # 1. 创建尚未设置班次的活动
        empty_activity = Activity.create!(
          title: "Food Distribution",
          description: "Food distribution volunteer activity",
          location: "Sha Tin",
          organization: organization_a
        )

        # 2. 请求组织 Dashboard
        get "/dashboard"

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)

        # 3. 没有班次的活动仍然需要显示
        item = activity_item(document, empty_activity)
        expect(item).not_to be_nil
        expect(item.text.squish).to include(empty_activity.title)
        expect(item.text.squish).to include("No shifts yet.")

        # 4. 不显示不存在的班次
        expect(item.css('[id^="shift-"]')).to be_empty

        # 5. Organizer 可以直接创建班次
        expect_dashboard_link(
          item,
          "New Shift",
          new_activity_shift_path(empty_activity)
        )

        # 6. 活动数量增加，但班次及报名统计保持不变
        expect_organization_summary(
          document,
          activities: 3,
          shifts: 2,
          confirmed: 2,
          waitlisted: 0,
          cancelled: 1
        )
      end
    end

    # ==================================================
    # 其他组织 Organizer 测试
    # ==================================================

    context "another organization" do
      # Test 19: 不同 Organizer 只能查看自己的组织
      it "displays only the organization belonging to the current organizer" do
        # 1. 登录 Organization B 的 Organizer
        sign_in_as(organizer_b)

        # 2. 请求组织 Dashboard
        get "/dashboard"

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)
        page_text = document.text.squish

        # 3. 显示当前组织的信息
        expect(page_text).to include(organization_b.name)
        expect(page_text).to include(organizer_b.email_address)
        expect(activity_item(document, activity_b)).not_to be_nil
        expect(shift_item(document, shift_b)).not_to be_nil

        # 4. 不显示 Organization A 的信息
        expect(page_text).not_to include(organization_a.name)
        expect(activity_item(document, activity_a)).to be_nil
        expect(activity_item(document, activity_c)).to be_nil
        expect(shift_item(document, shift_a)).to be_nil
        expect(shift_item(document, shift_c)).to be_nil

        # 5. 检查 Organization B 的整体统计
        expect_organization_summary(
          document,
          activities: 1,
          shifts: 1,
          confirmed: 1,
          waitlisted: 1,
          cancelled: 0
        )
      end
    end

    # ==================================================
    # 空组织 Dashboard 测试
    # ==================================================

    context "organization without activities" do
      # Test 20: 没有活动的组织显示空列表及零统计
      it "displays an empty dashboard for organizations without activities" do
        # 1. 创建尚未发布任何活动的组织
        empty_organization = Organization.create!(
          name: "New Volunteer Organization"
        )

        empty_organizer = User.create!(
          email_address: "empty_organizer@example.com",
          password: "password123",
          role: "organizer",
          organization: empty_organization
        )

        # 2. 登录新组织的 Organizer
        sign_in_as(empty_organizer)

        # 3. 请求组织 Dashboard
        get "/dashboard"

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)
        page_text = document.text.squish

        # 4. 显示正确的组织信息及空列表提示
        expect(page_text).to include(empty_organization.name)
        expect(page_text).to include("No activities yet.")

        # 5. 所有统计数据均为零
        expect_organization_summary(
          document,
          activities: 0,
          shifts: 0,
          confirmed: 0,
          waitlisted: 0,
          cancelled: 0
        )

        # 6. 不显示其他组织的任何活动或班次
        expect(document.css('[id^="activity-"]')).to be_empty
        expect(document.css('[id^="shift-"]')).to be_empty

        # 7. 保留创建活动入口
        expect_dashboard_link(
          document,
          "New Activity",
          new_activity_path
        )
      end
    end
  end

  # ==================================================
  # 首页、登录跳转及全局导航测试
  # ==================================================

  describe "dashboard navigation" do
    # 获取全局导航栏
    def main_navigation
      document = Nokogiri::HTML(response.body)
      navigation = document.at_css("#main-navigation")
      expect(navigation).not_to be_nil
      navigation
    end

    # 检查指定导航链接
    def expect_navigation_link(navigation, label, path)
      link = navigation.at_css("a[href='#{path}']")
      expect(link).not_to be_nil
      expect(link.text.strip).to eq(label)
    end

    # 检查已登录用户的全局导航栏
    def expect_authenticated_navigation(activity_label)
      navigation = main_navigation
      # 1. 检查 Dashboard 及活动列表入口
      expect_navigation_link(
        navigation,
        "Dashboard",
        dashboard_path
      )
      expect_navigation_link(
        navigation,
        activity_label,
        activities_path
      )
      # 2. 已登录用户不应看到登录及注册入口
      expect(
        navigation.at_css("a[href='#{new_session_path}']")
      ).to be_nil
      expect(
        navigation.at_css("a[href='#{new_registration_path}']")
      ).to be_nil
      # 3. 检查退出登录表单
      sign_out_form = navigation.at_css(
        "form[action='#{session_path}']"
      )
      expect(sign_out_form).not_to be_nil
      expect(sign_out_form["method"]).to eq("post")
      expect(sign_out_form.at_css("button").text.strip).to eq(
        "Sign Out"
      )
      # 4. 检查退出登录请求方式
      method_input = sign_out_form.at_css(
        'input[name="_method"]'
      )
      expect(method_input).not_to be_nil
      expect(method_input["value"]).to eq("delete")
    end

    # ==================================================
    # 首页访问测试
    # ==================================================

    context "home page access" do
      # Test 22: 未登录访问首页时跳转登录
      it "redirects unauthenticated visitors from the home page to sign in" do
        get root_path
        expect(response).to redirect_to(
          new_session_path
        )
      end

      # Test 23: Volunteer 首页显示个人 Dashboard
      it "displays the volunteer dashboard on the home page" do
        sign_in_as(volunteer_a)
        get root_path
        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)
        # 检查 Volunteer Dashboard
        expect(document.text.squish).to include(
          "My Dashboard"
        )
        expect(document.at_css("#my-signups")).not_to be_nil
        expect(document.at_css("#signup-summary")).not_to be_nil
        # 不显示 Organizer Dashboard
        expect(
          document.at_css("#organization-summary")
        ).to be_nil
      end

      # Test 24: Organizer 首页显示组织 Dashboard
      it "displays the organization dashboard on the home page" do
        sign_in_as(organizer_a)
        get root_path
        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)
        # 检查 Organizer Dashboard
        expect(document.text.squish).to include(
          "Organization Dashboard"
        )
        expect(document.text).to include(
          organization_a.name
        )
        expect(
          document.at_css("#organization-summary")
        ).not_to be_nil
        expect(
          document.at_css("#my-activities")
        ).not_to be_nil
        # 不显示 Volunteer Dashboard
        expect(document.at_css("#my-signups")).to be_nil
      end
    end

    # ==================================================
    # 登录后跳转测试
    # ==================================================

    context "post-login redirection" do
      # Test 25: Volunteer 登录成功后进入个人 Dashboard
      it "redirects volunteers to their dashboard after signing in" do
        # 1. 登录 Volunteer
        sign_in_as(volunteer_a)
        expect(response).to redirect_to(root_path)
        # 2. 跟随登录成功后的跳转
        follow_redirect!
        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)
        # 3. 显示个人 Dashboard
        expect(document.text.squish).to include(
          "My Dashboard"
        )
        expect(document.at_css("#my-signups")).not_to be_nil
      end

      # Test 26: Organizer 登录成功后进入组织 Dashboard
      it "redirects organizers to their organization dashboard after signing in" do
        # 1. 登录 Organizer
        sign_in_as(organizer_a)
        expect(response).to redirect_to(root_path)
        # 2. 跟随登录成功后的跳转
        follow_redirect!
        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)
        # 3. 显示所属组织 Dashboard
        expect(document.text.squish).to include(
          "Organization Dashboard"
        )
        expect(document.text).to include(
          organization_a.name
        )
        expect(
          document.at_css("#organization-summary")
        ).not_to be_nil
      end

      # Test 27: 登录后返回原本请求的页面
      it "returns users to the originally requested page after signing in" do
        # 1. 未登录时尝试访问班次详情
        requested_path = activity_shift_path(
          activity_a,
          shift_a
        )
        get requested_path
        expect(response).to redirect_to(
          new_session_path
        )
        # 2. 登录 Volunteer
        sign_in_as(volunteer_a)
        # 3. 登录后应返回原本请求的班次
        expect(response).to redirect_to(
          requested_path
        )
        follow_redirect!
        expect(response).to have_http_status(:ok)
        page_text = Nokogiri::HTML(response.body).text.squish
        # 4. 检查班次详情及个人报名状态
        expect(page_text).to include(activity_a.title)
        expect(page_text).to include(
          "Signup Status: Confirmed"
        )
        expect(page_text).not_to include(
          "My Dashboard"
        )
      end
    end

    # ==================================================
    # 全局导航栏测试
    # ==================================================

    context "global navigation" do
      # Test 28: 未登录用户显示登录及注册导航
      it "displays sign-in and registration links for unauthenticated users" do
        [ new_session_path, new_registration_path ].each do |path|
          # 1. 请求登录或注册页面
          get path
          expect(response).to have_http_status(:ok)
          navigation = main_navigation
          # 2. 显示登录及注册入口
          expect_navigation_link(
            navigation,
            "Sign In",
            new_session_path
          )
          expect_navigation_link(
            navigation,
            "Sign Up",
            new_registration_path
          )
          # 3. 不显示已登录用户的功能入口
          expect(
            navigation.at_css("a[href='#{dashboard_path}']")
          ).to be_nil
          expect(
            navigation.at_css("a[href='#{activities_path}']")
          ).to be_nil
          expect(
            navigation.at_css("form[action='#{session_path}']")
          ).to be_nil
        end
      end

      # Test 29: Volunteer 全局导航正确显示
      it "displays consistent navigation across volunteer pages" do
        sign_in_as(volunteer_a)
        # 1. 获取 Volunteer 可以访问的页面
        paths = [
          root_path,
          dashboard_path,
          activities_path,
          activity_path(activity_a),
          activity_shifts_path(activity_a),
          activity_shift_path(activity_a, shift_a)
        ]
        # 2. 检查所有页面均具有相同导航
        paths.each do |path|
          get path
          expect(response).to have_http_status(:ok)
          expect_authenticated_navigation(
            "Browse Activities"
          )
          # 3. 不显示 Organizer 创建活动入口
          navigation = main_navigation
          expect(
            navigation.at_css("a[href='#{new_activity_path}']")
          ).to be_nil
        end
      end

      # Test 30: Organizer 全局导航正确显示
      it "displays consistent navigation across organizer pages" do
        sign_in_as(organizer_a)
        # 1. 获取 Organizer 可以访问的页面
        paths = [
          root_path,
          dashboard_path,
          activities_path,
          activity_path(activity_a),
          new_activity_path,
          edit_activity_path(activity_a),
          activity_shifts_path(activity_a),
          activity_shift_path(activity_a, shift_a),
          new_activity_shift_path(activity_a),
          edit_activity_shift_path(activity_a, shift_a),
          activity_shift_attendances_path(activity_a, shift_a)
        ]
        # 2. 检查所有页面均具有相同导航
        paths.each do |path|
          get path
          expect(response).to have_http_status(:ok)
          expect_authenticated_navigation(
            "View All Activities"
          )
        end
      end
    end

    # ==================================================
    # 退出登录测试
    # ==================================================

    context "signing out" do
      # Test 31: 退出登录后无法继续访问 Dashboard
      it "prevents access to protected pages after signing out" do
        # 1. 登录 Volunteer
        sign_in_as(volunteer_a)
        # 2. 确认登录后能够访问 Dashboard
        get dashboard_path
        expect(response).to have_http_status(:ok)
        # 3. 发送退出登录请求
        delete session_path
        expect(response).to redirect_to(
          new_session_path
        )
        expect(response).to have_http_status(:see_other)
        # 4. 检查退出后无法再访问受保护页面
        paths = [
          root_path,
          dashboard_path,
          activities_path,
          activity_shift_path(activity_a, shift_a)
        ]
        paths.each do |path|
          get path
          expect(response).to redirect_to(
            new_session_path
          )
        end
      end
    end
  end
end
