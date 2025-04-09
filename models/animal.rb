require_relative 'user.rb'

class Animal < ActiveRecord::Base
  belongs_to :user
  belongs_to :category
  validates :name, :price, presence: true
end