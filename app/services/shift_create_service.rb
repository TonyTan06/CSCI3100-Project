
class ShiftCreateService

  # 创建活动班次
  def self.call(user:, activity:, attributes:)

    # 1. 初始化 Shift 对象
    shift = Shift.new

    # 2. 检查当前用户是否为 Organizer
    if user.role != "organizer"
      shift.errors.add(
        :base,
        "must be an organizer"
      )

      return shift
    end

    # 3. 从数据库重新读取 Activity
    activity.reload

    # 4. 检查活动是否属于当前 Organizer 的组织
    if user.organization_id != activity.organization_id
      shift.errors.add(
        :base,
        "can only create shifts for activities belonging to their own organization"
      )

      return shift
    end

    # 5. 筛选允许设置的班次属性
    allowed_attributes = attributes.symbolize_keys.slice(
      :start_time,
      :end_time,
      :capacity
    )

    # 6. 设置班次属性
    shift.assign_attributes(allowed_attributes)

    # 7. 设置经过权限验证的所属 Activity
    shift.activity = activity

    # 8. 保存班次并执行 Model 验证
    shift.save

    # 9. 返回班次创建结果
    shift
  end
end
