
class CancellationService
  # 处理 Volunteer 的取消报名请求
  def self.call(user:, signup:)
    # 1. 开启数据库事务
    ActiveRecord::Base.transaction(requires_new: true) do
      # 2. 从数据库重新读取报名记录
      signup.reload

      # 3. 检查当前用户是否为 Volunteer
      if user.role != "volunteer"
        signup.errors.add(
          :user,
          "must be a volunteer"
        )

        next signup
      end

      # 4. 检查报名记录是否属于当前 Volunteer
      if signup.user_id != user.id
        signup.errors.add(
          :user,
          "can only cancel their own signups"
        )

        next signup
      end

      # 5. 检查报名是否已经取消
      if signup.status == "cancelled"
        signup.errors.add(
          :status,
          "has already been cancelled"
        )

        next signup
      end

      # 6. 保存取消前的报名状态
      original_status = signup.status

      # 7. 尝试取消报名
      if signup.update(status: "cancelled")

        # 7.1 取消正式报名后触发自动递补
        if original_status == "confirmed"

          WaitlistService.call(
            shift: signup.shift
          )

        end
      end

      # 8. 返回取消报名结果
      signup
    end
  end
end
