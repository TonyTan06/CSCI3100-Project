
class Shift < ApplicationRecord
  belongs_to :activity

  # 一个 Shift 可以拥有多个报名记录
  has_many :signups

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
end
