
require 'rails_helper'
require 'securerandom'
require 'timeout'

RSpec.describe "Signup concurrency", type: :model do
  # 仅对当前测试组关闭自动测试事务
  self.use_transactional_tests = false

  # ==================================================
  # 公共测试数据
  # ==================================================

  before do
    # 安全检查：只允许在测试环境中运行
    raise "Test environment required" unless Rails.env.test?

    # 确保当前测试没有被外层事务包裹
    expect(
      ActiveRecord::Base.lease_connection.open_transactions
    ).to eq(0)

    # 使用唯一标识避免与其他测试数据发生冲突
    @token = SecureRandom.hex(6)

    @users = []
    @shifts = []

    # 创建测试组织
    @organization = Organization.create!(
      name: "Concurrency Test #{@token}"
    )

    # 创建测试活动
    @activity = Activity.create!(
      title: "Campus Cleaning",
      description: "Concurrency testing activity",
      location: "CUHK Campus",
      organization: @organization
    )

    # 设置班次开始时间
    @start_time = Time.current.change(usec: 0) + 1.day

    # 创建两个 Volunteer
    @volunteer_a = create_volunteer("a")
    @volunteer_b = create_volunteer("b")

    # 创建容量为 1 的班次
    @shift = create_shift(
      start_time: @start_time,
      end_time: @start_time + 3.hours,
      capacity: 1
    )
  end

  # ==================================================
  # 清理测试数据
  # ==================================================

  after do
    # 安全检查：禁止在非测试环境中删除数据
    next unless Rails.env.test?

    # 由于本测试组关闭了自动事务回滚，
    # 因此需要手动清理本次测试创建的数据

    shift_ids = Array(@shifts).map(&:id)
    user_ids = Array(@users).map(&:id)

    # 按照外键依赖顺序清理数据
    Signup.where(shift_id: shift_ids).delete_all

    Shift.where(id: shift_ids).delete_all

    Activity.where(id: @activity.id).delete_all if @activity

    User.where(id: user_ids).delete_all

    if @organization
      Organization.where(id: @organization.id).delete_all
    end
  end

  # ==================================================
  # 辅助方法
  # ==================================================

  # 创建 Volunteer
  def create_volunteer(name)
    user = User.create!(
      email_address: "#{name}_#{@token}@example.com",
      password: "password123",
      role: "volunteer"
    )

    @users << user

    user
  end

  # 创建当前测试组织的 Organizer
  def create_organizer
    organizer = User.create!(
      email_address: "organizer_#{@token}@example.com",
      password: "password123",
      role: "organizer",
      organization: @organization
    )

    # 加入测试用户数组，确保测试结束后自动清理
    @users << organizer

    organizer
  end

  # 创建班次
  def create_shift(start_time:, end_time:, capacity:)
    shift = Shift.create!(
      activity: @activity,
      start_time: start_time,
      end_time: end_time,
      capacity: capacity
    )

    @shifts << shift

    shift
  end

  # 同时执行多个业务请求
  def run_concurrent_requests(requests)
    # 用于记录已经准备完成的线程
    ready_queue = Queue.new

    # 用于统一控制线程开始执行
    start_queue = Queue.new

    threads = []

    requests.each do |request|
      threads << Thread.new(request) do |operation|
        Rails.application.executor.wrap do
          # 为每个线程获取独立的数据库连接
          ActiveRecord::Base.connection_pool.with_connection do |connection|
            # 1. 在当前线程中重新读取用户和班次
            user = User.find(operation[:user_id])
            shift = Shift.find(operation[:shift_id])

            # 2. 通知主线程：当前线程已经准备完成
            ready_queue << connection.object_id

            # 3. 等待统一开始信号
            start_queue.pop

            # 4. 根据请求类型执行对应的 Service
            case operation.fetch(:action, :signup)

            # 4.1 执行报名操作
            when :signup

              result = SignupService.call(
                user: user,
                shift: shift
              )

            # 4.2 执行取消报名操作
            when :cancel

              signup = Signup.find(
                operation[:signup_id]
              )

              result = CancellationService.call(
                user: user,
                signup: signup
              )

            # 4.3 执行容量修改操作
            when :update_capacity

              result = ShiftUpdateService.call(
                user: user,
                shift: shift,
                attributes: {
                  capacity: operation[:capacity]
                }
              )

            # 4.4 拒绝未知操作
            else

              raise ArgumentError, "Unknown operation"

            end

            # 5. 返回业务执行结果
            {
              id: result.id,

              status: result.is_a?(Signup) ?
                result.status : nil,

              persisted: result.persisted?,

              errors: result.errors.full_messages,

              duplicate_error: result.errors.of_kind?(
                :user_id,
                :taken
              ),

              conflict_error: result.errors[:shift].include?(
                "overlaps with another confirmed signup"
              ),

              capacity_error: result.errors[:capacity].include?(
                "cannot be less than the number of confirmed signups"
              )
            }
          end
        end
      end
    end

    # 设置超时，避免测试无限等待
    Timeout.timeout(20) do
      # 等待所有线程准备完成
      connection_ids = requests.size.times.map do
        ready_queue.pop
      end

      # 检查各线程使用不同的数据库连接
      expect(connection_ids.uniq.size).to eq(
        requests.size
      )

      # 同时释放所有线程
      requests.size.times do
        start_queue << true
      end

      # 等待所有线程结束并获取结果
      threads.map(&:value)
    end

  ensure

    # 即使测试失败，也停止尚未结束的线程
    Array(threads).each do |thread|
      thread.kill if thread.alive?
    end

    # 确保线程结束后才进行数据库清理
    Array(threads).each do |thread|
      begin
        thread.join
      rescue StandardError
        # 工作线程异常由 thread.value 抛出
      end
    end
  end

  # ==================================================
  # 多线程并发报名测试
  # ==================================================

  # Test 1: 两个 Volunteer 同时争抢最后一个名额
  it "prevents overbooking when volunteers sign up concurrently" do
    # 1. 检查初始容量
    expect(@shift.capacity).to eq(1)
    expect(@shift.confirmed_count).to eq(0)

    # 2. 同时执行两个报名请求
    results = run_concurrent_requests([
      {
        user_id: @volunteer_a.id,
        shift_id: @shift.id
      },
      {
        user_id: @volunteer_b.id,
        shift_id: @shift.id
      }
    ])

    # 3. 检查两个请求均成功保存
    expect(
      results.all? do |result|
        result[:persisted] && result[:errors].empty?
      end
    ).to be true

    # 4. 检查一个 confirmed，一个 waitlisted
    expect(
      results.map { |result| result[:status] }
    ).to contain_exactly(
      "confirmed",
      "waitlisted"
    )

    # 5. 检查数据库中的正式报名人数
    expect(@shift.reload.confirmed_count).to eq(1)

    # 6. 检查候补队列人数
    expect(@shift.waitlist_queue.count).to eq(1)

    # 7. 检查剩余名额
    expect(@shift.available_slots).to eq(0)

    # 8. 检查报名记录总数
    expect(@shift.signups.count).to eq(2)
  end

  # Test 2: 同一个 Volunteer 同时提交两次报名
  it "prevents duplicate signups from concurrent requests" do
    # 1. 同一个 Volunteer 同时提交两次报名
    results = run_concurrent_requests([
      {
        user_id: @volunteer_a.id,
        shift_id: @shift.id
      },
      {
        user_id: @volunteer_a.id,
        shift_id: @shift.id
      }
    ])

    # 2. 获取成功和失败的报名结果
    successful_results = results.select do |result|
      result[:persisted] && result[:errors].empty?
    end

    failed_results = results.reject do |result|
      result[:persisted] && result[:errors].empty?
    end

    # 3. 只能有一个请求成功
    expect(successful_results.size).to eq(1)
    expect(failed_results.size).to eq(1)

    # 4. 失败的请求必须包含重复报名错误
    expect(
      failed_results.first[:duplicate_error]
    ).to be true

    # 5. 数据库只能存在一条报名记录
    expect(
      Signup.where(
        user_id: @volunteer_a.id,
        shift_id: @shift.id
      ).count
    ).to eq(1)

    # 6. 检查成功的报名为 confirmed
    expect(@shift.reload.confirmed_count).to eq(1)

    # 7. 不应该产生重复候补记录
    expect(@shift.waitlist_queue).to be_empty

    expect(@shift.signups.count).to eq(1)
  end

  # Test 3: 同一个 Volunteer 同时报名冲突班次
  it "prevents conflicting confirmed signups from concurrent requests" do
    # 1. 创建与原班次时间重叠的另一个班次
    conflicting_shift = create_shift(
      start_time: @start_time + 2.hours,
      end_time: @start_time + 5.hours,
      capacity: 1
    )

    # 2. 检查两个班次均有空余名额
    expect(@shift.available_slots).to eq(1)

    expect(
      conflicting_shift.available_slots
    ).to eq(1)

    # 3. 同一个 Volunteer 同时报名两个班次
    results = run_concurrent_requests([
      {
        user_id: @volunteer_a.id,
        shift_id: @shift.id
      },
      {
        user_id: @volunteer_a.id,
        shift_id: conflicting_shift.id
      }
    ])

    # 4. 获取成功和失败的报名结果
    successful_results = results.select do |result|
      result[:persisted] && result[:errors].empty?
    end

    failed_results = results.reject do |result|
      result[:persisted] && result[:errors].empty?
    end

    # 5. 只能有一个报名请求成功
    expect(successful_results.size).to eq(1)
    expect(failed_results.size).to eq(1)

    # 6. 成功的报名必须为 confirmed
    expect(
      successful_results.first[:status]
    ).to eq("confirmed")

    # 7. 失败请求必须包含时间冲突错误
    expect(
      failed_results.first[:conflict_error]
    ).to be true

    # 8. 检查数据库中只有一条正式报名
    expect(
      Signup.where(
        user_id: @volunteer_a.id,
        status: "confirmed"
      ).count
    ).to eq(1)

    # 9. 两个班次的正式报名总数只能为 1
    total_confirmed =
      @shift.reload.confirmed_count +
      conflicting_shift.reload.confirmed_count

    expect(total_confirmed).to eq(1)
  end

  # ==================================================
  # 跨业务并发测试
  # ==================================================

  # Test 4: 并发取消和报名时保护候补优先权
  it "preserves waitlist priority during concurrent cancellation and signup" do
    volunteer_c = create_volunteer("c")

    # 1. Volunteer A 占用唯一正式名额
    signup_a = SignupService.call(
      user: @volunteer_a,
      shift: @shift
    )

    # 2. Volunteer B 进入候补队列
    signup_b = SignupService.call(
      user: @volunteer_b,
      shift: @shift
    )

    expect(signup_a.status).to eq("confirmed")
    expect(signup_b.status).to eq("waitlisted")

    # 3. A 取消报名，同时 C 提交报名
    results = run_concurrent_requests([
      {
        action: :cancel,
        user_id: @volunteer_a.id,
        shift_id: @shift.id,
        signup_id: signup_a.id
      },
      {
        action: :signup,
        user_id: volunteer_c.id,
        shift_id: @shift.id
      }
    ])

    # 4. 检查两个请求均执行成功
    expect(
      results.all? do |result|
        result[:persisted] && result[:errors].empty?
      end
    ).to be true

    # 5. 查询 Volunteer C 的报名记录
    signup_c = Signup.find_by!(
      user: volunteer_c,
      shift: @shift
    )

    # 6. 检查候补优先权得到保护
    expect(signup_a.reload.status).to eq("cancelled")
    expect(signup_b.reload.status).to eq("confirmed")
    expect(signup_c.reload.status).to eq("waitlisted")

    # 7. 检查容量及候补队列
    expect(@shift.reload.confirmed_count).to eq(1)
    expect(@shift.available_slots).to eq(0)

    expect(@shift.waitlist_queue.to_a).to eq(
      [ signup_c ]
    )

    expect(@shift.signups.count).to eq(3)
  end

  # Test 5: 并发增加容量和报名时保护候补优先权
  it "preserves waitlist priority during concurrent capacity increase and signup" do
    organizer = create_organizer
    volunteer_c = create_volunteer("c")

    # 1. Volunteer A 占用唯一正式名额
    signup_a = SignupService.call(
      user: @volunteer_a,
      shift: @shift
    )

    # 2. Volunteer B 进入候补队列
    signup_b = SignupService.call(
      user: @volunteer_b,
      shift: @shift
    )

    expect(signup_a.status).to eq("confirmed")
    expect(signup_b.status).to eq("waitlisted")

    # 3. Organizer 增加容量，同时 C 提交报名
    results = run_concurrent_requests([
      {
        action: :update_capacity,
        user_id: organizer.id,
        shift_id: @shift.id,
        capacity: 2
      },
      {
        action: :signup,
        user_id: volunteer_c.id,
        shift_id: @shift.id
      }
    ])

    # 4. 检查两个请求均执行成功
    expect(
      results.all? do |result|
        result[:persisted] && result[:errors].empty?
      end
    ).to be true

    # 5. 查询 Volunteer C 的报名记录
    signup_c = Signup.find_by!(
      user: volunteer_c,
      shift: @shift
    )

    # 6. 检查原有候补用户优先获得名额
    expect(signup_a.reload.status).to eq("confirmed")
    expect(signup_b.reload.status).to eq("confirmed")
    expect(signup_c.reload.status).to eq("waitlisted")

    # 7. 检查班次容量及候补队列
    expect(@shift.reload.capacity).to eq(2)
    expect(@shift.confirmed_count).to eq(2)
    expect(@shift.available_slots).to eq(0)

    expect(@shift.waitlist_queue.to_a).to eq(
      [ signup_c ]
    )

    expect(@shift.signups.count).to eq(3)
  end

  # Test 6: 并发减少容量和报名时防止超额报名
  it "maintains valid capacity during concurrent capacity decrease and signup" do
    organizer = create_organizer

    # 1. 将初始容量设置为 2
    @shift.update!(capacity: 2)

    # 2. Volunteer A 占用一个正式名额
    signup_a = SignupService.call(
      user: @volunteer_a,
      shift: @shift
    )

    expect(signup_a.status).to eq("confirmed")
    expect(@shift.available_slots).to eq(1)

    # 3. Organizer 减少容量，同时 B 提交报名
    results = run_concurrent_requests([
      {
        action: :update_capacity,
        user_id: organizer.id,
        shift_id: @shift.id,
        capacity: 1
      },
      {
        action: :signup,
        user_id: @volunteer_b.id,
        shift_id: @shift.id
      }
    ])

    # 4. 获取两个请求的执行结果
    update_result = results[0]
    signup_result = results[1]

    # 5. Volunteer B 的报名应成功保存
    expect(signup_result[:persisted]).to be true
    expect(signup_result[:errors]).to be_empty

    signup_b = Signup.find_by!(
      user: @volunteer_b,
      shift: @shift
    )

    @shift.reload

    # 6. 根据不同执行顺序检查结果
    if @shift.capacity == 1

      # 情况 A：Organizer 先成功减少容量
      expect(update_result[:errors]).to be_empty
      expect(signup_b.status).to eq("waitlisted")

      expect(@shift.confirmed_count).to eq(1)
      expect(@shift.waitlist_queue.count).to eq(1)

    else

      # 情况 B：Volunteer B 先成功报名
      # 此时容量不允许降低至 1
      expect(@shift.capacity).to eq(2)

      expect(update_result[:capacity_error]).to be true
      expect(signup_b.status).to eq("confirmed")

      expect(@shift.confirmed_count).to eq(2)
      expect(@shift.waitlist_queue).to be_empty

    end

    # 7. 无论执行顺序如何，都不能超额报名
    expect(@shift.confirmed_count).to be <= @shift.capacity

    # 8. 检查其他报名状态及班次数据
    expect(signup_a.reload.status).to eq("confirmed")
    expect(@shift.available_slots).to eq(0)
    expect(@shift.signups.count).to eq(2)
  end
end
