
require 'rails_helper'
require 'nokogiri'

RSpec.describe "Shifts", type: :request do
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

  # 设置班次开始时间
  let(:start_time) do
    Time.current.change(usec: 0) + 1.day
  end

  # 创建 Activity A 的第一个班次
  let!(:shift_a1) do
    Shift.create!(
      activity: activity_a,
      start_time: start_time,
      end_time: start_time + 3.hours,
      capacity: 10
    )
  end

  # 创建 Activity A 的第二个班次
  let!(:shift_a2) do
    Shift.create!(
      activity: activity_a,
      start_time: start_time + 4.hours,
      end_time: start_time + 7.hours,
      capacity: 15
    )
  end

  # 创建 Activity B 的班次
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
  # 未登录用户访问测试
  # ==================================================

  describe "unauthenticated access" do
    # Test 1: 未登录用户不能查看班次列表
    it "redirects unauthenticated users when viewing shifts" do
      get "/activities/#{activity_a.id}/shifts"

      expect(response).to redirect_to(
        new_session_path
      )
    end

    # Test 2: 未登录用户不能查看班次详情
    it "redirects unauthenticated users when viewing a shift" do
      get "/activities/#{activity_a.id}/shifts/#{shift_a1.id}"

      expect(response).to redirect_to(
        new_session_path
      )
    end
  end

  # ==================================================
  # Volunteer 访问权限测试
  # ==================================================

  describe "volunteer access" do
    before do
      sign_in_as(volunteer)
    end

    # Test 3: Volunteer 可以查看指定活动的班次列表
    it "displays only shifts belonging to the requested activity" do
      # 1. 请求 Activity A 的班次列表
      get "/activities/#{activity_a.id}/shifts"

      expect(response).to have_http_status(:ok)

      # 2. 解析返回的 HTML
      document = Nokogiri::HTML(response.body)

      links = document.css("a").map do |link|
        link["href"]
      end

      # 3. 应显示 Activity A 的两个班次
      expect(links).to include(
        "/activities/#{activity_a.id}/shifts/#{shift_a1.id}"
      )

      expect(links).to include(
        "/activities/#{activity_a.id}/shifts/#{shift_a2.id}"
      )

      # 4. 不应显示 Activity B 的班次
      expect(links).not_to include(
        "/activities/#{activity_b.id}/shifts/#{shift_b.id}"
      )

      expect(links).not_to include(
        "/activities/#{activity_a.id}/shifts/#{shift_b.id}"
      )
    end

    # Test 4: Volunteer 可以查看不同组织的班次详情
    it "allows volunteers to view shifts across organizations" do
      # 1. 查看 Organization A 的班次
      get "/activities/#{activity_a.id}/shifts/#{shift_a1.id}"

      expect(response).to have_http_status(:ok)

      expect(response.body).to include(
        activity_a.title
      )

      page_text = Nokogiri::HTML(response.body).text

      expect(page_text).to include(
        "Capacity: #{shift_a1.capacity}"
      )

      # 2. 查看 Organization B 的班次
      get "/activities/#{activity_b.id}/shifts/#{shift_b.id}"

      expect(response).to have_http_status(:ok)

      expect(response.body).to include(
        activity_b.title
      )

      page_text = Nokogiri::HTML(response.body).text

      expect(page_text).to include(
        "Capacity: #{shift_b.capacity}"
      )
    end
  end

  # ==================================================
  # Organizer 访问权限测试
  # ==================================================

  describe "organizer access" do
    before do
      sign_in_as(organizer_a)
    end

    # Test 5: Organizer 可以查看自己组织的班次列表
    it "allows organizers to view shifts belonging to their own organization" do
      get "/activities/#{activity_a.id}/shifts"

      expect(response).to have_http_status(:ok)

      document = Nokogiri::HTML(response.body)

      links = document.css("a").map do |link|
        link["href"]
      end

      expect(links).to include(
        "/activities/#{activity_a.id}/shifts/#{shift_a1.id}"
      )

      expect(links).to include(
        "/activities/#{activity_a.id}/shifts/#{shift_a2.id}"
      )

      expect(links).not_to include(
        "/activities/#{activity_b.id}/shifts/#{shift_b.id}"
      )

      expect(links).not_to include(
        "/activities/#{activity_a.id}/shifts/#{shift_b.id}"
      )
    end

    # Test 6: Organizer 可以查看自己组织的班次详情
    it "allows organizers to view their own shift details" do
      get "/activities/#{activity_a.id}/shifts/#{shift_a1.id}"

      expect(response).to have_http_status(:ok)

      expect(response.body).to include(
        activity_a.title
      )

      document = Nokogiri::HTML(response.body)

      # 检查班次容量
      expect(document.text).to include(
        "Capacity: #{shift_a1.capacity}"
      )

      # 检查班次开始及结束时间
      time_values = document.css("time").map do |element|
        element["datetime"]
      end

      expect(time_values).to include(
        shift_a1.start_time.iso8601
      )

      expect(time_values).to include(
        shift_a1.end_time.iso8601
      )
    end

    # Test 7: Organizer 不能查看其他组织的班次列表
    it "prevents organizers from viewing shifts belonging to another organization" do
      get "/activities/#{activity_b.id}/shifts"

      expect(response).to have_http_status(
        :not_found
      )

      expect(response.body).not_to include(
        activity_b.title
      )
    end

    # Test 8: Organizer 不能查看其他组织的班次详情
    it "prevents organizers from viewing shift details belonging to another organization" do
      get "/activities/#{activity_b.id}/shifts/#{shift_b.id}"

      expect(response).to have_http_status(
        :not_found
      )

      expect(response.body).not_to include(
        activity_b.title
      )
    end
  end

  # ==================================================
  # 嵌套路由及资源安全测试
  # ==================================================

  describe "nested resource protection" do
    # Test 9: 禁止使用错误的 Activity ID 访问班次
    it "rejects shifts that do not belong to the requested activity" do
      sign_in_as(volunteer)

      # 使用 Activity A 的 ID 请求 Activity B 的班次
      get "/activities/#{activity_a.id}/shifts/#{shift_b.id}"

      expect(response).to have_http_status(
        :not_found
      )

      expect(response.body).not_to include(
        activity_b.title
      )
    end

    # Test 10: 请求不存在的班次时返回 404
    it "returns not found when the requested shift does not exist" do
      sign_in_as(volunteer)

      nonexistent_shift_id = Shift.maximum(:id) + 1

      get "/activities/#{activity_a.id}/shifts/#{nonexistent_shift_id}"

      expect(response).to have_http_status(
        :not_found
      )
    end
  end

  # ==================================================
  # 班次创建测试
  # ==================================================

  describe "shift creation" do
    # 创建班次时使用的合法参数
    let(:valid_shift_attributes) do
      {
        start_time: (start_time + 8.hours).iso8601,
        end_time: (start_time + 11.hours).iso8601,
        capacity: 25
      }
    end

    # ==================================================
    # 未登录用户权限测试
    # ==================================================

    context "unauthenticated access" do
      # Test 11: 未登录用户不能访问创建班次页面
      it "redirects unauthenticated users when accessing the new shift page" do
        get "/activities/#{activity_a.id}/shifts/new"

        expect(response).to redirect_to(
          new_session_path
        )
      end

      # Test 12: 未登录用户不能创建班次
      it "prevents unauthenticated users from creating shifts" do
        # 1. 尝试提交创建班次请求
        expect {
          post "/activities/#{activity_a.id}/shifts", params: {
            shift: valid_shift_attributes
          }
        }.not_to change(Shift, :count)

        # 2. 检查是否跳转至登录页面
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
        sign_in_as(volunteer)
      end

      # Test 13: Volunteer 不能访问创建班次页面
      it "prevents volunteers from accessing the new shift page" do
        get "/activities/#{activity_a.id}/shifts/new"

        expect(response).to have_http_status(
          :forbidden
        )
      end

      # Test 14: Volunteer 不能创建班次
      it "prevents volunteers from creating shifts" do
        # 1. 尝试提交创建班次请求
        expect {
          post "/activities/#{activity_a.id}/shifts", params: {
            shift: valid_shift_attributes
          }
        }.not_to change(Shift, :count)

        # 2. 检查权限拒绝响应
        expect(response).to have_http_status(
          :forbidden
        )
      end
    end

    # ==================================================
    # Organizer 班次创建测试
    # ==================================================

    context "organizer access" do
      before do
        sign_in_as(organizer_a)
      end

      # Test 15: Organizer 可以访问创建班次页面
      it "allows organizers to access the new shift page" do
        # 1. 请求创建班次页面
        get "/activities/#{activity_a.id}/shifts/new"

        expect(response).to have_http_status(:ok)

        # 2. 解析 HTML 表单
        document = Nokogiri::HTML(response.body)

        # 3. 检查必要的输入字段
        expect(
          document.at_css('input[name="shift[start_time]"]')
        ).not_to be_nil

        expect(
          document.at_css('input[name="shift[end_time]"]')
        ).not_to be_nil

        expect(
          document.at_css('input[name="shift[capacity]"]')
        ).not_to be_nil

        # 4. 不允许用户自行指定所属 Activity
        expect(
          document.at_css('[name="shift[activity_id]"]')
        ).to be_nil

        # 5. 检查表单属于正确的活动
        expect(document.text).to include(
          activity_a.title
        )
      end

      # Test 16: Organizer 可以成功创建班次
      it "allows organizers to create shifts for their own activities" do
        # 1. 提交合法班次参数
        expect {
          post "/activities/#{activity_a.id}/shifts", params: {
            shift: valid_shift_attributes
          }
        }.to change(Shift, :count).by(1)

        # 2. 查询新创建的班次
        shift = activity_a.shifts.find_by!(
          start_time: start_time + 8.hours
        )

        # 3. 检查班次开始及结束时间
        expect(shift.start_time).to eq(
          start_time + 8.hours
        )

        expect(shift.end_time).to eq(
          start_time + 11.hours
        )

        # 4. 检查班次容量
        expect(shift.capacity).to eq(25)

        # 5. 检查班次所属活动及组织
        expect(shift.activity).to eq(activity_a)

        expect(shift.activity.organization).to eq(
          organization_a
        )

        # 6. 新班次不应包含任何报名记录
        expect(shift.signups).to be_empty
        expect(shift.confirmed_count).to eq(0)
        expect(shift.available_slots).to eq(25)
        expect(shift.waitlist_queue).to be_empty

        # 7. 创建成功后跳转至班次详情
        expect(response).to redirect_to(
          activity_shift_path(activity_a, shift)
        )
      end

      # Test 17: 拒绝非法班次容量
      it "rejects invalid shift capacity" do
        # 1. 构造容量为 0 的非法参数
        invalid_attributes =
          valid_shift_attributes.merge(
            capacity: 0
          )

        # 2. 提交非法参数
        expect {
          post "/activities/#{activity_a.id}/shifts", params: {
            shift: invalid_attributes
          }
        }.not_to change(Shift, :count)

        # 3. 检查 HTTP 响应
        expect(response).to have_http_status(422)

        # 4. 检查页面错误信息
        page_text = Nokogiri::HTML(response.body).text

        expect(page_text).to include(
          "Capacity must be greater than 0"
        )
      end

      # Test 18: 拒绝非法班次时间
      it "rejects shifts with invalid start and end times" do
        # 1. 将结束时间设置为早于开始时间
        invalid_attributes =
          valid_shift_attributes.merge(
            end_time: (start_time + 7.hours).iso8601
          )

        # 2. 提交非法时间参数
        expect {
          post "/activities/#{activity_a.id}/shifts", params: {
            shift: invalid_attributes
          }
        }.not_to change(Shift, :count)

        # 3. 检查 HTTP 响应
        expect(response).to have_http_status(422)

        # 4. 检查页面错误信息
        page_text = Nokogiri::HTML(response.body).text

        expect(page_text).to include(
          "End time must be after the start time"
        )
      end

      # Test 19: Organizer 不能为其他组织创建班次
      it "prevents organizers from creating shifts for another organization" do
        # 1. 尝试查看其他组织的创建班次页面
        get "/activities/#{activity_b.id}/shifts/new"

        expect(response).to have_http_status(
          :not_found
        )

        # 2. 记录其他组织的原有班次数量
        original_shift_count = activity_b.shifts.count

        # 3. 直接向其他组织的活动提交创建请求
        expect {
          post "/activities/#{activity_b.id}/shifts", params: {
            shift: valid_shift_attributes
          }
        }.not_to change(Shift, :count)

        # 4. 检查权限拒绝响应
        expect(response).to have_http_status(
          :not_found
        )

        # 5. 其他组织的班次数量保持不变
        expect(activity_b.shifts.count).to eq(
          original_shift_count
        )
      end

      # Test 20: 防止通过 HTTP 参数指定其他 Activity
      it "ignores protected attributes during shift creation" do
        # 1. 保存其他组织班次的原有数据
        original_other_attributes = shift_b.attributes
        original_other_shift_count = activity_b.shifts.count

        # 2. 在合法参数中加入受保护属性
        malicious_attributes =
          valid_shift_attributes.merge(
            activity_id: activity_b.id,
            id: shift_b.id
          )

        # 3. 提交包含非法属性的创建请求
        expect {
          post "/activities/#{activity_a.id}/shifts", params: {
            shift: malicious_attributes
          }
        }.to change(Shift, :count).by(1)

        # 4. 查询新创建的班次
        shift = activity_a.shifts.find_by!(
          start_time: start_time + 8.hours
        )

        # 5. 班次必须属于 URL 指定的合法 Activity
        expect(shift.activity_id).to eq(activity_a.id)

        expect(shift.activity_id).not_to eq(
          activity_b.id
        )

        # 6. 不允许自行指定班次 ID
        expect(shift.id).not_to eq(shift_b.id)

        # 7. 合法属性仍然成功保存
        expect(shift.capacity).to eq(25)

        expect(shift.start_time).to eq(
          start_time + 8.hours
        )

        expect(shift.end_time).to eq(
          start_time + 11.hours
        )

        # 8. 其他组织的班次数量及数据保持不变
        expect(activity_b.shifts.count).to eq(
          original_other_shift_count
        )

        expect(shift_b.reload.attributes).to eq(
          original_other_attributes
        )

        # 9. 创建成功后跳转至正确的班次详情
        expect(response).to redirect_to(
          activity_shift_path(activity_a, shift)
        )
      end
    end
  end

  # ==================================================
  # 班次编辑及更新测试
  # ==================================================

  describe "shift editing" do
    # 修改班次时使用的合法参数
    let(:updated_shift_attributes) do
      {
        start_time: (start_time + 8.hours).iso8601,
        end_time: (start_time + 11.hours).iso8601,
        capacity: 25
      }
    end

    # 创建额外的 Volunteer，用于容量及递补测试
    let(:volunteer_b) do
      User.create!(
        email_address: "volunteer_b@example.com",
        password: "password123",
        role: "volunteer"
      )
    end

    # ==================================================
    # 未登录用户权限测试
    # ==================================================

    context "unauthenticated access" do
      # Test 21: 未登录用户不能查看编辑班次页面
      it "redirects unauthenticated users when accessing the edit shift page" do
        get "/activities/#{activity_a.id}/shifts/#{shift_a1.id}/edit"

        expect(response).to redirect_to(
          new_session_path
        )
      end

      # Test 22: 未登录用户不能修改班次
      it "prevents unauthenticated users from updating shifts" do
        # 1. 保存班次原有数据
        original_attributes = shift_a1.attributes

        # 2. 提交修改请求
        patch "/activities/#{activity_a.id}/shifts/#{shift_a1.id}", params: {
          shift: updated_shift_attributes
        }

        # 3. 检查是否跳转至登录页面
        expect(response).to redirect_to(
          new_session_path
        )

        # 4. 检查数据库中的班次没有被修改
        expect(shift_a1.reload.attributes).to eq(
          original_attributes
        )
      end
    end

    # ==================================================
    # Volunteer 权限测试
    # ==================================================

    context "volunteer access" do
      before do
        sign_in_as(volunteer)
      end

      # Test 23: Volunteer 不能查看编辑班次页面
      it "prevents volunteers from accessing the edit shift page" do
        get "/activities/#{activity_a.id}/shifts/#{shift_a1.id}/edit"

        expect(response).to have_http_status(
          :forbidden
        )
      end

      # Test 24: Volunteer 不能修改班次
      it "prevents volunteers from updating shifts" do
        # 1. 保存班次原有数据
        original_attributes = shift_a1.attributes

        # 2. 提交修改请求
        patch "/activities/#{activity_a.id}/shifts/#{shift_a1.id}", params: {
          shift: updated_shift_attributes
        }

        # 3. 检查权限拒绝响应
        expect(response).to have_http_status(
          :forbidden
        )

        # 4. 检查班次数据保持不变
        expect(shift_a1.reload.attributes).to eq(
          original_attributes
        )
      end
    end

    # ==================================================
    # Organizer 班次编辑测试
    # ==================================================

    context "organizer access" do
      before do
        sign_in_as(organizer_a)
      end

      # Test 25: Organizer 可以查看自己组织的班次编辑页面
      it "allows organizers to access the edit page for their own shifts" do
        # 1. 请求编辑班次页面
        get "/activities/#{activity_a.id}/shifts/#{shift_a1.id}/edit"

        expect(response).to have_http_status(:ok)

        # 2. 解析 HTML 表单
        document = Nokogiri::HTML(response.body)

        start_time_input = document.at_css(
          'input[name="shift[start_time]"]'
        )

        end_time_input = document.at_css(
          'input[name="shift[end_time]"]'
        )

        capacity_input = document.at_css(
          'input[name="shift[capacity]"]'
        )

        # 3. 检查必要输入字段
        expect(start_time_input).not_to be_nil
        expect(end_time_input).not_to be_nil
        expect(capacity_input).not_to be_nil

        # 4. 检查表单包含原有班次数据
        expect(start_time_input["value"]).to start_with(
          shift_a1.start_time.strftime("%Y-%m-%dT%H:%M")
        )

        expect(end_time_input["value"]).to start_with(
          shift_a1.end_time.strftime("%Y-%m-%dT%H:%M")
        )

        expect(capacity_input["value"]).to eq(
          shift_a1.capacity.to_s
        )

        # 5. 不允许通过表单修改所属活动
        expect(
          document.at_css('[name="shift[activity_id]"]')
        ).to be_nil

        # 6. 检查页面所属活动
        expect(document.text).to include(
          activity_a.title
        )
      end

      # Test 26: Organizer 可以成功修改班次
      it "allows organizers to update shifts belonging to their own activities" do
        # 1. 保存原有班次 ID 及所属活动
        original_id = shift_a1.id
        original_activity_id = shift_a1.activity_id

        # 2. 提交合法修改请求
        expect {
          patch "/activities/#{activity_a.id}/shifts/#{shift_a1.id}", params: {
            shift: updated_shift_attributes
          }
        }.not_to change(Shift, :count)

        # 3. 重新读取数据库记录
        shift_a1.reload

        # 4. 检查合法属性成功更新
        expect(shift_a1.start_time).to eq(
          start_time + 8.hours
        )

        expect(shift_a1.end_time).to eq(
          start_time + 11.hours
        )

        expect(shift_a1.capacity).to eq(25)

        # 5. 检查受保护属性保持不变
        expect(shift_a1.id).to eq(original_id)

        expect(shift_a1.activity_id).to eq(
          original_activity_id
        )

        # 6. 修改成功后跳转至班次详情
        expect(response).to redirect_to(
          activity_shift_path(activity_a, shift_a1)
        )
      end

      # Test 27: 容量不能低于正式报名人数
      it "rejects capacity reductions below the confirmed signup count" do
        # 1. 创建两条正式报名记录
        signup_a = Signup.create!(
          user: volunteer,
          shift: shift_a1,
          status: "confirmed"
        )

        signup_b = Signup.create!(
          user: volunteer_b,
          shift: shift_a1,
          status: "confirmed"
        )

        expect(shift_a1.confirmed_count).to eq(2)

        # 2. 保存原有班次数据
        original_attributes = shift_a1.attributes

        # 3. 尝试将容量降低至 1
        patch "/activities/#{activity_a.id}/shifts/#{shift_a1.id}", params: {
          shift: {
            capacity: 1
          }
        }

        # 4. 检查 HTTP 响应
        expect(response).to have_http_status(422)

        # 5. 检查错误信息
        page_text = Nokogiri::HTML(response.body).text

        expect(page_text).to include(
          "Capacity cannot be less than the number of confirmed signups"
        )

        # 6. 检查班次数据保持不变
        expect(shift_a1.reload.attributes).to eq(
          original_attributes
        )

        # 7. 正式报名记录不受影响
        expect(signup_a.reload.status).to eq("confirmed")
        expect(signup_b.reload.status).to eq("confirmed")
        expect(shift_a1.confirmed_count).to eq(2)
      end

      # Test 28: 拒绝非法班次时间修改
      it "rejects shift updates with invalid start and end times" do
        # 1. 保存原有班次数据
        original_attributes = shift_a1.attributes

        # 2. 构造非法时间参数
        invalid_attributes =
          updated_shift_attributes.merge(
            end_time: (start_time + 7.hours).iso8601
          )

        # 3. 提交非法修改请求
        patch "/activities/#{activity_a.id}/shifts/#{shift_a1.id}", params: {
          shift: invalid_attributes
        }

        # 4. 检查 HTTP 响应
        expect(response).to have_http_status(422)

        # 5. 检查错误信息
        page_text = Nokogiri::HTML(response.body).text

        expect(page_text).to include(
          "End time must be after the start time"
        )

        # 6. 检查数据库中的班次保持不变
        expect(shift_a1.reload.attributes).to eq(
          original_attributes
        )
      end

      # Test 29: 禁止跨组织编辑及修改班次
      it "prevents organizers from editing and updating shifts belonging to another organization" do
        # 1. 保存其他组织班次的原有数据
        original_attributes = shift_b.attributes

        # 2. 尝试访问其他组织的班次编辑页面
        get "/activities/#{activity_b.id}/shifts/#{shift_b.id}/edit"

        expect(response).to have_http_status(
          :not_found
        )

        expect(response.body).not_to include(
          activity_b.title
        )

        # 3. 直接提交跨组织修改请求
        patch "/activities/#{activity_b.id}/shifts/#{shift_b.id}", params: {
          shift: updated_shift_attributes
        }

        expect(response).to have_http_status(
          :not_found
        )

        # 4. 检查其他组织班次未被修改
        expect(shift_b.reload.attributes).to eq(
          original_attributes
        )
      end

      # Test 30: 禁止使用错误的 Activity ID 修改班次
      it "rejects shift edits and updates through an incorrect parent activity" do
        # 1. 创建同一组织下的另一个活动
        other_activity = Activity.create!(
          title: "Tree Planting",
          description: "Plant trees around campus",
          location: "CUHK Campus",
          organization: organization_a
        )

        # 2. 保存班次原有数据
        original_attributes = shift_a1.attributes

        # 3. 使用错误的 Activity ID 请求编辑页面
        get "/activities/#{other_activity.id}/shifts/#{shift_a1.id}/edit"

        expect(response).to have_http_status(
          :not_found
        )

        # 4. 使用错误的 Activity ID 提交修改请求
        patch "/activities/#{other_activity.id}/shifts/#{shift_a1.id}", params: {
          shift: updated_shift_attributes
        }

        expect(response).to have_http_status(
          :not_found
        )

        # 5. 班次数据必须保持不变
        expect(shift_a1.reload.attributes).to eq(
          original_attributes
        )
      end

      # Test 31: 防止通过 HTTP 参数修改受保护属性
      it "ignores protected attributes during shift updates" do
        # 1. 保存原有班次 ID 及所属活动
        original_id = shift_a1.id
        original_activity_id = shift_a1.activity_id

        # 2. 保存其他组织班次的原有数据
        original_other_attributes = shift_b.attributes

        # 3. 在合法参数中加入受保护属性
        malicious_attributes =
          updated_shift_attributes.merge(
            activity_id: activity_b.id,
            id: shift_b.id
          )

        # 4. 提交包含非法属性的修改请求
        expect {
          patch "/activities/#{activity_a.id}/shifts/#{shift_a1.id}", params: {
            shift: malicious_attributes
          }
        }.not_to change(Shift, :count)

        # 5. 重新读取原有班次
        shift_a1.reload

        # 6. 检查合法属性成功更新
        expect(shift_a1.capacity).to eq(25)

        expect(shift_a1.start_time).to eq(
          start_time + 8.hours
        )

        expect(shift_a1.end_time).to eq(
          start_time + 11.hours
        )

        # 7. 检查受保护属性保持不变
        expect(shift_a1.id).to eq(original_id)

        expect(shift_a1.activity_id).to eq(
          original_activity_id
        )

        # 8. 其他组织的班次不能受到影响
        expect(shift_b.reload.attributes).to eq(
          original_other_attributes
        )

        # 9. 修改成功后跳转至正确班次
        expect(response).to redirect_to(
          activity_shift_path(activity_a, shift_a1)
        )
      end

      # ==================================================
      # HTTP 层核心业务规则测试
      # ==================================================

      # Test 32: 增加班次容量后自动递补候补用户
      it "automatically promotes waitlisted volunteers when capacity increases" do
        # 1. 设置初始班次容量为 1
        shift_a1.update!(capacity: 1)

        # 2. Volunteer A 占用唯一正式名额
        signup_a = SignupService.call(
          user: volunteer,
          shift: shift_a1
        )

        # 3. Volunteer B 进入候补队列
        signup_b = SignupService.call(
          user: volunteer_b,
          shift: shift_a1
        )

        expect(signup_a.status).to eq("confirmed")
        expect(signup_b.status).to eq("waitlisted")
        expect(signup_b.waitlisted_at).not_to be_nil

        # 4. 通过 HTTP 请求增加班次容量
        expect {
          patch "/activities/#{activity_a.id}/shifts/#{shift_a1.id}", params: {
            shift: {
              capacity: 2
            }
          }
        }.not_to change(Signup, :count)

        # 5. 检查修改成功后的跳转
        expect(response).to redirect_to(
          activity_shift_path(activity_a, shift_a1)
        )

        # 6. 检查容量成功增加
        expect(shift_a1.reload.capacity).to eq(2)

        # 7. 检查原有正式报名保持不变
        expect(signup_a.reload.status).to eq(
          "confirmed"
        )

        # 8. 检查候补用户自动转为正式报名
        expect(signup_b.reload.status).to eq(
          "confirmed"
        )

        expect(signup_b.waitlisted_at).to be_nil
        expect(signup_b.attendance_status).to eq("pending")

        # 9. 检查班次统计数据
        expect(shift_a1.confirmed_count).to eq(2)
        expect(shift_a1.available_slots).to eq(0)
        expect(shift_a1.waitlist_queue).to be_empty
      end

      # Test 33: 拒绝会造成时间冲突的班次修改
      it "rejects shift time updates that conflict with confirmed signups" do
        # 1. Volunteer 报名两个原本不冲突的班次
        signup_a = Signup.create!(
          user: volunteer,
          shift: shift_a1,
          status: "confirmed"
        )

        signup_b = Signup.create!(
          user: volunteer,
          shift: shift_a2,
          status: "confirmed"
        )

        # 2. 保存班次原有数据
        original_attributes = shift_a1.attributes

        # 3. 尝试修改班次时间，使两个班次产生重叠
        conflicting_attributes = {
          start_time: (start_time + 2.hours).iso8601,
          end_time: (start_time + 5.hours).iso8601
        }

        patch "/activities/#{activity_a.id}/shifts/#{shift_a1.id}", params: {
          shift: conflicting_attributes
        }

        # 4. 检查系统拒绝修改
        expect(response).to have_http_status(422)

        # 5. 检查时间冲突错误信息
        page_text = Nokogiri::HTML(response.body).text

        expect(page_text).to include(
          "time change conflicts with another confirmed signup"
        )

        # 6. 检查班次时间保持不变
        expect(shift_a1.reload.attributes).to eq(
          original_attributes
        )

        # 7. 检查原有报名记录不受影响
        expect(signup_a.reload.status).to eq(
          "confirmed"
        )

        expect(signup_b.reload.status).to eq(
          "confirmed"
        )
      end
    end
  end
end
