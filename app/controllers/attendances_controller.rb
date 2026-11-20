
class AttendancesController < ApplicationController
  # 仅允许 Organizer 管理出勤
  before_action :require_organizer

  # 查找当前组织下的活动及班次
  before_action :set_activity
  before_action :set_shift

  # 修改出勤时查找指定报名记录
  before_action :set_signup, only: [:update]

  # ==================================================
  # 出勤名单查看
  # ==================================================

  # GET /activities/:activity_id/shifts/:shift_id/attendances
  # 显示当前班次的正式报名人员及出勤统计
  def index
    load_confirmed_signups
  end

  # ==================================================
  # 出勤状态修改
  # ==================================================

  # PATCH /activities/:activity_id/shifts/:shift_id/attendances/:id
  # 处理 Organizer 修改出勤状态的请求
  def update
    # 1. 调用 AttendanceService 修改出勤状态
    @signup = AttendanceService.call(
      user: Current.user,
      signup: @signup,
      attendance_status: attendance_params[:attendance_status]
    )

    # 2. 检查出勤状态是否成功更新
    if @signup.errors.empty?
      # 2.1 更新成功，跳转至出勤名单
      redirect_to activity_shift_attendances_path(@activity, @shift),
                  notice: "Attendance updated successfully.",
                  status: :see_other
    else
      # 2.2 更新失败，重新读取正式报名人员及出勤统计
      load_confirmed_signups
      render :index, status: 422
    end
  end

  private

  # ==================================================
  # 权限控制
  # ==================================================

  # 检查当前用户是否为 Organizer
  def require_organizer
    head :forbidden unless Current.user.role == "organizer"
  end

  # 查找属于当前 Organizer 所在组织的 Activity
  def set_activity
    @activity = Activity.where(
      organization_id: Current.user.organization_id
    ).find_by(
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

  # 查找属于当前班次的 Signup
  def set_signup
    @signup = @shift.signups.find_by(
      id: params[:id]
    )
    head :not_found unless @signup
  end

  # ==================================================
  # 出勤名单及统计
  # ==================================================

  # 获取当前班次的正式报名人员及出勤统计
  def load_confirmed_signups
    # 1. 查询并加载正式报名人员
    @signups = @shift.signups.where(
      status: "confirmed"
    ).includes(:user).order(:id).to_a

    # 2. 计算出勤人数统计
    @attendance_summary = {
      confirmed: @signups.size,
      present: @signups.count { |signup| signup.attendance_status == "present" },
      absent: @signups.count { |signup| signup.attendance_status == "absent" },
      pending: @signups.count { |signup| signup.attendance_status == "pending" }
    }
  end

  # ==================================================
  # 参数安全检查
  # ==================================================

  # 检查出勤参数结构并限制允许提交的属性
  def attendance_params
    params.expect(
      attendance: [
        :attendance_status
      ]
    )
  end
end
