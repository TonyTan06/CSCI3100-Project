
class Activity < ApplicationRecord
  belongs_to :organization
  has_many :shifts

  # 活动必须拥有名称
  validates :title, presence: true

  # 活动必须拥有描述
  validates :description, presence: true

  # 活动必须拥有地点
  validates :location, presence: true
end
