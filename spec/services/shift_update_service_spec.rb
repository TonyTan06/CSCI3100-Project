
require 'rails_helper'

RSpec.describe ShiftUpdateService do
  include ActiveSupport::Testing::TimeHelpers

  # ==================================================
  # 公共测试数据
  # ==================================================

  # 创建主要 Organization
  let(:organization) do
    Organization.create!(
      name: "CUHK Volunteer Team"
    )
  end

  # 创建另一个 Organization
  let(:other_organization) do
    Organization.create!(
      name: "CUHK Community Service"
    )
  end

  # 创建主要 Activity
  let(:activity) do
    Activity.create!(
      title: "Campus Cleaning",
      description: "Campus cleaning volunteer activity",
      location: "CUHK Campus",
      organization: organization
    )
  end

  # 创建主要 Organizer
  let(:organizer) do
    User.create!(
      email_address: "organizer@example.com",
      password: "password123",
      role: "organizer",
      organization: organization
    )
  end

  # 创建其他组织的 Organizer
  let(:other_organizer) do
    User.create!(
      email_address: "other_organizer@example.com",
      password: "password123",
      role: "organizer",
      organization: other_organization
    )
  end

  # 设置初始时间
  let(:initial_time) do
    Time.current.change(usec: 0)
  end

  # 设置班次开始时间
  let(:start_time) do
    initial_time + 1.day
  end

  # 创建主要测试班次
  let(:shift) do
    Shift.create!(
      activity: activity,
      start_time: start_time,
      end_time: start_time + 3.hours,
      capacity: 1
    )
  end

  # 创建与主要班次存在时间冲突的班次
  let(:conflicting_shift) do
    Shift.create!(
      activity: activity,
      start_time: start_time + 2.hours,
      end_time: start_time + 5.hours,
      capacity: 20
    )
  end

  # 创建与主要班次暂时不存在时间冲突的班次
  let(:other_shift) do
    Shift.create!(
      activity: activity,
      start_time: start_time + 4.hours,
      end_time: start_time + 7.hours,
      capacity: 20
    )
  end

  # 创建 Volunteer
  let(:volunteer_a) do
    create_volunteer("volunteer_a@example.com")
  end

  let(:volunteer_b) do
    create_volunteer("volunteer_b@example.com")
  end

  let(:volunteer_c) do
    create_volunteer("volunteer_c@example.com")
  end

  let(:volunteer_d) do
    create_volunteer("volunteer_d@example.com")
  end

  # ==================================================
  # 辅助方法
  # ==================================================

  # 创建 Volunteer
  def create_volunteer(email)
    User.create!(
      email_address: email,
      password: "password123",
      role: "volunteer"
    )
  end

  # 创建正式报名
  def create_confirmed_signup(user:, shift:)
    Signup.create!(
      user: user,
      shift: shift,
      status: "confirmed"
    )
  end

  # 在指定时间创建候补报名
  def create_waitlisted_signup(user:, shift:, time:)
    travel_to(time) do
      Signup.create!(
        user: user,
        shift: shift,
        status: "waitlisted"
      )
    end
  end

  # ==================================================
  # 班次修改测试
  # ==================================================

  describe ".call" do

    # Test 1: Organizer 可以增加自己组织的班次容量
    it "allows an organizer to increase capacity for their own shift" do

      result = ShiftUpdateService.call(
        user: organizer,
        shift: shift,
        attributes: {
          capacity: 3
        }
      )

      # 检查修改成功
      expect(result).to be_a(Shift)
      expect(result.errors).to be_empty
      expect(result.reload.capacity).to eq(3)

      # 检查剩余名额
      expect(shift.available_slots).to eq(3)
    end

    # Test 2: 增加容量后自动递补第一位候补用户
    it "promotes the first waitlisted signup when capacity increases" do

      signup_a = create_confirmed_signup(
        user: volunteer_a,
        shift: shift
      )

      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time
      )

      signup_c = create_waitlisted_signup(
        user: volunteer_c,
        shift: shift,
        time: initial_time + 10.minutes
      )

      expect(shift.full?).to be true

      # 将班次容量从 1 增加至 2
      result = ShiftUpdateService.call(
        user: organizer,
        shift: shift,
        attributes: {
          capacity: 2
        }
      )

      # 检查容量修改成功
      expect(result.errors).to be_empty
      expect(shift.reload.capacity).to eq(2)

      # 检查报名状态
      expect(signup_a.reload.status).to eq("confirmed")
      expect(signup_b.reload.status).to eq("confirmed")
      expect(signup_c.reload.status).to eq("waitlisted")

      # 检查递补后候补时间已清空
      expect(signup_b.waitlisted_at).to be_nil

      expect(shift.confirmed_count).to eq(2)
      expect(shift.waitlist_queue.to_a).to eq([signup_c])
      expect(shift.full?).to be true
    end

    # Test 3: 增加多个名额后连续递补
    it "promotes multiple waitlisted signups when several slots are added" do

      create_confirmed_signup(
        user: volunteer_a,
        shift: shift
      )

      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time
      )

      signup_c = create_waitlisted_signup(
        user: volunteer_c,
        shift: shift,
        time: initial_time + 10.minutes
      )

      signup_d = create_waitlisted_signup(
        user: volunteer_d,
        shift: shift,
        time: initial_time + 20.minutes
      )

      # 将班次容量从 1 增加至 3
      result = ShiftUpdateService.call(
        user: organizer,
        shift: shift,
        attributes: {
          capacity: 3
        }
      )

      expect(result.errors).to be_empty
      expect(shift.reload.capacity).to eq(3)

      # 检查前两位候补用户成功转正
      expect(signup_b.reload.status).to eq("confirmed")
      expect(signup_c.reload.status).to eq("confirmed")
      expect(signup_d.reload.status).to eq("waitlisted")

      expect(shift.confirmed_count).to eq(3)
      expect(shift.waitlist_queue.to_a).to eq([signup_d])
      expect(shift.available_slots).to eq(0)
    end

    # Test 4: 自动跳过存在时间冲突的候补用户
    it "skips conflicting waitlisted signups when capacity increases" do

      create_confirmed_signup(
        user: volunteer_a,
        shift: shift
      )

      # Volunteer B 已经拥有存在时间冲突的正式报名
      conflicting_signup = create_confirmed_signup(
        user: volunteer_b,
        shift: conflicting_shift
      )

      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time
      )

      signup_c = create_waitlisted_signup(
        user: volunteer_c,
        shift: shift,
        time: initial_time + 10.minutes
      )

      original_waitlisted_at = signup_b.waitlisted_at

      result = ShiftUpdateService.call(
        user: organizer,
        shift: shift,
        attributes: {
          capacity: 2
        }
      )

      expect(result.errors).to be_empty
      expect(shift.reload.capacity).to eq(2)

      # B 因时间冲突无法转正
      expect(signup_b.reload.status).to eq("waitlisted")

      expect(signup_b.waitlisted_at).to eq(
        original_waitlisted_at
      )

      # C 成功转正
      expect(signup_c.reload.status).to eq("confirmed")

      # 原有冲突班次报名不受影响
      expect(conflicting_signup.reload.status).to eq(
        "confirmed"
      )

      expect(shift.waitlist_queue.to_a).to eq([signup_b])
      expect(shift.full?).to be true
    end

    # Test 5: 合法减少容量时不触发递补
    it "allows a valid capacity decrease without automatic promotion" do

      shift.update!(capacity: 3)

      signup_a = create_confirmed_signup(
        user: volunteer_a,
        shift: shift
      )

      expect(WaitlistService).not_to receive(:call)

      result = ShiftUpdateService.call(
        user: organizer,
        shift: shift,
        attributes: {
          capacity: 2
        }
      )

      expect(result.errors).to be_empty
      expect(shift.reload.capacity).to eq(2)
      expect(signup_a.reload.status).to eq("confirmed")
      expect(shift.available_slots).to eq(1)
    end

    # Test 6: 禁止容量低于已确认报名人数
    it "rejects capacity below the number of confirmed signups" do

      shift.update!(capacity: 2)

      create_confirmed_signup(
        user: volunteer_a,
        shift: shift
      )

      create_confirmed_signup(
        user: volunteer_b,
        shift: shift
      )

      expect(WaitlistService).not_to receive(:call)

      result = ShiftUpdateService.call(
        user: organizer,
        shift: shift,
        attributes: {
          capacity: 1
        }
      )

      # 检查返回容量验证错误
      expect(result.errors[:capacity]).to include(
        "cannot be less than the number of confirmed signups"
      )

      # 检查数据库中的容量保持不变
      expect(shift.reload.capacity).to eq(2)
      expect(shift.confirmed_count).to eq(2)
    end

    # Test 7: 合法修改班次时间
    it "allows a valid shift time change" do

      signup = create_confirmed_signup(
        user: volunteer_a,
        shift: shift
      )

      new_start_time = start_time + 1.hour
      new_end_time = start_time + 4.hours

      expect(WaitlistService).not_to receive(:call)

      result = ShiftUpdateService.call(
        user: organizer,
        shift: shift,
        attributes: {
          start_time: new_start_time,
          end_time: new_end_time
        }
      )

      expect(result.errors).to be_empty

      shift.reload

      expect(shift.start_time).to eq(new_start_time)
      expect(shift.end_time).to eq(new_end_time)

      expect(signup.reload.status).to eq("confirmed")
    end

    # Test 8: 禁止造成已有正式报名时间冲突的修改
    it "rejects a time change that creates a confirmed signup conflict" do

      create_confirmed_signup(
        user: volunteer_a,
        shift: shift
      )

      create_confirmed_signup(
        user: volunteer_a,
        shift: other_shift
      )

      original_start_time = shift.start_time
      original_end_time = shift.end_time

      expect(WaitlistService).not_to receive(:call)

      # 修改时间，使两个正式报名班次产生重叠
      result = ShiftUpdateService.call(
        user: organizer,
        shift: shift,
        attributes: {
          start_time: start_time + 2.hours,
          end_time: start_time + 5.hours
        }
      )

      expect(result.errors[:base]).to include(
        "time change conflicts with another confirmed signup"
      )

      # 原有时间应保持不变
      shift.reload

      expect(shift.start_time).to eq(original_start_time)
      expect(shift.end_time).to eq(original_end_time)
    end

    # Test 9: 禁止 Volunteer 修改班次
    it "rejects shift update requests from volunteers" do

      original_updated_at = shift.updated_at

      expect(WaitlistService).not_to receive(:call)

      result = ShiftUpdateService.call(
        user: volunteer_a,
        shift: shift,
        attributes: {
          capacity: 5
        }
      )

      expect(result.errors[:base]).to include(
        "must be an organizer"
      )

      expect(shift.reload.capacity).to eq(1)

      expect(shift.updated_at).to eq(
        original_updated_at
      )
    end

    # Test 10: 禁止 Organizer 修改其他组织的班次
    it "rejects updates to shifts belonging to another organization" do

      original_updated_at = shift.updated_at

      expect(WaitlistService).not_to receive(:call)

      result = ShiftUpdateService.call(
        user: other_organizer,
        shift: shift,
        attributes: {
          capacity: 5
        }
      )

      expect(result.errors[:base]).to include(
        "can only update shifts belonging to their own organization"
      )

      expect(shift.reload.capacity).to eq(1)

      expect(shift.updated_at).to eq(
        original_updated_at
      )
    end

    # Test 11: 容量未变化时不触发递补
    it "does not trigger promotion when capacity remains unchanged" do

      create_confirmed_signup(
        user: volunteer_a,
        shift: shift
      )

      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time
      )

      original_waitlisted_at = signup_b.waitlisted_at

      expect(WaitlistService).not_to receive(:call)

      result = ShiftUpdateService.call(
        user: organizer,
        shift: shift,
        attributes: {
          capacity: 1
        }
      )

      expect(result.errors).to be_empty
      expect(shift.reload.capacity).to eq(1)

      expect(signup_b.reload.status).to eq("waitlisted")

      expect(signup_b.waitlisted_at).to eq(
        original_waitlisted_at
      )

      expect(shift.full?).to be true
    end

    # Test 12: 递补发生系统异常时回滚容量修改
    it "rolls back capacity changes and promotions when promotion raises an error" do

      signup_a = create_confirmed_signup(
        user: volunteer_a,
        shift: shift
      )

      signup_b = create_waitlisted_signup(
        user: volunteer_b,
        shift: shift,
        time: initial_time
      )

      original_updated_at = shift.updated_at
      original_waitlisted_at = signup_b.waitlisted_at
      original_signup_updated_at = signup_b.updated_at

      # 模拟递补成功后发生系统异常
      allow(WaitlistService)
        .to receive(:call)
        .with(shift: shift) do

          signup_b.reload
          signup_b.update!(status: "confirmed")

          raise StandardError, "Simulated promotion failure"
        end

      expect {
        ShiftUpdateService.call(
          user: organizer,
          shift: shift,
          attributes: {
            capacity: 2
          }
        )
      }.to raise_error(
        StandardError,
        "Simulated promotion failure"
      )

      # 检查班次容量已回滚
      expect(shift.reload.capacity).to eq(1)

      expect(shift.updated_at).to eq(
        original_updated_at
      )

      # 检查报名状态已回滚
      expect(signup_a.reload.status).to eq("confirmed")
      expect(signup_b.reload.status).to eq("waitlisted")

      expect(signup_b.waitlisted_at).to eq(
        original_waitlisted_at
      )

      expect(signup_b.updated_at).to eq(
        original_signup_updated_at
      )

      expect(shift.confirmed_count).to eq(1)
      expect(shift.waitlist_queue.count).to eq(1)
      expect(shift.full?).to be true
    end
  end
end
