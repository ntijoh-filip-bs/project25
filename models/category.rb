class Category < ActiveRecord::Base
  has_many :animals
  validates :name, presence: true, uniqueness: true
end