
Rails.application.routes.draw do
  resource :session
  resource :registration, only: [ :new, :create ]
  resources :passwords, param: :token

  # 本地开发专用：快速切换测试账号
  if Rails.env.development?
    post "dev/switch_account",
         to: "dev_tools/account_switches#create",
         as: :dev_switch_account
  end

  # 活动、班次、报名及出勤管理路由
  resources :activities, only: [ :index, :show, :new, :create, :edit, :update ] do
    resources :shifts, only: [ :index, :show, :new, :create, :edit, :update ] do
      resources :signups, only: [ :create, :destroy ]
      resources :attendances, only: [ :index, :update ]
    end
  end
  # Dashboard 路由
  resource :dashboard, only: [ :show ]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  # 临时首页：后续实现 VolunteerHub Dashboard 后替换
  root "dashboards#show"
end
