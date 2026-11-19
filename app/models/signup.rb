
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
end
