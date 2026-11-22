
require 'rails_helper'
require 'nokogiri'

RSpec.describe "Activities", type: :request do
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
  let!(:activity_a) do
    Activity.create!(
      title: "Campus Cleaning",
      description: "Campus cleaning volunteer activity",
      location: "CUHK Campus",
      organization: organization_a
    )
  end

  # 创建 Organization B 的活动
  let!(:activity_b) do
    Activity.create!(
      title: "Community Service",
      description: "Community volunteer activity",
      location: "Sha Tin",
      organization: organization_b
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
    # Test 1: 未登录用户不能查看活动列表
    it "redirects unauthenticated users to login when viewing activities" do
      get "/activities"

      expect(response).to redirect_to(
        new_session_path
      )
    end

    # Test 2: 未登录用户不能查看活动详情
    it "redirects unauthenticated users to login when viewing an activity" do
      get "/activities/#{activity_a.id}"

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

    # Test 3: Volunteer 可以查看所有组织的活动
    it "allows volunteers to view activities across organizations" do
      # 1. 请求活动列表
      get "/activities"

      # 2. 检查 HTTP 请求成功
      expect(response).to have_http_status(:ok)

      # 3. 检查两个组织的活动均被显示
      expect(response.body).to include(
        activity_a.title
      )

      expect(response.body).to include(
        activity_b.title
      )
    end

    # Test 4: Volunteer 可以查看不同组织的活动详情
    it "allows volunteers to view activity details across organizations" do
      # 1. 查看 Organization A 的活动
      get "/activities/#{activity_a.id}"

      expect(response).to have_http_status(:ok)

      expect(response.body).to include(
        activity_a.title
      )

      expect(response.body).to include(
        activity_a.description
      )

      expect(response.body).to include(
        activity_a.location
      )

      # 2. 查看 Organization B 的活动
      get "/activities/#{activity_b.id}"

      expect(response).to have_http_status(:ok)

      expect(response.body).to include(
        activity_b.title
      )

      expect(response.body).to include(
        activity_b.description
      )

      expect(response.body).to include(
        activity_b.location
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

    # Test 5: Organizer 只能查看所属组织的活动列表
    it "only displays activities belonging to the organizer's organization" do
      # 1. 请求活动列表
      get "/activities"

      expect(response).to have_http_status(:ok)

      # 2. 自己组织的活动应该被显示
      expect(response.body).to include(
        activity_a.title
      )

      # 3. 其他组织的活动不应该被显示
      expect(response.body).not_to include(
        activity_b.title
      )
    end

    # Test 6: Organizer 可以查看自己组织的活动详情
    it "allows organizers to view activities belonging to their own organization" do
      get "/activities/#{activity_a.id}"

      expect(response).to have_http_status(:ok)

      expect(response.body).to include(
        activity_a.title
      )

      expect(response.body).to include(
        activity_a.description
      )

      expect(response.body).to include(
        activity_a.location
      )
    end

    # Test 7: Organizer 不能访问其他组织的活动详情
    it "prevents organizers from viewing activities belonging to another organization" do
      # 1. 直接请求其他组织的活动 URL
      get "/activities/#{activity_b.id}"

      # 2. 检查系统拒绝访问
      expect(response).to have_http_status(
        :not_found
      )

      # 3. 不允许泄露其他组织的活动详情
      expect(response.body).not_to include(
        activity_b.description
      )

      expect(response.body).not_to include(
        activity_b.title
      )
    end
  end

  # ==================================================
  # 活动创建测试
  # ==================================================

  describe "activity creation" do
    # 创建活动时使用的合法参数
    let(:valid_activity_attributes) do
      {
        title: "Beach Cleaning",
        description: "Clean the beach with volunteers",
        location: "Hong Kong"
      }
    end

    # ==================================================
    # 未登录用户权限测试
    # ==================================================

    context "unauthenticated access" do
      # Test 8: 未登录用户不能查看创建活动页面
      it "redirects unauthenticated users when accessing the new activity page" do
        get "/activities/new"

        expect(response).to redirect_to(
          new_session_path
        )
      end

      # Test 9: 未登录用户不能创建活动
      it "prevents unauthenticated users from creating activities" do
        # 1. 尝试提交创建活动请求
        expect {
          post "/activities", params: {
            activity: valid_activity_attributes
          }
        }.not_to change(Activity, :count)

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

      # Test 10: Volunteer 不能查看创建活动页面
      it "prevents volunteers from accessing the new activity page" do
        get "/activities/new"

        expect(response).to have_http_status(
          :forbidden
        )
      end

      # Test 11: Volunteer 不能创建活动
      it "prevents volunteers from creating activities" do
        # 1. 尝试提交创建活动请求
        expect {
          post "/activities", params: {
            activity: valid_activity_attributes
          }
        }.not_to change(Activity, :count)

        # 2. 检查权限拒绝响应
        expect(response).to have_http_status(
          :forbidden
        )
      end
    end

    # ==================================================
    # Organizer 活动创建测试
    # ==================================================

    context "organizer access" do
      before do
        sign_in_as(organizer_a)
      end

      # Test 12: Organizer 可以查看创建活动页面
      it "allows organizers to access the new activity page" do
        # 1. 请求创建活动页面
        get "/activities/new"

        # 2. 检查页面成功返回
        expect(response).to have_http_status(:ok)

        # 3. 检查页面包含三个必要输入字段
        expect(response.body).to include(
          'name="activity[title]"'
        )

        expect(response.body).to include(
          'name="activity[description]"'
        )

        expect(response.body).to include(
          'name="activity[location]"'
        )

        # 4. 页面不允许自行选择所属组织
        expect(response.body).not_to include(
          'name="activity[organization_id]"'
        )
      end

      # Test 13: Organizer 可以成功创建活动
      it "allows organizers to create activities for their own organization" do
        # 1. 提交合法活动参数
        expect {
          post "/activities", params: {
            activity: valid_activity_attributes
          }
        }.to change(Activity, :count).by(1)

        # 2. 查询新创建的活动
        activity = Activity.find_by!(
          title: valid_activity_attributes[:title]
        )

        # 3. 检查活动属性
        expect(activity.title).to eq(
          valid_activity_attributes[:title]
        )

        expect(activity.description).to eq(
          valid_activity_attributes[:description]
        )

        expect(activity.location).to eq(
          valid_activity_attributes[:location]
        )

        # 4. 检查活动自动归属于 Organizer 的组织
        expect(activity.organization).to eq(
          organization_a
        )

        # 5. 创建成功后跳转至活动详情页面
        expect(response).to redirect_to(
          activity_path(activity)
        )
      end

      # Test 14: 拒绝保存无效活动数据
      it "rejects invalid activity attributes" do
        # 1. 创建缺少标题的无效参数
        invalid_attributes =
          valid_activity_attributes.merge(
            title: ""
          )

        # 2. 提交无效数据
        expect {
          post "/activities", params: {
            activity: invalid_attributes
          }
        }.not_to change(Activity, :count)

        # 3. 检查 HTTP 响应
        expect(response).to have_http_status(422)

        # 4. 解析 HTML，避免 HTML 实体编码影响测试
        page_text = Nokogiri::HTML(response.body).text

        # 5. 检查页面实际显示的完整错误信息
        expect(page_text).to include(
          "Title can't be blank"
        )
      end

      # Test 15: 防止通过 HTTP 参数指定其他组织
      it "ignores an injected organization ID during activity creation" do
        # 1. 在合法参数中加入非法组织 ID
        malicious_attributes =
          valid_activity_attributes.merge(
            organization_id: organization_b.id
          )

        original_other_organization_count =
          organization_b.activities.count

        # 2. 提交包含非法属性的请求
        expect {
          post "/activities", params: {
            activity: malicious_attributes
          }
        }.to change(Activity, :count).by(1)

        # 3. 查询新创建的活动
        activity = Activity.find_by!(
          title: valid_activity_attributes[:title]
        )

        # 4. 活动仍然必须属于 Organizer 自己的组织
        expect(activity.organization_id).to eq(
          organization_a.id
        )

        # 5. 不允许归属于其他组织
        expect(activity.organization_id).not_to eq(
          organization_b.id
        )

        # 6. 其他组织的活动数量保持不变
        expect(
          organization_b.activities.count
        ).to eq(
          original_other_organization_count
        )

        # 7. 合法属性仍然成功保存
        expect(activity.description).to eq(
          valid_activity_attributes[:description]
        )

        expect(activity.location).to eq(
          valid_activity_attributes[:location]
        )

        # 8. 创建成功后跳转至活动详情页面
        expect(response).to redirect_to(
          activity_path(activity)
        )
      end
    end
  end

  # ==================================================
  # 活动编辑及更新测试
  # ==================================================

  describe "activity editing" do
    # 修改活动时使用的合法参数
    let(:updated_activity_attributes) do
      {
        title: "Updated Campus Cleaning",
        description: "Updated volunteer activity description",
        location: "University Station"
      }
    end

    # ==================================================
    # 未登录用户权限测试
    # ==================================================

    context "unauthenticated access" do
      # Test 16: 未登录用户不能查看编辑页面
      it "redirects unauthenticated users when accessing the edit activity page" do
        get "/activities/#{activity_a.id}/edit"

        expect(response).to redirect_to(
          new_session_path
        )
      end

      # Test 17: 未登录用户不能修改活动
      it "prevents unauthenticated users from updating activities" do
        # 1. 保存原有活动数据
        original_attributes = activity_a.attributes

        # 2. 尝试修改活动
        patch "/activities/#{activity_a.id}", params: {
          activity: updated_activity_attributes
        }

        # 3. 检查是否跳转至登录页面
        expect(response).to redirect_to(
          new_session_path
        )

        # 4. 检查原有活动数据保持不变
        expect(activity_a.reload.attributes).to eq(
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

      # Test 18: Volunteer 不能查看编辑页面
      it "prevents volunteers from accessing the edit activity page" do
        get "/activities/#{activity_a.id}/edit"

        expect(response).to have_http_status(
          :forbidden
        )
      end

      # Test 19: Volunteer 不能修改活动
      it "prevents volunteers from updating activities" do
        # 1. 保存原有活动数据
        original_attributes = activity_a.attributes

        # 2. 尝试修改活动
        patch "/activities/#{activity_a.id}", params: {
          activity: updated_activity_attributes
        }

        # 3. 检查权限拒绝响应
        expect(response).to have_http_status(
          :forbidden
        )

        # 4. 检查数据库中的活动没有被修改
        expect(activity_a.reload.attributes).to eq(
          original_attributes
        )
      end
    end

    # ==================================================
    # Organizer 活动编辑测试
    # ==================================================

    context "organizer access" do
      before do
        sign_in_as(organizer_a)
      end

      # Test 20: Organizer 可以查看自己组织的活动编辑页面
      it "allows organizers to edit activities belonging to their own organization" do
        # 1. 请求编辑活动页面
        get "/activities/#{activity_a.id}/edit"

        # 2. 检查页面成功返回
        expect(response).to have_http_status(:ok)

        # 3. 解析 HTML 表单
        document = Nokogiri::HTML(response.body)

        title_input = document.at_css(
          'input[name="activity[title]"]'
        )

        description_input = document.at_css(
          'textarea[name="activity[description]"]'
        )

        location_input = document.at_css(
          'input[name="activity[location]"]'
        )

        # 4. 检查输入字段包含原有活动数据
        expect(title_input).not_to be_nil
        expect(description_input).not_to be_nil
        expect(location_input).not_to be_nil

        expect(title_input["value"]).to eq(
          activity_a.title
        )

        expect(description_input.text.strip).to eq(
          activity_a.description
        )

        expect(location_input["value"]).to eq(
          activity_a.location
        )

        # 5. 不允许通过表单修改活动所属组织
        expect(response.body).not_to include(
          'name="activity[organization_id]"'
        )
      end

      # Test 21: Organizer 可以成功修改自己组织的活动
      it "allows organizers to update activities belonging to their own organization" do
        # 1. 保存原有活动 ID 和所属组织
        original_id = activity_a.id
        original_organization_id = activity_a.organization_id

        # 2. 提交修改请求
        expect {
          patch "/activities/#{activity_a.id}", params: {
            activity: updated_activity_attributes
          }
        }.not_to change(Activity, :count)

        # 3. 重新读取数据库记录
        activity_a.reload

        # 4. 检查活动属性成功更新
        expect(activity_a.title).to eq(
          updated_activity_attributes[:title]
        )

        expect(activity_a.description).to eq(
          updated_activity_attributes[:description]
        )

        expect(activity_a.location).to eq(
          updated_activity_attributes[:location]
        )

        # 5. 检查活动身份及所属组织保持不变
        expect(activity_a.id).to eq(original_id)

        expect(activity_a.organization_id).to eq(
          original_organization_id
        )

        # 6. 修改成功后跳转至活动详情页面
        expect(response).to redirect_to(
          activity_path(activity_a)
        )
      end

      # Test 22: 拒绝无效的活动修改
      it "rejects invalid activity updates" do
        # 1. 保存原有活动数据
        original_attributes = activity_a.attributes

        # 2. 创建无效修改参数
        invalid_attributes =
          updated_activity_attributes.merge(
            title: ""
          )

        # 3. 提交无效修改请求
        patch "/activities/#{activity_a.id}", params: {
          activity: invalid_attributes
        }

        # 4. 检查 HTTP 响应
        expect(response).to have_http_status(422)

        # 5. 解析 HTML 并检查错误信息
        page_text = Nokogiri::HTML(response.body).text

        expect(page_text).to include(
          "Title can't be blank"
        )

        # 6. 检查数据库中的原有数据保持不变
        expect(activity_a.reload.attributes).to eq(
          original_attributes
        )
      end

      # Test 23: Organizer 不能编辑其他组织的活动
      it "prevents organizers from editing and updating activities belonging to another organization" do
        # 1. 保存其他组织活动的原有数据
        original_attributes = activity_b.attributes

        # 2. 尝试查看其他组织的活动编辑页面
        get "/activities/#{activity_b.id}/edit"

        expect(response).to have_http_status(
          :not_found
        )

        expect(response.body).not_to include(
          activity_b.description
        )

        # 3. 直接提交修改其他组织活动的请求
        patch "/activities/#{activity_b.id}", params: {
          activity: updated_activity_attributes
        }

        expect(response).to have_http_status(
          :not_found
        )

        # 4. 检查其他组织活动未被修改
        expect(activity_b.reload.attributes).to eq(
          original_attributes
        )
      end

      # Test 24: 防止通过 HTTP 参数修改受保护属性
      it "ignores protected attributes during activity updates" do
        # 1. 保存原有活动 ID 和所属组织
        original_id = activity_a.id
        original_organization_id = activity_a.organization_id

        # 2. 保存其他组织活动的原有数据
        original_other_attributes = activity_b.attributes

        # 3. 在合法参数中加入非法属性
        malicious_attributes =
          updated_activity_attributes.merge(
            organization_id: organization_b.id,
            id: activity_b.id
          )

        # 4. 提交包含非法属性的修改请求
        expect {
          patch "/activities/#{activity_a.id}", params: {
            activity: malicious_attributes
          }
        }.not_to change(Activity, :count)

        # 5. 重新读取原有活动
        activity_a.reload

        # 6. 检查合法属性成功更新
        expect(activity_a.title).to eq(
          updated_activity_attributes[:title]
        )

        expect(activity_a.description).to eq(
          updated_activity_attributes[:description]
        )

        expect(activity_a.location).to eq(
          updated_activity_attributes[:location]
        )

        # 7. 检查受保护属性保持不变
        expect(activity_a.id).to eq(original_id)

        expect(activity_a.organization_id).to eq(
          original_organization_id
        )

        # 8. 检查其他组织活动未被修改
        expect(activity_b.reload.attributes).to eq(
          original_other_attributes
        )

        # 9. 修改成功后跳转至活动详情页面
        expect(response).to redirect_to(
          activity_path(activity_a)
        )
      end
    end
  end
end
