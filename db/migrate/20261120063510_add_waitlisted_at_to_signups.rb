
class AddWaitlistedAtToSignups < ActiveRecord::Migration[8.1]
  def up
    # 1. 添加进入候补队列的时间字段
    add_column :signups, :waitlisted_at, :datetime

    # 2. 为已有的候补报名记录补充初始候补时间
    execute <<~SQL
      UPDATE signups
      SET waitlisted_at = created_at
      WHERE status = 'waitlisted'
    SQL

    # 3. 创建联合索引，提高候补队列查询效率
    add_index :signups,
              [ :shift_id, :status, :waitlisted_at ],
              name: "index_signups_on_waitlist_order"
  end

  def down
    # 1. 删除候补队列查询索引
    remove_index :signups,
                 name: "index_signups_on_waitlist_order"

    # 2. 删除候补时间字段
    remove_column :signups, :waitlisted_at
  end
end
