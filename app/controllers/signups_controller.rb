
class SignupsController < ApplicationController
  include ShiftSignupDisplay

  # 仅允许 Volunteer 报名及取消报名
  before_action :require_volunteer

  # 查找报名对应的活动及班次
  before_action :set_activity
  before_action :set_shift

  # 取消报名时查找当前用户的报名记录
  before_action :set_signup, only: [:destroy]

  # ==================================================
  # 班次报名
  # ==================================================

  # POST /activities/:activity_id/shifts/:shift_id/signups
  # 处理 Volunteer 报名请求
  def create
    # 1. 调用 SignupService 创建或恢复报名记录
    @signup = SignupService.call(
      user: Current.user,
      shift: @shift
    )

    # 2. 检查报名是否成功
    if @signup.persisted? && @signup.errors.empty?
      # 2.1 根据报名状态设置提示信息
      if @signup.status == "confirmed"
        message = "Signup confirmed successfully."
      else
        message = "You have been added to the waitlist."
      end

      # 2.2 报名成功，跳转至班次详情
      redirect_to activity_shift_path(@activity, @shift),
                  notice: message,
                  status: :see_other
    else
      # 2.3 报名失败，重新显示班次详情及错误信息
      @signup_error_title = "Unable to sign up"
      prepare_signup_display
      render "shifts/show", status: 422
    end
  end

  # ==================================================
  # 取消报名
  # ==================================================

  # DELETE /activities/:activity_id/shifts/:shift_id/signups/:id
  # 处理 Volunteer 取消报名请求
  def destroy
    # 1. 调用 CancellationService 取消报名
    @signup = CancellationService.call(
      user: Current.user,
      signup: @signup
    )

    # 2. 检查报名是否成功取消
    if @signup.status == "cancelled" && @signup.errors.empty?
      # 2.1 取消成功，跳转至班次详情
      redirect_to activity_shift_path(@activity, @shift),
                  notice: "Signup cancelled successfully.",
                  status: :see_other
    else
      # 2.2 取消失败，重新显示班次详情及错误信息
      @signup_error_title = "Unable to cancel signup"
      prepare_signup_display
      render "shifts/show", status: 422
    end
  end

  private

  # ==================================================
  # 权限控制
  # ==================================================

  # 检查当前用户是否为 Volunteer
  def require_volunteer
    head :forbidden unless Current.user.role == "volunteer"
  end

  # 查找当前请求对应的 Activity
  def set_activity
    @activity = Activity.find_by(
      id: params[:activity_id]
    )
    head :not_found unless @activity
  end

  # 查找当前 Activity 下的指定 Shift
  def set_shift
    @shift = @activity.shifts.find_by(
      id: params[:shift_id]
    )
    head :not_found unless @shift
  end

  # 查找属于当前班次及当前用户的 Signup
  def set_signup
    @signup = @shift.signups.where(
      user_id: Current.user.id
    ).find_by(
      id: params[:id]
    )
    head :not_found unless @signup
  end
end
