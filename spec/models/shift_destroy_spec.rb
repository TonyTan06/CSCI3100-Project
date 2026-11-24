require "rails_helper"

RSpec.describe Shift, type: :model do
  # ==================================================
  # 测试数据
  # ==================================================

  let(:organization) do
    Organization.create!(
      name: "CUHK Volunteer Team"
    )
  end

  let(:activity) do
    Activity.create!(
      organization: organization,
      title: "Campus Cleaning",
      description: "Campus cleaning volunteer activity",
      location: "CUHK Campus"
    )
  end

  let(:volunteer) do
    User.create!(
      email_address: "shift-destroy-volunteer@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "volunteer"
    )
  end

  let(:start_time) { 1.day.from_now.change(usec: 0) }

  let(:shift) do
    Shift.create!(
      activity: activity,
      start_time: start_time,
      end_time: start_time + 3.hours,
      capacity: 5
    )
  end

  # ==================================================
  # 班次删除保护
  # ==================================================

  describe "destroy protection" do
    # Test 1: 允许删除没有报名记录的班次
    it "allows destruction of a shift without signups" do
      shift.destroy

      expect(shift).to be_destroyed
      expect(Shift.exists?(shift.id)).to be false
    end

    # Test 2: 禁止删除存在已确认报名的班次
    it "prevents destruction of a shift with confirmed signups" do
      signup = Signup.create!(
        user: volunteer,
        shift: shift,
        status: "confirmed",
        attendance_status: "pending"
      )

      expect(shift.destroy).to be false
      expect(shift.errors[:base]).to be_present
      expect(Shift.exists?(shift.id)).to be true
      expect(Signup.exists?(signup.id)).to be true
    end

    # Test 3: 禁止删除存在候补报名的班次
    it "prevents destruction of a shift with waitlisted signups" do
      signup = Signup.create!(
        user: volunteer,
        shift: shift,
        status: "waitlisted",
        attendance_status: "pending"
      )

      expect(shift.destroy).to be false
      expect(shift.errors[:base]).to be_present
      expect(Shift.exists?(shift.id)).to be true
      expect(Signup.exists?(signup.id)).to be true
    end

    # Test 4: 禁止删除存在已取消报名记录的班次
    it "prevents destruction of a shift with cancelled signups" do
      signup = Signup.create!(
        user: volunteer,
        shift: shift,
        status: "cancelled",
        attendance_status: "pending"
      )

      expect(shift.destroy).to be false
      expect(shift.errors[:base]).to be_present
      expect(Shift.exists?(shift.id)).to be true
      expect(Signup.exists?(signup.id)).to be true
    end

    # Test 5: 禁止删除存在出勤记录的班次
    it "preserves existing attendance records" do
      signup = Signup.create!(
        user: volunteer,
        shift: shift,
        status: "confirmed",
        attendance_status: "present"
      )

      expect(shift.destroy).to be false
      expect(shift.errors[:base]).to be_present
      expect(Shift.exists?(shift.id)).to be true
      expect(signup.reload.attendance_status).to eq("present")
    end
  end
end
