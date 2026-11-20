
require 'rails_helper'

RSpec.describe ShiftCreateService do

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

  # 创建本组织活动
  let(:activity) do
    Activity.create!(
      title: "Campus Cleaning",
      description: "Campus cleaning volunteer activity",
      location: "CUHK Campus",
      organization: organization
    )
  end

  # 创建其他组织活动
  let(:other_activity) do
    Activity.create!(
      title: "Community Service",
      description: "Community volunteer activity",
      location: "Sha Tin",
      organization: other_organization
    )
  end

  # 设置班次开始时间
  let(:start_time) do
    Time.current.change(usec: 0) + 1.day
  end

  # 合法的班次属性
  let(:valid_attributes) do
    {
      start_time: start_time,
      end_time: start_time + 3.hours,
      capacity: 20
    }
  end

  # ==================================================
  # 创建班次测试
  # ==================================================

  describe ".call" do

    # Test 1: Organizer 可以成功创建自己组织的班次
    it "allows an organizer to create a shift for their own activity" do

      result = nil

      expect {
        result = ShiftCreateService.call(
          user: organizer,
          activity: activity,
          attributes: valid_attributes
        )
      }.to change(Shift, :count).by(1)

      expect(result).to be_a(Shift)
      expect(result).to be_persisted
      expect(result.errors).to be_empty

      result.reload

      # 检查班次属性
      expect(result.activity).to eq(activity)

      expect(result.start_time).to eq(
        valid_attributes[:start_time]
      )

      expect(result.end_time).to eq(
        valid_attributes[:end_time]
      )

      expect(result.capacity).to eq(20)

      # 新创建的班次没有报名记录
      expect(result.confirmed_count).to eq(0)
      expect(result.available_slots).to eq(20)
      expect(result.full?).to be false
      expect(result.waitlist_queue).to be_empty
    end

    # Test 2: 同一个活动可以创建多个班次
    it "allows an organizer to create multiple shifts for an activity" do

      first_shift = ShiftCreateService.call(
        user: organizer,
        activity: activity,
        attributes: valid_attributes
      )

      second_shift = ShiftCreateService.call(
        user: organizer,
        activity: activity,
        attributes: {
          start_time: start_time + 4.hours,
          end_time: start_time + 7.hours,
          capacity: 10
        }
      )

      expect(first_shift).to be_persisted
      expect(second_shift).to be_persisted

      expect(first_shift.errors).to be_empty
      expect(second_shift.errors).to be_empty

      expect(first_shift.id).not_to eq(
        second_shift.id
      )

      expect(activity.shifts.count).to eq(2)

      expect(activity.shifts).to include(
        first_shift,
        second_shift
      )
    end

    # Test 3: 禁止 Volunteer 创建班次
    it "rejects shift creation requests from volunteers" do

      result = nil

      expect {
        result = ShiftCreateService.call(
          user: volunteer,
          activity: activity,
          attributes: valid_attributes
        )
      }.not_to change(Shift, :count)

      expect(result).not_to be_persisted

      expect(result.errors[:base]).to include(
        "must be an organizer"
      )
    end

    # Test 4: 禁止 Organizer 为其他组织创建班次
    it "rejects shift creation for activities belonging to another organization" do

      result = nil

      expect {
        result = ShiftCreateService.call(
          user: other_organizer,
          activity: activity,
          attributes: valid_attributes
        )
      }.not_to change(Shift, :count)

      expect(result).not_to be_persisted

      expect(result.errors[:base]).to include(
        "can only create shifts for activities belonging to their own organization"
      )
    end

    # Test 5: 拒绝非法班次容量
    it "rejects shifts with invalid capacity values" do

      # 分别测试零、负数和非整数容量
      [0, -5, 1.5].each do |invalid_capacity|

        result = nil

        expect {
          result = ShiftCreateService.call(
            user: organizer,
            activity: activity,
            attributes: valid_attributes.merge(
              capacity: invalid_capacity
            )
          )
        }.not_to change(Shift, :count)

        expect(result).not_to be_persisted
        expect(result.errors[:capacity]).not_to be_empty
      end
    end

    # Test 6: 拒绝非法班次时间
    it "rejects shifts ending before or at their start time" do

      invalid_end_times = [
        start_time,
        start_time - 1.hour
      ]

      invalid_end_times.each do |invalid_end_time|

        result = nil

        expect {
          result = ShiftCreateService.call(
            user: organizer,
            activity: activity,
            attributes: valid_attributes.merge(
              end_time: invalid_end_time
            )
          )
        }.not_to change(Shift, :count)

        expect(result).not_to be_persisted

        expect(result.errors[:end_time]).to include(
          "must be after the start time"
        )
      end
    end

    # Test 7: 拒绝缺少必要属性的班次
    it "rejects shifts with missing required attributes" do

      result = nil

      expect {
        result = ShiftCreateService.call(
          user: organizer,
          activity: activity,
          attributes: {}
        )
      }.not_to change(Shift, :count)

      expect(result).not_to be_persisted

      expect(
        result.errors.of_kind?(:start_time, :blank)
      ).to be true

      expect(
        result.errors.of_kind?(:end_time, :blank)
      ).to be true

      expect(
        result.errors.of_kind?(:capacity, :blank)
      ).to be true
    end

    # Test 8: 禁止通过参数改变班次所属活动
    it "ignores attempts to assign a shift to another activity through attributes" do

      attributes = valid_attributes.merge(
        activity_id: other_activity.id,
        activity: other_activity
      )

      result = ShiftCreateService.call(
        user: organizer,
        activity: activity,
        attributes: attributes
      )

      expect(result).to be_persisted
      expect(result.errors).to be_empty

      # 班次必须属于经过权限验证的 Activity
      expect(result.reload.activity).to eq(
        activity
      )

      expect(activity.shifts).to include(
        result
      )

      expect(other_activity.shifts).not_to include(
        result
      )
    end
  end
end
