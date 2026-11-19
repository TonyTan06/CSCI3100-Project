
class CreateActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :activities do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.string :location, null: false
      t.references :organization, null: false, foreign_key: true

      t.timestamps
    end
  end
end
