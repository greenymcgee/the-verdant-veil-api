class Game < ApplicationRecord
  after_update :delete_cache

  mount_uploader :banner_image, BannerImageUploader

  has_and_belongs_to_many :age_ratings
  has_many :artworks, dependent: :destroy
  has_one :cover, dependent: :destroy
  has_and_belongs_to_many :franchises
  has_and_belongs_to_many :game_engines
  has_and_belongs_to_many :game_modes
  has_and_belongs_to_many :genres
  has_many :involved_companies, dependent: :destroy
  has_and_belongs_to_many :platforms
  has_and_belongs_to_many :player_perspectives
  has_many :release_dates, dependent: :destroy
  has_many :screenshots, dependent: :destroy
  has_and_belongs_to_many :themes
  has_many :websites, dependent: :destroy
  has_many :game_videos, dependent: :destroy

  scope(
    :by_query,
    ->(query) do
      if query.present?
        where("games.name ILIKE ?", "%#{sanitize_sql_like(query)}%")
      end
    end,
  )

  scope(
    :by_companies,
    ->(slugs) do
      return if slugs.blank?

      joins(involved_companies: :company).where(
        companies: {
          slug: slugs,
        },
      ).distinct
    end,
  )

  scope(
    :by_genres,
    ->(slugs) do
      return if slugs.blank?

      joins(:genres).where(genres: { slug: slugs }).distinct
    end,
  )

  scope(
    :by_platforms,
    ->(slugs) do
      return if slugs.blank?

      joins(:platforms).where(platforms: { slug: slugs }).distinct
    end,
  )

  scope :currently_playing, -> { where(currently_playing: true) }

  scope(
    :most_recent_ps,
    -> do
      joins(:platforms)
        .where(platforms: { slug: "ps" })
        .order(created_at: :desc)
        .distinct
        .limit(10)
    end,
  )

  scope(
    :most_recent_snes,
    -> do
      joins(:platforms)
        .where(platforms: { slug: "snes" })
        .order(created_at: :desc)
        .distinct
        .limit(10)
    end,
  )

  scope(
    :published,
    -> do
      where("published_at IS NOT NULL AND published_at <= ?", Time.current)
    end,
  )

  validates :igdb_id, presence: true

  def developers
    developer_involved_companies =
      involved_companies.where(is_developer: true).includes([:company])
    developer_involved_companies.map do |involved_company|
      involved_company.company
    end
  end

  def porters
    porter_involved_companies =
      involved_companies.where(is_porter: true).includes([:company])
    porter_involved_companies.map do |involved_company|
      involved_company.company
    end
  end

  def published?
    return false if published_at.blank?

    published_at < Time.current
  end

  def publishers
    publisher_involved_companies =
      involved_companies.where(is_publisher: true).includes([:company])
    publisher_involved_companies.map do |involved_company|
      involved_company.company
    end
  end

  def supporters
    supporter_involved_companies =
      involved_companies.where(is_supporter: true).includes([:company])
    supporter_involved_companies.map do |involved_company|
      involved_company.company
    end
  end

  def self.scope_map
    {
      "currently_playing" => :currently_playing,
      "ps" => :most_recent_ps,
      "snes" => :most_recent_snes,
    }
  end

  def self.unset_currently_playing!
    transaction do
      where(currently_playing: true).update_all(currently_playing: false)
    end
  end

  private

  def delete_cache
    Rails.cache.delete("game/#{slug}/show")
  end
end
