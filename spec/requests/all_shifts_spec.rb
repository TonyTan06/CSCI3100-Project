require "rails_helper"
require "nokogiri"

RSpec.describe "All shifts", type: :request do
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

  let(:organizer_b) do
    User.create!(
      email_address: "organizer_b@example.com",
      password: "password123",
      role: "organizer",
      organization: organization_b
    )
  end

  let(:volunteer) do
    User.create!(
      email_address: "volunteer@example.com",
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

  let(:shift_a1) do
    Shift.create!(
      activity: activity_a,
      start_time: start_time,
      end_time: start_time + 3.hours,
      capacity: 1
    )
  end

  let(:shift_a2) do
    Shift.create!(
      activity: activity_a,
      start_time: start_time + 4.hours,
      end_time: start_time + 7.hours,
      capacity: 15
    )
  end

  let(:shift_b) do
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

  # 解析页面 HTML
  def document
    Nokogiri::HTML(response.body)
  end

  # 获取总列表中的班次 ID
  def displayed_shift_ids
    document.css("#shifts-list article.shift-list-card").map do |card|
      card["id"]
    end
  end

  # ==================================================
  # 未登录用户权限测试
  # ==================================================

  describe "unauthenticated access" do
    # Test 1: 未登录用户不能访问班次总列表
    it "redirects unauthenticated users to the login page" do
      get shifts_path

      expect(response).to redirect_to(
        new_session_path
      )
    end
  end

  # ==================================================
  # 班次总列表测试
  # ==================================================

  describe "shift listing" do
    before do
      # 故意不按照开始时间顺序创建班次
      shift_a2
      shift_a1
      shift_b
    end

    # ==================================================
    # Volunteer 访问测试
    # ==================================================

    context "volunteer access" do
      before do
        sign_in_as(volunteer)
      end

      # Test 2: Volunteer 可以查看所有组织的班次
      it "displays shifts from all organizations" do
        get shifts_path

        expect(response).to have_http_status(:ok)

        expect(displayed_shift_ids).to contain_exactly(
          "shift-#{shift_a1.id}",
          "shift-#{shift_a2.id}",
          "shift-#{shift_b.id}"
        )
      end

      # Test 3: 班次按照开始时间及 ID 升序排列
      it "orders shifts by start time and ID" do
        get shifts_path

        expect(displayed_shift_ids).to eq(
          [
            "shift-#{shift_a1.id}",
            "shift-#{shift_b.id}",
            "shift-#{shift_a2.id}"
          ]
        )
      end

      # Test 4: 正确显示班次所属活动及组织信息
      it "displays activity, organization, location and shift times" do
        get shifts_path

        card = document.at_css(
          "#shift-#{shift_a1.id}"
        )

        expect(card).not_to be_nil

        expect(card.text).to include(
          activity_a.title,
          organization_a.name,
          activity_a.location
        )

        time_values = card.css("time").map do |element|
          element["datetime"]
        end

        expect(time_values).to include(
          shift_a1.start_time.iso8601,
          shift_a1.end_time.iso8601
        )
      end

      # Test 5: 正确显示容量、报名及候补统计
      it "displays accurate capacity and signup statistics" do
        Signup.create!(
          user: volunteer,
          shift: shift_a1,
          status: "confirmed",
          attendance_status: "pending"
        )

        Signup.create!(
          user: volunteer_b,
          shift: shift_a1,
          status: "waitlisted",
          attendance_status: "pending"
        )

        get shifts_path

        card = document.at_css(
          "#shift-#{shift_a1.id}"
        )

        expect(card.text).to include(
          "Capacity: 1"
        )

        expect(
          card.at_css(".shift-list-stat-value.text-success").text.strip
        ).to eq("1")

        expect(
          card.at_css(".shift-list-stat-value.text-primary").text.strip
        ).to eq("0")

        expect(
          card.at_css(".shift-list-stat-value.text-warning").text.strip
        ).to eq("1")

        expect(
          card.at_css(".status-badge").text.strip
        ).to eq("Full")

        expect(
          card.at_css('[role="progressbar"]')["aria-valuenow"]
        ).to eq("100")

        available_card = document.at_css(
          "#shift-#{shift_a2.id}"
        )

        expect(
          available_card.at_css(".status-badge").text.strip
        ).to eq("Available")
      end

      # Test 6: 班次和活动详情链接指向正确资源
      it "provides correct activity and shift detail links" do
        get shifts_path

        [ shift_a1, shift_a2, shift_b ].each do |shift|
          card = document.at_css(
            "#shift-#{shift.id}"
          )

          links = card.css("a").map do |link|
            link["href"]
          end

          expect(links).to include(
            activity_path(shift.activity),
            activity_shift_path(shift.activity, shift)
          )
        end
      end
    end

    # ==================================================
    # Organizer 访问及组织隔离测试
    # ==================================================

    context "organizer access" do
      # Test 7: Organizer A 只能查看组织 A 的班次
      it "restricts organizer A to shifts in organization A" do
        sign_in_as(organizer_a)

        get shifts_path

        expect(response).to have_http_status(:ok)

        expect(displayed_shift_ids).to contain_exactly(
          "shift-#{shift_a1.id}",
          "shift-#{shift_a2.id}"
        )

        expect(response.body).not_to include(
          activity_b.title
        )
      end

      # Test 8: Organizer B 只能查看组织 B 的班次
      it "restricts organizer B to shifts in organization B" do
        sign_in_as(organizer_b)

        get shifts_path

        expect(response).to have_http_status(:ok)

        expect(displayed_shift_ids).to eq(
          [ "shift-#{shift_b.id}" ]
        )

        expect(response.body).not_to include(
          activity_a.title
        )
      end

      # Test 9: 禁止通过 URL 参数绕过组织隔离
      it "prevents organizers from bypassing organization isolation through query parameters" do
        sign_in_as(organizer_a)

        get shifts_path, params: {
          organization_id: organization_b.id,
          activity_id: activity_b.id
        }

        expect(response).to have_http_status(:ok)

        expect(displayed_shift_ids).to contain_exactly(
          "shift-#{shift_a1.id}",
          "shift-#{shift_a2.id}"
        )

        expect(displayed_shift_ids).not_to include(
          "shift-#{shift_b.id}"
        )
      end
    end
  end

  # ==================================================
  # 空列表测试
  # ==================================================

  describe "empty shift list" do
    # Test 10: 系统没有班次时正确显示空列表
    it "displays an empty state when no shifts exist" do
      sign_in_as(volunteer)

      get shifts_path

      expect(response).to have_http_status(:ok)

      expect(displayed_shift_ids).to be_empty

      expect(response.body).to include(
        "No shifts available.",
        "No volunteer shifts have been scheduled yet."
      )
    end

    # Test 11: Organizer 所属组织没有班次时显示空列表
    it "displays an empty state when an organizer has no accessible shifts" do
      # 其他组织存在班次
      shift_b

      sign_in_as(organizer_a)

      get shifts_path

      expect(response).to have_http_status(:ok)

      expect(displayed_shift_ids).to be_empty

      expect(response.body).to include(
        "No shifts have been scheduled for your organization yet."
      )

      expect(response.body).not_to include(
        activity_b.title
      )
    end
  end

  # ==================================================
  # Dashboard 及导航栏入口测试
  # ==================================================

  describe "navigation" do
    # Test 12: 没有报名记录的 Volunteer 可以浏览班次
    it "provides a browse shifts link for volunteers without signups" do
      sign_in_as(volunteer)

      get dashboard_path

      expect(response).to have_http_status(:ok)

      link = document.at_css(
        ".dashboard-actions a[href='#{shifts_path}']"
      )

      expect(link).not_to be_nil
      expect(link.text.strip).to eq("Browse Shifts")
    end

    # Test 13: 已有报名记录的 Volunteer 可以浏览班次
    it "provides a browse shifts link for volunteers with signups" do
      Signup.create!(
        user: volunteer,
        shift: shift_a1,
        status: "confirmed",
        attendance_status: "pending"
      )

      sign_in_as(volunteer)

      get dashboard_path

      expect(response).to have_http_status(:ok)

      link = document.at_css(
        ".dashboard-actions a[href='#{shifts_path}']"
      )

      expect(link).not_to be_nil
      expect(link.text.strip).to eq("Browse Shifts")

      # 原有 Browse Activities 按钮仍然存在
      expect(
        document.at_css(
          ".dashboard-actions a[href='#{activities_path}']"
        )
      ).not_to be_nil
    end

    # Test 14: Organizer Dashboard 提供班次总列表入口
    it "provides a view all shifts link on the organizer dashboard" do
      sign_in_as(organizer_a)

      get dashboard_path

      expect(response).to have_http_status(:ok)

      link = document.at_css(
        ".organization-actions a[href='#{shifts_path}']"
      )

      expect(link).not_to be_nil
      expect(link.text.strip).to eq("View All Shifts")
    end

    # Test 15: 侧边导航栏正确显示并高亮 Shift 入口
    it "highlights the shifts navigation link instead of activities" do
      sign_in_as(volunteer)

      get shifts_path

      expect(response).to have_http_status(:ok)

      shifts_link = document.at_css(
        "#main-navigation a[href='#{shifts_path}']"
      )

      activities_link = document.at_css(
        "#main-navigation a[href='#{activities_path}']"
      )

      expect(shifts_link).not_to be_nil
      expect(activities_link).not_to be_nil

      expect(shifts_link.text.strip).to eq("Browse Shifts")

      expect(shifts_link["class"].split).to include(
        "active"
      )

      expect(activities_link["class"].split).not_to include(
        "active"
      )
    end
  end
end
