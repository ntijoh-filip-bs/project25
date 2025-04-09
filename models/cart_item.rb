require_relative 'cart.rb'
require_relative 'animal.rb'

class CartItem < ActiveRecord::Base
  belongs_to :cart
  belongs_to :animal
end