
class ActivityService
  # 创建活动
  def self.create(user:, attributes:)
    # 1. 初始化 Activity 对象
    activity = Activity.new

    # 2. 检查当前用户是否为 Organizer
    if user.role != "organizer"
      activity.errors.add(
        :base,
        "must be an organizer"
      )

      return activity
    end

    # 3. 筛选允许设置的活动属性
    allowed_attributes = attributes.symbolize_keys.slice(
      :title,
      :description,
      :location
    )

    # 4. 设置活动属性
    activity.assign_attributes(allowed_attributes)

    # 5. 自动分配 Organizer 所属的组织
    activity.organization = user.organization

    # 6. 保存活动并执行 Model 验证
    activity.save

    # 7. 返回活动创建结果
    activity
  end

  # 修改活动
  def self.update(user:, activity:, attributes:)
    # 1. 从数据库重新读取活动记录
    activity.reload

    # 2. 检查当前用户是否为 Organizer
    if user.role != "organizer"
      activity.errors.add(
        :base,
        "must be an organizer"
      )

      return activity
    end

    # 3. 检查活动是否属于当前 Organizer 的组织
    if user.organization_id != activity.organization_id
      activity.errors.add(
        :base,
        "can only update activities belonging to their own organization"
      )

      return activity
    end

    # 4. 筛选允许修改的活动属性
    allowed_attributes = attributes.symbolize_keys.slice(
      :title,
      :description,
      :location
    )

    # 5. 修改活动并执行 Model 验证
    activity.update(allowed_attributes)

    # 6. 返回活动修改结果
    activity
  end
end
