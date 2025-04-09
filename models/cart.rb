require_relative 'user.rb'
require_relative 'cart_item.rb'
require_relative 'animal.rb'

class Cart < ActiveRecord::Base
  belongs_to :user
  has_many :cart_items
  has_many :animals, through: :cart_items
end