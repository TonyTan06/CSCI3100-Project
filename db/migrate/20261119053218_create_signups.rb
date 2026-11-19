
class CreateSignups < ActiveRecord::Migration[8.1]
  def change
    create_table :signups do |t|
      t.references :user, null: false, foreign_key: true
      t.references :shift, null: false, foreign_key: true
      t.string :status, null: false
      t.string :attendance_status, null: false, default: "pending"

      t.timestamps
    end

    # 防止同一个用户重复报名同一个班次
    add_index :signups, [:user_id, :shift_id], unique: true
  end
end
