
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  belongs_to :organization, optional: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true
  validates :email_address, uniqueness: { case_sensitive: false }
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :role, inclusion: { in: ["volunteer", "organizer"] }
  # Organizer 必须属于一个 Organization
  validates :organization, presence: true, if: -> { role == "organizer" }
end
