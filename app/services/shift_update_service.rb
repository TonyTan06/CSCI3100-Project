
class ShiftUpdateService

  # 处理 Organizer 的班次修改请求
  def self.call(user:, shift:, attributes:)

    # 1. 从数据库重新读取班次记录
    shift.reload

    # 2. 检查当前用户是否为 Organizer
    if user.role != "organizer"
      shift.errors.add(
        :base,
        "must be an organizer"
      )

      return shift
    end

    # 3. 检查班次是否属于当前 Organizer 的组织
    if user.organization_id != shift.activity.organization_id
      shift.errors.add(
        :base,
        "can only update shifts belonging to their own organization"
      )

      return shift
    end

    # 4. 限制允许修改的属性
    allowed_attributes = attributes.symbolize_keys.slice(
      :start_time,
      :end_time,
      :capacity
    )

    # 5. 保存修改前的班次容量
    original_capacity = shift.capacity

    # 6. 使用数据库事务执行班次修改及自动递补
    ActiveRecord::Base.transaction(requires_new: true) do

      # 6.1 尝试修改班次属性
      if shift.update(allowed_attributes)

        # 6.2 如果班次容量增加，则触发自动递补
        if shift.capacity > original_capacity

          WaitlistService.call(
            shift: shift
          )

        end
      end
    end

    # 7. 返回班次修改结果
    shift
  end
end
