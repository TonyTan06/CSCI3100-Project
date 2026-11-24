
class Shift < ApplicationRecord
  belongs_to :activity

  # 一个 Shift 可以拥有多个报名记录
  # 存在任何报名记录时，禁止删除该班次
  has_many :signups, dependent: :restrict_with_error

  # 班次必须拥有开始时间
  validates :start_time, presence: true

  # 班次必须拥有结束时间
  validates :end_time, presence: true

  # 班次必须拥有容量上限
  validates :capacity, presence: true

  # 班次容量上限必须大于 0
  # 班次容量上限必须为整数
  validates :capacity, numericality: {
    greater_than: 0,
    only_integer: true
  }

  # 班次结束时间必须晚于开始时间
  validate :end_time_after_start_time

  # 班次容量不能低于已确认报名人数
  validate :capacity_must_not_be_below_confirmed_count

  # 修改班次时间不能造成已有报名的时间冲突
  validate :time_change_must_not_cause_conflicts

  # 统计当前班次已确认的报名人数
  def confirmed_count
    signups.where(status: "confirmed").count
  end

  # 计算当前班次的剩余名额
  def available_slots
    capacity - confirmed_count
  end

  # 判断当前班次是否已满
  def full?
    available_slots <= 0
  end

  # 获取当前班次按照 FIFO 原则排列的候补队列
  def waitlist_queue
    signups
      .where(status: "waitlisted")
      .order(waitlisted_at: :asc, id: :asc)
  end

  private

  # 自定义时间验证方法
  def end_time_after_start_time
    # 1. 如果开始时间或结束时间为空，则跳过比较
    return if start_time.blank? || end_time.blank?

    # 2. 检查结束时间是否晚于开始时间
    if end_time <= start_time
      # 3. 添加自定义错误信息
      errors.add(:end_time, "must be after the start time")
    end
  end

  # 自定义班次容量验证方法
  def capacity_must_not_be_below_confirmed_count
    # 1. 如果班次容量为空，则跳过验证
    return if capacity.blank?

    # 2. 如果班次尚未保存，则跳过验证
    return if new_record?

    # 3. 检查班次容量是否低于已确认报名人数
    if capacity < confirmed_count
      # 4. 添加自定义错误信息
      errors.add(
        :capacity,
        "cannot be less than the number of confirmed signups"
      )
    end
  end

  # 自定义班次时间修改保护方法
  def time_change_must_not_cause_conflicts
    # 1. 如果班次尚未保存，则跳过验证
    return if new_record?

    # 2. 如果开始时间或结束时间为空，则跳过验证
    return if start_time.blank? || end_time.blank?

    # 3. 如果班次时间本身不合法，则跳过验证
    return if end_time <= start_time

    # 4. 如果班次时间没有发生修改，则跳过验证
    return unless will_save_change_to_start_time? ||
                  will_save_change_to_end_time?

    # 5. 获取当前班次中所有已确认 Volunteer 的 ID
    confirmed_user_ids = signups
      .where(status: "confirmed")
      .select(:user_id)

    # 6. 获取这些 Volunteer 在其他班次中的已确认报名
    other_confirmed_signups = Signup
      .where(user_id: confirmed_user_ids)
      .where(status: "confirmed")
      .where.not(shift_id: id)

    # 7. 检查修改后的班次时间是否与其他班次重叠
    overlapping_signups = other_confirmed_signups
      .joins(:shift)
      .where(
        "shifts.start_time < ? AND shifts.end_time > ?",
        end_time,
        start_time
      )

    # 8. 如果存在时间冲突，则拒绝修改班次时间
    if overlapping_signups.exists?
      errors.add(
        :base,
        "time change conflicts with another confirmed signup"
      )
    end
  end
end
