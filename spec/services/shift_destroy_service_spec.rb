require "rails_helper"

RSpec.describe "ShiftDestroyService" do
  # ==================================================
  # 测试数据
  # ==================================================

  let(:organization) do
    Organization.create!(
      name: "Test Organization"
    )
  end

  let(:other_organization) do
    Organization.create!(
      name: "Other Organization"
    )
  end

  let(:organizer) do
    User.create!(
      email_address: "destroy-organizer@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "organizer",
      organization: organization
    )
  end

  let(:other_organizer) do
    User.create!(
      email_address: "other-destroy-organizer@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "organizer",
      organization: other_organization
    )
  end

  let(:volunteer) do
    User.create!(
      email_address: "destroy-volunteer@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "volunteer"
    )
  end

  let(:activity) do
    Activity.create!(
      organization: organization,
      title: "Test Activity",
      description: "Activity for shift deletion testing.",
      location: "CUHK Main Campus"
    )
  end

  let(:start_time) { 2.days.from_now }

  let(:shift) do
    Shift.create!(
      activity: activity,
      start_time: start_time,
      end_time: start_time + 2.hours,
      capacity: 5
    )
  end

  # ==================================================
  # 班次删除测试
  # ==================================================

  describe ".call" do
    # 验证 Organizer 可以删除自己组织的空班次
    it "allows an organizer to destroy an empty shift in their own organization" do
      result = ShiftDestroyService.call(
        user: organizer,
        shift: shift
      )

      expect(result.destroyed?).to be true
      expect(Shift.exists?(shift.id)).to be false
    end

    # 验证 Volunteer 无法删除班次
    it "rejects shift deletion by a volunteer" do
      result = ShiftDestroyService.call(
        user: volunteer,
        shift: shift
      )

      expect(result.errors[:base]).to be_present
      expect(Shift.exists?(shift.id)).to be true
    end

    # 验证 Organizer 无法删除其他组织的班次
    it "rejects deletion of a shift belonging to another organization" do
      result = ShiftDestroyService.call(
        user: other_organizer,
        shift: shift
      )

      expect(result.errors[:base]).to be_present
      expect(Shift.exists?(shift.id)).to be true
    end

    # 验证存在报名记录的班次无法被删除
    it "rejects deletion of a shift with existing signups" do
      signup = Signup.create!(
        user: volunteer,
        shift: shift,
        status: "confirmed",
        attendance_status: "pending"
      )

      result = ShiftDestroyService.call(
        user: organizer,
        shift: shift
      )

      expect(result.errors[:base]).to be_present
      expect(Shift.exists?(shift.id)).to be true
      expect(Signup.exists?(signup.id)).to be true
    end
  end
end
