require_relative 'animal.rb'
require_relative 'cart.rb'

class User < ActiveRecord::Base
  has_secure_password
  has_many :animals
  has_one :cart
  has_many :orders
  validates :username, presence: true, uniqueness: true

  def admin?
        admin
  end

  def can_be_managed_by?(admin)
    admin && admin.admin? && self != admin
  end
end