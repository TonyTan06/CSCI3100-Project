
module ShiftSignupDisplay
  extend ActiveSupport::Concern

  private

  # ==================================================
  # 班次报名状态显示
  # ==================================================

  # 准备班次详情页面所需的个人报名数据
  def prepare_signup_display
    # 1. 初始化页面数据
    @current_signup = nil
    @waitlist_position = nil
    @waitlist_total = 0

    # 2. 仅为 Volunteer 查询个人报名信息
    return unless Current.user.role == "volunteer"

    # 3. 查询数据库中的真实报名状态
    @current_signup = @shift.signups.find_by(
      user_id: Current.user.id
    )

    # 4. 仅为候补用户计算候补排位
    return unless @current_signup&.status == "waitlisted"

    # 5. 获取按照候补时间排序的报名 ID
    waitlist_ids = @shift.waitlist_queue.pluck(:id)

    # 6. 查找当前用户在候补队列中的位置
    position = waitlist_ids.index(@current_signup.id)

    # 7. 计算实际候补排位及队列人数
    @waitlist_position = position + 1 unless position.nil?
    @waitlist_total = waitlist_ids.length
  end
end
