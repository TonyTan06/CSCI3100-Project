
class AttendanceService

  # 处理 Organizer 的出勤管理请求
  def self.call(user:, signup:, attendance_status:)

    # 1. 开启数据库事务
    ActiveRecord::Base.transaction(requires_new: true) do

      # 2. 从数据库重新读取报名记录
      signup.reload

      # 3. 检查当前用户是否为 Organizer
      if user.role != "organizer"
        signup.errors.add(
          :base,
          "must be an organizer"
        )

        next signup
      end

      # 4. 检查报名记录是否属于当前 Organizer 的组织
      if user.organization_id !=
         signup.shift.activity.organization_id

        signup.errors.add(
          :base,
          "can only manage attendance for their own organization"
        )

        next signup
      end

      # 5. 检查报名记录是否为正式报名
      if signup.status != "confirmed"
        signup.errors.add(
          :status,
          "must be confirmed to manage attendance"
        )

        next signup
      end

      # 6. 更新出勤状态
      signup.update(
        attendance_status: attendance_status
      )

      # 7. 返回出勤修改结果
      signup

    end
  end
end
