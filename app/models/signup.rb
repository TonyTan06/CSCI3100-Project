
class Signup < ApplicationRecord
  belongs_to :user
  belongs_to :shift

  # 报名记录必须拥有状态
  validates :status, presence: true

  # 报名记录必须拥有合法的状态
  validates :status, inclusion: {
    in: ["confirmed", "waitlisted", "cancelled"]
  }

  # 报名记录必须拥有合法的出勤状态
  validates :attendance_status, inclusion: {
    in: ["pending", "present", "absent"]
  }

  # 仅允许 Volunteer 报名
  validate :user_must_be_volunteer

  # 防止同一个 Volunteer 重复报名同一个 Shift
  validates :user_id, uniqueness: {
    scope: :shift_id
  }

  # 防止已确认报名人数超过班次容量
  validate :shift_must_have_available_capacity

  # 防止同一个 Volunteer 报名时间重叠的班次
  validate :shift_must_not_overlap

  # 在保存报名记录之前自动管理候补时间
  before_save :manage_waitlisted_at

  private

  # 自定义用户角色验证方法
  def user_must_be_volunteer
    # 1. 如果 User 不存在，则跳过角色验证
    return if user.blank?

    # 2. 检查 User 是否拥有 Volunteer 角色
    if user.role != "volunteer"
      # 3. 添加自定义错误信息
      errors.add(:user, "must be a volunteer")
    end
  end

  # 自定义班次容量验证方法
  def shift_must_have_available_capacity
    # 1. 如果 Shift 不存在，则跳过容量验证
    return if shift.blank?

    # 2. 仅对已确认报名进行容量验证
    return unless status == "confirmed"

    # 3. 如果班次容量尚未设置，则跳过容量验证
    return if shift.capacity.blank?

    # 4. 统计当前班次的其他已确认报名记录
    confirmed_count = shift.signups
                           .where(status: "confirmed")
                           .where.not(id: id)
                           .count

    # 5. 检查班次是否还有可用名额
    if confirmed_count >= shift.capacity
      # 6. 添加自定义错误信息
      errors.add(:shift, "has reached its capacity")
    end
  end

  # 自定义报名时间冲突验证方法
  def shift_must_not_overlap
    # 1. 如果 User 或 Shift 不存在，则跳过验证
    return if user.blank? || shift.blank?

    # 2. 仅对已确认报名进行时间冲突验证
    return unless status == "confirmed"

    # 3. 如果班次开始时间或结束时间为空，则跳过验证
    return if shift.start_time.blank? || shift.end_time.blank?

    # 4. 获取当前 Volunteer 的其他已确认报名
    confirmed_signups = user.signups
                            .where(status: "confirmed")
                            .where.not(id: id)

    # 5. 检查是否存在时间重叠的班次
    overlapping_signups = confirmed_signups
      .joins(:shift)
      .where(
        "shifts.start_time < ? AND shifts.end_time > ?",
        shift.end_time,
        shift.start_time
      )

    # 6. 如果存在时间冲突，则添加自定义错误信息
    if overlapping_signups.exists?
      errors.add(
        :shift,
        "overlaps with another confirmed signup"
      )
    end
  end

  # 自动管理进入候补队列的时间
  def manage_waitlisted_at
    # 1. 检查当前报名状态是否为 waitlisted
    if status == "waitlisted"

      # 2. 如果是新记录、报名状态发生变化，
      #    或候补时间为空，则记录当前时间
      if new_record? ||
         will_save_change_to_status? ||
         waitlisted_at.blank?

        self.waitlisted_at = Time.current
      end

    else

      # 3. 如果当前状态不是 waitlisted，则清空候补时间
      self.waitlisted_at = nil

    end
  end
end
