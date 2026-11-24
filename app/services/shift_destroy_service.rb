class ShiftDestroyService
  # 处理 Organizer 的班次删除请求
  def self.call(user:, shift:)
    # 1. 开启数据库事务
    ActiveRecord::Base.transaction(requires_new: true) do
      # 2. 从数据库重新读取班次记录并获取锁
      shift.reload(lock: true)

      # 3. 检查当前用户是否为 Organizer
      if user.role != "organizer"
        shift.errors.add(
          :base,
          "must be an organizer"
        )

        next shift
      end

      # 4. 检查班次是否属于当前 Organizer 的组织
      if user.organization_id != shift.activity.organization_id
        shift.errors.add(
          :base,
          "can only delete shifts belonging to their own organization"
        )

        next shift
      end

      # 5. 检查班次是否存在任何报名记录
      if shift.signups.exists?
        shift.errors.add(
          :base,
          "cannot delete a shift with existing signup records"
        )

        next shift
      end

      # 6. 删除班次
      shift.destroy

      # 7. 返回班次删除结果
      shift
    end
  end
end
