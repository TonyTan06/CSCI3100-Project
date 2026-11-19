
class Organization < ApplicationRecord
  has_many :users
  has_many :activities

  validates :name, presence: true
end
