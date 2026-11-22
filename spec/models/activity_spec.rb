
require 'rails_helper'

RSpec.describe Activity, type: :model do
  describe "validations" do
    # Test 1: 活动必须拥有名称
    it "requires a title" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建一个名称为空的 Activity
      activity = Activity.new(
        title: "",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 检查 Activity 是否无法通过验证
      expect(activity).not_to be_valid

      # 4. 检查错误是否来自 title 字段
      expect(activity.errors[:title]).to include("can't be blank")
    end

    # Test 2: 活动必须拥有描述
    it "requires a description" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建一个描述为空的 Activity
      activity = Activity.new(
        title: "Campus Cleaning",
        description: "",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 检查 Activity 是否无法通过验证
      expect(activity).not_to be_valid

      # 4. 检查错误是否来自 description 字段
      expect(activity.errors[:description]).to include("can't be blank")
    end

    # Test 3: 活动必须拥有地点
    it "requires a location" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建一个地点为空的 Activity
      activity = Activity.new(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "",
        organization: organization
      )

      # 3. 检查 Activity 是否无法通过验证
      expect(activity).not_to be_valid

      # 4. 检查错误是否来自 location 字段
      expect(activity.errors[:location]).to include("can't be blank")
    end

    # Test 4: 活动必须属于一个 Organization
    it "requires an organization" do
      # 1. 创建一个没有所属 Organization 的 Activity
      activity = Activity.new(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus"
      )

      # 2. 检查 Activity 是否无法通过验证
      expect(activity).not_to be_valid

      # 3. 检查错误是否来自 organization 字段
      expect(activity.errors[:organization]).to include("must exist")
    end

    # Test 5: 合法活动可以成功保存
    it "creates an activity with valid attributes" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建并保存一个合法的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 检查 Activity 是否成功保存到数据库
      expect(activity).to be_persisted

      # 4. 从数据库重新读取 Activity
      activity.reload

      # 5. 检查活动信息是否正确
      expect(activity.title).to eq("Campus Cleaning")
      expect(activity.description).to eq("Campus cleaning volunteer activity")
      expect(activity.location).to eq("CUHK Campus")

      # 6. 检查活动所属 Organization 是否正确
      expect(activity.organization).to eq(organization)
    end
  end

  describe "associations" do
    # Test 6: Organization 可以拥有多个 Activity
    it "allows an organization to have multiple activities" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建第一个 Activity
      activity_a = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 创建第二个 Activity
      activity_b = Activity.create!(
        title: "Community Visit",
        description: "Community service volunteer activity",
        location: "Sha Tin",
        organization: organization
      )

      # 4. 检查 Organization 是否包含这两个 Activity
      expect(organization.activities).to contain_exactly(
        activity_a,
        activity_b
      )

      # 5. 检查 Organization 拥有的活动数量
      expect(organization.activities.count).to eq(2)
    end
  end
end
