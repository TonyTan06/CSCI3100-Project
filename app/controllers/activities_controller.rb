
class ActivitiesController < ApplicationController

  # 仅允许 Organizer 创建及修改活动
  before_action :require_organizer, only: [:new, :create, :edit, :update]

  # ==================================================
  # 活动查看
  # ==================================================

  # GET /activities
  # 显示当前用户有权限查看的活动列表
  def index
    @activities = accessible_activities.order(:id)
  end

  # GET /activities/:id
  # 显示指定活动的详细信息
  def show
    @activity = accessible_activities.find_by(
      id: params[:id]
    )

    # 活动不存在或没有访问权限
    head :not_found unless @activity
  end

  # ==================================================
  # 活动创建
  # ==================================================

  # GET /activities/new
  # 显示创建活动页面
  def new
    @activity = Activity.new(
      organization: Current.user.organization
    )
  end

  # POST /activities
  # 处理创建活动请求
  def create
    # 1. 调用 ActivityService 创建活动
    @activity = ActivityService.create(
      user: Current.user,
      attributes: activity_params.to_h
    )

    # 2. 检查活动是否成功保存
    if @activity.persisted? && @activity.errors.empty?

      # 2.1 创建成功，跳转至活动详情页面
      redirect_to activity_path(@activity),
                  notice: "Activity created successfully.",
                  status: :see_other

    else

      # 2.2 创建失败，重新显示创建页面
      render :new, status: 422

    end
  end

  # ==================================================
  # 活动编辑及更新
  # ==================================================

  # GET /activities/:id/edit
  # 显示活动编辑页面
  def edit
    # 1. 在当前用户有权限访问的活动中查找
    @activity = accessible_activities.find_by(
      id: params[:id]
    )

    # 2. 活动不存在或没有访问权限
    head :not_found unless @activity
  end

  # PATCH /activities/:id
  # 处理活动更新请求
  def update
    # 1. 在当前用户有权限访问的活动中查找
    @activity = accessible_activities.find_by(
      id: params[:id]
    )

    # 2. 如果活动不存在或没有访问权限，结束请求
    return head :not_found unless @activity

    # 3. 调用 ActivityService 更新活动
    @activity = ActivityService.update(
      user: Current.user,
      activity: @activity,
      attributes: activity_params.to_h
    )

    # 4. 检查活动是否成功更新
    if @activity.errors.empty?

      # 4.1 更新成功，跳转至活动详情页面
      redirect_to activity_path(@activity),
                  notice: "Activity updated successfully.",
                  status: :see_other

    else

      # 4.2 更新失败，重新显示编辑页面及错误信息
      render :edit, status: 422

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

  # 检查当前用户是否为 Organizer
  def require_organizer
    head :forbidden unless Current.user.role == "organizer"
  end

  # ==================================================
  # 参数安全检查
  # ==================================================

  # 检查活动参数结构并限制允许提交的属性
  def activity_params
    params.expect(
      activity: [
        :title,
        :description,
        :location
      ]
    )
  end
end
