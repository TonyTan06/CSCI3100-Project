
require 'rails_helper'

RSpec.describe ActivityService do

  # ==================================================
  # 公共测试数据
  # ==================================================

  # 创建两个不同的 Organization
  let(:organization) do
    Organization.create!(
      name: "CUHK Volunteer Team"
    )
  end

  let(:other_organization) do
    Organization.create!(
      name: "CUHK Community Service"
    )
  end

  # 创建本组织 Organizer
  let(:organizer) do
    User.create!(
      email_address: "organizer@example.com",
      password: "password123",
      role: "organizer",
      organization: organization
    )
  end

  # 创建其他组织 Organizer
  let(:other_organizer) do
    User.create!(
      email_address: "other_organizer@example.com",
      password: "password123",
      role: "organizer",
      organization: other_organization
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

  # 合法的活动属性
  let(:valid_attributes) do
    {
      title: "Campus Cleaning",
      description: "Campus cleaning volunteer activity",
      location: "CUHK Campus"
    }
  end

  # 创建已有活动
  let(:activity) do
    Activity.create!(
      valid_attributes.merge(
        organization: organization
      )
    )
  end

  # ==================================================
  # 创建活动测试
  # ==================================================

  describe ".create" do

    # Test 1: Organizer 可以成功创建活动
    it "allows an organizer to create an activity" do

      result = nil

      expect {
        result = ActivityService.create(
          user: organizer,
          attributes: valid_attributes
        )
      }.to change(Activity, :count).by(1)

      expect(result).to be_a(Activity)
      expect(result).to be_persisted
      expect(result.errors).to be_empty

      # 检查活动属性
      result.reload

      expect(result.title).to eq(
        valid_attributes[:title]
      )

      expect(result.description).to eq(
        valid_attributes[:description]
      )

      expect(result.location).to eq(
        valid_attributes[:location]
      )
    end

    # Test 2: 自动分配 Organizer 所属组织
    it "automatically assigns the organizer's organization" do

      result = ActivityService.create(
        user: organizer,
        attributes: valid_attributes
      )

      expect(result).to be_persisted
      expect(result.errors).to be_empty

      expect(result.reload.organization).to eq(
        organization
      )

      expect(organization.activities).to include(
        result
      )
    end

    # Test 3: 禁止 Volunteer 创建活动
    it "rejects activity creation requests from volunteers" do

      result = nil

      expect {
        result = ActivityService.create(
          user: volunteer,
          attributes: valid_attributes
        )
      }.not_to change(Activity, :count)

      expect(result).not_to be_persisted

      expect(result.errors[:base]).to include(
        "must be an organizer"
      )
    end

    # Test 4: 禁止通过参数创建其他组织的活动
    it "ignores attempts to assign an activity to another organization" do

      attributes = valid_attributes.merge(
        organization_id: other_organization.id,
        organization: other_organization
      )

      result = ActivityService.create(
        user: organizer,
        attributes: attributes
      )

      expect(result).to be_persisted
      expect(result.errors).to be_empty

      # 活动必须属于当前 Organizer 的组织
      expect(result.reload.organization).to eq(
        organization
      )

      expect(other_organization.activities)
        .not_to include(result)
    end

    # Test 5: 拒绝无效的活动数据
    it "rejects activity creation with invalid attributes" do

      attributes = {
        title: "",
        description: "",
        location: ""
      }

      result = nil

      expect {
        result = ActivityService.create(
          user: organizer,
          attributes: attributes
        )
      }.not_to change(Activity, :count)

      expect(result).not_to be_persisted

      # 复用 Activity Model 的 presence 验证
      expect(
        result.errors.of_kind?(:title, :blank)
      ).to be true

      expect(
        result.errors.of_kind?(:description, :blank)
      ).to be true

      expect(
        result.errors.of_kind?(:location, :blank)
      ).to be true
    end
  end

  # ==================================================
  # 修改活动测试
  # ==================================================

  describe ".update" do

    # Test 6: Organizer 可以修改自己组织的活动
    it "allows an organizer to update their own activity" do

      original_id = activity.id
      original_created_at = activity.created_at

      result = ActivityService.update(
        user: organizer,
        activity: activity,
        attributes: {
          title: "Updated Campus Cleaning",
          description: "Updated description",
          location: "University Library"
        }
      )

      expect(result.errors).to be_empty

      result.reload

      expect(result.title).to eq(
        "Updated Campus Cleaning"
      )

      expect(result.description).to eq(
        "Updated description"
      )

      expect(result.location).to eq(
        "University Library"
      )

      # 检查原有记录及组织归属保持不变
      expect(result.id).to eq(original_id)

      expect(result.created_at).to eq(
        original_created_at
      )

      expect(result.organization).to eq(
        organization
      )
    end

    # Test 7: 禁止 Volunteer 修改活动
    it "rejects activity update requests from volunteers" do

      original_title = activity.title
      original_updated_at = activity.updated_at

      result = ActivityService.update(
        user: volunteer,
        activity: activity,
        attributes: {
          title: "Unauthorized modification"
        }
      )

      expect(result.errors[:base]).to include(
        "must be an organizer"
      )

      expect(activity.reload.title).to eq(
        original_title
      )

      expect(activity.updated_at).to eq(
        original_updated_at
      )
    end

    # Test 8: 禁止 Organizer 修改其他组织的活动
    it "rejects updates to activities belonging to another organization" do

      original_title = activity.title
      original_updated_at = activity.updated_at

      result = ActivityService.update(
        user: other_organizer,
        activity: activity,
        attributes: {
          title: "Unauthorized modification"
        }
      )

      expect(result.errors[:base]).to include(
        "can only update activities belonging to their own organization"
      )

      expect(activity.reload.title).to eq(
        original_title
      )

      expect(activity.updated_at).to eq(
        original_updated_at
      )
    end

    # Test 9: 禁止修改活动所属组织
    it "ignores attempts to change an activity's organization" do

      result = ActivityService.update(
        user: organizer,
        activity: activity,
        attributes: {
          title: "Updated Campus Cleaning",
          organization_id: other_organization.id,
          organization: other_organization
        }
      )

      expect(result.errors).to be_empty

      activity.reload

      # 合法属性可以修改
      expect(activity.title).to eq(
        "Updated Campus Cleaning"
      )

      # 组织归属必须保持不变
      expect(activity.organization).to eq(
        organization
      )

      expect(other_organization.activities)
        .not_to include(activity)
    end

    # Test 10: 拒绝无效的活动修改
    it "rejects invalid activity updates without changing stored data" do

      original_title = activity.title
      original_description = activity.description
      original_location = activity.location
      original_updated_at = activity.updated_at

      result = ActivityService.update(
        user: organizer,
        activity: activity,
        attributes: {
          title: "",
          description: "",
          location: ""
        }
      )

      expect(
        result.errors.of_kind?(:title, :blank)
      ).to be true

      expect(
        result.errors.of_kind?(:description, :blank)
      ).to be true

      expect(
        result.errors.of_kind?(:location, :blank)
      ).to be true

      # 检查数据库中原有数据保持不变
      activity.reload

      expect(activity.title).to eq(
        original_title
      )

      expect(activity.description).to eq(
        original_description
      )

      expect(activity.location).to eq(
        original_location
      )

      expect(activity.updated_at).to eq(
        original_updated_at
      )
    end
  end
end
