class Order < ActiveRecord::Base
  belongs_to :user
  has_many :order_items
  has_many :animals, through: :order_items
end