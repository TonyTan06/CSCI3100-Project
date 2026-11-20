
class CancellationService

  # 处理 Volunteer 的取消报名请求
  def self.call(user:, signup:)

    # 1. 从数据库重新读取报名记录
    # 确保使用最新的报名状态并清除旧的错误信息
    signup.reload

    # 2. 检查当前用户是否为 Volunteer
    if user.role != "volunteer"
      signup.errors.add(
        :user,
        "must be a volunteer"
      )

      return signup
    end

    # 3. 检查报名记录是否属于当前 Volunteer
    if signup.user_id != user.id
      signup.errors.add(
        :user,
        "can only cancel their own signups"
      )

      return signup
    end

    # 4. 检查报名是否已经被取消
    if signup.status == "cancelled"
      signup.errors.add(
        :status,
        "has already been cancelled"
      )

      return signup
    end

    # 5. 保存取消前的报名状态
    original_status = signup.status

    # 6. 使用数据库事务执行取消及自动递补
    ActiveRecord::Base.transaction(requires_new: true) do

      # 6.1 尝试将报名状态修改为 cancelled
      if signup.update(status: "cancelled")

        # 6.2 如果取消的是正式报名，则触发自动递补
        if original_status == "confirmed"

          WaitlistService.call(
            shift: signup.shift
          )

        end
      end
    end

    # 7. 返回取消报名结果
    signup
  end
end
