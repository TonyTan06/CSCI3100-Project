
class WaitlistService
  # 自动递补当前班次中的合格候补用户
  def self.call(shift:)
    # 1. 开启数据库事务
    ActiveRecord::Base.transaction(requires_new: true) do
      # 2. 从数据库重新读取班次记录
      shift.reload

      # 3. 初始化用于保存成功递补记录的数组
      promoted_signups = []

      # 4. 如果班次已经满员，则直接结束递补
      next promoted_signups if shift.full?

      # 5. 获取按照 FIFO 原则排列的候补队列
      waitlisted_signups = shift.waitlist_queue

      # 6. 按照候补顺序遍历所有报名记录
      waitlisted_signups.each do |signup|
        # 6.1 如果班次已经满员，则停止递补
        break if shift.full?

        # 6.2 尝试将当前候补报名转为正式报名
        if signup.update(status: "confirmed")

          # 6.3 如果递补成功，则加入结果数组
          promoted_signups << signup

        else

          # 6.4 如果递补失败，则恢复对象的数据库状态
          signup.reload

        end
      end

      # 7. 返回所有成功递补的报名记录
      promoted_signups
    end
  end
end
