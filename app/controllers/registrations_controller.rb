
class RegistrationsController < ApplicationController
  # 允许未登录用户访问注册页面和提交注册请求
  allow_unauthenticated_access only: [ :new, :create ]

  # 显示用户注册页面
  def new
  end

  # 处理用户提交的注册信息
  def create
    @user = User.new(user_params)

    # 验证用户信息并保存到数据库
    if @user.save
      # 注册成功后跳转到登录页面
      redirect_to new_session_path, notice: "Account created successfully."
    else
      # 注册失败后重新显示注册页面
      render :new, status: :unprocessable_content
    end
  end

  private

  def user_params
    params.require(:user).permit(
      :email_address,
      :password,
      :password_confirmation
    )
  end
end
