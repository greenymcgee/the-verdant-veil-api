class Genre < ApplicationRecord
  has_and_belongs_to_many :games

  validates :igdb_id, presence: true

  scope(:with_games, -> { joins(:games).merge(Game.published).distinct })
end
