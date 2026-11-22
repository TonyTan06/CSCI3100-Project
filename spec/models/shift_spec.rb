
require 'rails_helper'

RSpec.describe Shift, type: :model do
  describe "validations" do
    # Test 1: 班次必须拥有开始时间
    it "requires a start time" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建班次所属的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 创建一个没有开始时间的 Shift
      shift = Shift.new(
        activity: activity,
        start_time: nil,
        end_time: 1.day.from_now + 3.hours,
        capacity: 20
      )

      # 4. 检查 Shift 是否无法通过验证
      expect(shift).not_to be_valid

      # 5. 检查错误是否来自 start_time 字段
      expect(shift.errors[:start_time]).to include("can't be blank")
    end

    # Test 2: 班次必须拥有结束时间
    it "requires an end time" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建班次所属的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 创建一个没有结束时间的 Shift
      shift = Shift.new(
        activity: activity,
        start_time: 1.day.from_now,
        end_time: nil,
        capacity: 20
      )

      # 4. 检查 Shift 是否无法通过验证
      expect(shift).not_to be_valid

      # 5. 检查错误是否来自 end_time 字段
      expect(shift.errors[:end_time]).to include("can't be blank")
    end

    # Test 3: 班次必须拥有容量上限
    it "requires a capacity" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建班次所属的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 创建一个没有容量上限的 Shift
      shift = Shift.new(
        activity: activity,
        start_time: 1.day.from_now,
        end_time: 1.day.from_now + 3.hours,
        capacity: nil
      )

      # 4. 检查 Shift 是否无法通过验证
      expect(shift).not_to be_valid

      # 5. 检查错误是否来自 capacity 字段
      expect(shift.errors[:capacity]).to include("can't be blank")
    end

    # Test 4: 班次容量上限必须大于 0
    it "requires a capacity greater than zero" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建班次所属的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 创建一个容量上限为 0 的 Shift
      shift = Shift.new(
        activity: activity,
        start_time: 1.day.from_now,
        end_time: 1.day.from_now + 3.hours,
        capacity: 0
      )

      # 4. 检查容量为 0 时是否无法通过验证
      expect(shift).not_to be_valid

      # 5. 检查错误是否来自 capacity 字段
      expect(shift.errors[:capacity]).to include("must be greater than 0")

      # 6. 将容量修改为负数
      shift.capacity = -5

      # 7. 检查容量为负数时是否无法通过验证
      expect(shift).not_to be_valid

      # 8. 检查错误是否来自 capacity 字段
      expect(shift.errors[:capacity]).to include("must be greater than 0")
    end

    # Test 5: 班次容量上限必须为整数
    it "requires an integer capacity" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建班次所属的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 创建一个容量上限为小数的 Shift
      shift = Shift.new(
        activity: activity,
        start_time: 1.day.from_now,
        end_time: 1.day.from_now + 3.hours,
        capacity: 2.5
      )

      # 4. 检查 Shift 是否无法通过验证
      expect(shift).not_to be_valid

      # 5. 检查错误是否来自 capacity 字段
      expect(shift.errors[:capacity]).to include("must be an integer")
    end

    # Test 6: 班次结束时间不能早于开始时间
    it "rejects an end time before the start time" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建班次所属的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 设置班次的开始时间
      start_time = 1.day.from_now

      # 4. 创建一个结束时间早于开始时间的 Shift
      shift = Shift.new(
        activity: activity,
        start_time: start_time,
        end_time: start_time - 1.hour,
        capacity: 20
      )

      # 5. 检查 Shift 是否无法通过验证
      expect(shift).not_to be_valid

      # 6. 检查错误是否来自 end_time 字段
      expect(shift.errors[:end_time]).to include("must be after the start time")
    end

    # Test 7: 班次结束时间不能等于开始时间
    it "rejects an end time equal to the start time" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建班次所属的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 设置班次的开始时间
      start_time = 1.day.from_now

      # 4. 创建一个结束时间等于开始时间的 Shift
      shift = Shift.new(
        activity: activity,
        start_time: start_time,
        end_time: start_time,
        capacity: 20
      )

      # 5. 检查 Shift 是否无法通过验证
      expect(shift).not_to be_valid

      # 6. 检查错误是否来自 end_time 字段
      expect(shift.errors[:end_time]).to include("must be after the start time")
    end

    # Test 8: 班次必须属于一个 Activity
    it "requires an activity" do
      # 1. 设置班次的开始时间
      start_time = 1.day.from_now

      # 2. 创建一个没有所属 Activity 的 Shift
      shift = Shift.new(
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 3. 检查 Shift 是否无法通过验证
      expect(shift).not_to be_valid

      # 4. 检查错误是否来自 activity 字段
      expect(shift.errors[:activity]).to include("must exist")
    end

    # Test 9: 合法班次可以成功保存
    it "creates a shift with valid attributes" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建班次所属的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 设置班次的开始时间和结束时间
      start_time = 1.day.from_now.change(usec: 0)
      end_time = start_time + 3.hours

      # 4. 创建并保存一个合法的 Shift
      shift = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: end_time,
        capacity: 20
      )

      # 5. 检查 Shift 是否成功保存到数据库
      expect(shift).to be_persisted

      # 6. 从数据库重新读取 Shift
      shift.reload

      # 7. 检查班次信息是否正确
      expect(shift.start_time).to eq(start_time)
      expect(shift.end_time).to eq(end_time)
      expect(shift.capacity).to eq(20)

      # 8. 检查班次所属 Activity 是否正确
      expect(shift.activity).to eq(activity)
    end
  end

  describe "associations" do
    # Test 10: Activity 可以拥有多个 Shift
    it "allows an activity to have multiple shifts" do
      # 1. 创建活动所属的 Organization
      organization = Organization.create!(
        name: "CUHK Volunteer Team"
      )

      # 2. 创建班次所属的 Activity
      activity = Activity.create!(
        title: "Campus Cleaning",
        description: "Campus cleaning volunteer activity",
        location: "CUHK Campus",
        organization: organization
      )

      # 3. 设置第一个班次的开始时间
      start_time = 1.day.from_now.change(usec: 0)

      # 4. 创建第一个 Shift
      shift_a = Shift.create!(
        activity: activity,
        start_time: start_time,
        end_time: start_time + 3.hours,
        capacity: 20
      )

      # 5. 创建第二个 Shift
      shift_b = Shift.create!(
        activity: activity,
        start_time: start_time + 5.hours,
        end_time: start_time + 8.hours,
        capacity: 15
      )

      # 6. 检查 Activity 是否包含这两个 Shift
      expect(activity.shifts).to contain_exactly(
        shift_a,
        shift_b
      )

      # 7. 检查 Activity 拥有的班次数量
      expect(activity.shifts.count).to eq(2)
    end
  end
end
