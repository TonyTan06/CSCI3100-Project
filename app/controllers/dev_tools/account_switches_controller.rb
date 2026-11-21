
module DevTools
  class AccountSwitchesController < ApplicationController
    # 允许快速切换的测试账号白名单
    DEMO_EMAILS = %w[
      volunteer1@example.com
      volunteer2@example.com
      organizer1@example.com
      organizer2@example.com
    ].freeze

    # 仅允许本地开发环境使用账号切换功能
    before_action :ensure_local_development

    def create
      email = params[:email_address].to_s

      # 拒绝切换到白名单之外的账号
      unless DEMO_EMAILS.include?(email)
        redirect_to dashboard_path, alert: "Invalid test account."
        return
      end

      # 查找目标测试账号
      user = User.find_by(email_address: email)

      unless user
        redirect_to dashboard_path, alert: "Test account not found. Check your seeds."
        return
      end

      # 结束当前 Session，并为目标账号创建新 Session
      terminate_session
      start_new_session_for user

      # 切换成功后返回 Dashboard
      redirect_to dashboard_path,
                  notice: "Switched to #{user.email_address}.",
                  status: :see_other
    end

    private

    def ensure_local_development
      head :not_found unless Rails.env.development? && request.local?
    end
  end
end
