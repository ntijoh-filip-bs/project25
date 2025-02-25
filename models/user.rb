class User < ActiveRecord::Base
  has_many :animals
  has_many :carts
  has_many :orders
  validates :username, presence: true, uniqueness: true
  has_secure_password
end