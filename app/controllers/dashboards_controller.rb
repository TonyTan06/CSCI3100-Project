
class DashboardsController < ApplicationController
  # ==================================================
  # Dashboard 主页
  # ==================================================

  # GET /dashboard
  # 根据当前用户角色显示对应的 Dashboard
  def show
    if Current.user.role == "volunteer"
      load_volunteer_dashboard
      render :volunteer
    elsif Current.user.role == "organizer"
      load_organizer_dashboard
      render :organizer
    else
      head :forbidden
    end
  end

  private

  # ==================================================
  # Volunteer Dashboard
  # ==================================================

  # 获取当前 Volunteer 的报名记录及统计数据
  def load_volunteer_dashboard
    # 1. 查询当前用户的所有报名记录
    @signups = Current.user.signups
      .joins(:shift)
      .includes(shift: { activity: :organization })
      .order("shifts.start_time ASC", "signups.id ASC")
      .to_a

    # 2. 计算个人报名统计
    @signup_summary = {
      confirmed: @signups.count { |signup| signup.status == "confirmed" },
      waitlisted: @signups.count { |signup| signup.status == "waitlisted" },
      cancelled: @signups.count { |signup| signup.status == "cancelled" }
    }
  end

  # ==================================================
  # Organizer Dashboard
  # ==================================================

  # 获取当前 Organizer 所属组织的活动及统计数据
  def load_organizer_dashboard
    # 1. 获取当前用户所属组织
    @organization = Current.user.organization

    # 2. 查询组织所属活动并提前加载班次及报名记录
    @activities = @organization.activities
      .includes(shifts: :signups)
      .order(:id)
      .to_a

    # 3. 对每个活动的班次进行排序
    @shifts_by_activity = {}
    @activities.each do |activity|
      @shifts_by_activity[activity.id] = activity.shifts.sort_by do |shift|
        [shift.start_time, shift.id]
      end
    end

    # 4. 获取当前组织的所有班次及报名记录
    shifts = @shifts_by_activity.values.flatten
    signups = shifts.flat_map(&:signups)

    # 5. 计算组织整体统计
    @organization_summary = {
      activities: @activities.size,
      shifts: shifts.size,
      confirmed: signups.count { |signup| signup.status == "confirmed" },
      waitlisted: signups.count { |signup| signup.status == "waitlisted" },
      cancelled: signups.count { |signup| signup.status == "cancelled" }
    }

    # 6. 计算每个班次的报名及出勤统计
    @shift_summaries = {}
    shifts.each do |shift|
      @shift_summaries[shift.id] = calculate_shift_summary(shift)
    end
  end

  # ==================================================
  # 班次统计
  # ==================================================

  # 计算指定班次的容量、报名及出勤统计
  def calculate_shift_summary(shift)
    # 1. 获取班次报名记录
    signups = shift.signups.to_a

    # 2. 筛选正式报名人员
    confirmed_signups = signups.select do |signup|
      signup.status == "confirmed"
    end

    # 3. 返回班次统计数据
    {
      capacity: shift.capacity,
      confirmed: confirmed_signups.size,
      available: shift.capacity - confirmed_signups.size,
      waitlisted: signups.count { |signup| signup.status == "waitlisted" },
      present: confirmed_signups.count { |signup| signup.attendance_status == "present" },
      absent: confirmed_signups.count { |signup| signup.attendance_status == "absent" },
      pending: confirmed_signups.count { |signup| signup.attendance_status == "pending" }
    }
  end
end
