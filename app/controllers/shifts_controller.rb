
class ShiftsController < ApplicationController
  include ShiftSignupDisplay

  # 仅允许 Organizer 创建、修改及删除班次
  before_action :require_organizer, only: [ :new, :create, :edit, :update, :destroy ]

  # 检查活动访问权限（班次总列表不需要指定活动）
  before_action :set_activity, except: [ :all ]

  # 查找指定活动下的班次
  before_action :set_shift, only: [ :show, :edit, :update, :destroy ]

  # ==================================================
  # 班次查看
  # ==================================================

  # GET /shifts
  # 显示当前用户有权访问的所有班次
  def all
    # 1. 根据当前用户角色获取可访问的活动
    activities = accessible_activities

    # 2. 查询这些活动所属的全部班次
    # 3. 提前加载活动及组织信息
    # 4. 按照开始时间及班次 ID 排序
    @shifts = Shift
      .where(activity_id: activities.select(:id))
      .includes(activity: :organization)
      .order(:start_time, :id)
  end

  # GET /activities/:activity_id/shifts
  # 显示指定活动的所有班次
  def index
    @shifts = @activity.shifts.order(:start_time, :id)
  end

  # GET /activities/:activity_id/shifts/:id
  # 显示指定班次的详细信息
  def show
    prepare_signup_display
  end

  # ==================================================
  # 班次创建
  # ==================================================

  # GET /activities/:activity_id/shifts/new
  # 显示创建班次页面
  def new
    @shift = @activity.shifts.build
  end

  # POST /activities/:activity_id/shifts
  # 处理创建班次请求
  def create
    # 1. 调用 ShiftCreateService 创建班次
    @shift = ShiftCreateService.call(
      user: Current.user,
      activity: @activity,
      attributes: shift_params.to_h
    )

    # 2. 检查班次是否成功保存
    if @shift.persisted? && @shift.errors.empty?
      # 2.1 创建成功，跳转至班次详情
      redirect_to activity_shift_path(@activity, @shift),
                  notice: "Shift created successfully.",
                  status: :see_other
    else
      # 2.2 创建失败，重新显示创建页面
      render :new, status: 422
    end
  end

  # ==================================================
  # 班次编辑及更新
  # ==================================================

  # GET /activities/:activity_id/shifts/:id/edit
  # 显示班次编辑页面
  def edit
  end

  # PATCH /activities/:activity_id/shifts/:id
  # 处理班次更新请求
  def update
    # 1. 调用 ShiftUpdateService 更新班次
    @shift = ShiftUpdateService.call(
      user: Current.user,
      shift: @shift,
      attributes: shift_params.to_h
    )

    # 2. 检查班次是否成功更新
    if @shift.errors.empty?
      # 2.1 更新成功，跳转至班次详情
      redirect_to activity_shift_path(@activity, @shift),
                  notice: "Shift updated successfully.",
                  status: :see_other
    else
      # 2.2 更新失败，重新显示编辑页面
      render :edit, status: 422
    end
  end

  # ==================================================
  # 班次删除
  # ==================================================

  # DELETE /activities/:activity_id/shifts/:id
  # 处理班次删除请求
  def destroy
    # 1. 调用 ShiftDestroyService 删除班次
    @shift = ShiftDestroyService.call(
      user: Current.user,
      shift: @shift
    )

    # 2. 检查班次是否成功删除
    if @shift.destroyed?
      # 2.1 删除成功，跳转至活动的班次列表
      redirect_to activity_shifts_path(@activity),
                  notice: "Shift deleted successfully.",
                  status: :see_other
    else
      # 2.2 删除失败，返回班次详情并显示错误信息
      redirect_to activity_shift_path(@activity, @shift),
                  alert: @shift.errors.full_messages.to_sentence.presence || "Unable to delete shift.",
                  status: :see_other
    end
  end

  private

  # ==================================================
  # 权限控制
  # ==================================================

  # 根据当前用户角色限制可访问的活动范围
  def accessible_activities
    if Current.user.role == "organizer"
      Activity.where(
        organization_id: Current.user.organization_id
      )
    elsif Current.user.role == "volunteer"
      Activity.all
    else
      Activity.none
    end
  end

  # 查找当前请求对应的 Activity
  def set_activity
    @activity = accessible_activities.find_by(
      id: params[:activity_id]
    )
    head :not_found unless @activity
  end

  # 查找当前 Activity 下的指定 Shift
  def set_shift
    @shift = @activity.shifts.find_by(
      id: params[:id]
    )
    head :not_found unless @shift
  end

  # 检查当前用户是否为 Organizer
  def require_organizer
    head :forbidden unless Current.user.role == "organizer"
  end

  # ==================================================
  # 参数安全检查
  # ==================================================

  # 检查班次参数结构并限制允许提交的属性
  def shift_params
    params.expect(
      shift: [
        :start_time,
        :end_time,
        :capacity
      ]
    )
  end
end
