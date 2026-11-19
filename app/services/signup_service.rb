
class SignupService

  # 处理 Volunteer 的班次报名请求
  def self.call(user:, shift:)

    # 1. 根据班次是否满员自动判断报名状态
    if shift.full?
      status = "waitlisted"
    else
      status = "confirmed"
    end

    # 2. 查询当前 Volunteer 是否存在已取消的报名记录
    existing_signup = Signup.find_by(
      user: user,
      shift: shift,
      status: "cancelled"
    )

    # 3. 根据是否存在已取消的报名记录进行处理
    if existing_signup

      # 3.1 复用原有的报名记录
      signup = existing_signup

      # 3.2 重新设置报名状态
      signup.status = status

      # 3.3 重置出勤状态
      signup.attendance_status = "pending"

    else

      # 3.4 创建一个新的 Signup 对象
      signup = Signup.new(
        user: user,
        shift: shift,
        status: status
      )

    end

    # 4. 将报名记录保存至数据库
    signup.save

    # 5. 返回 Signup 对象
    signup
  end
end
