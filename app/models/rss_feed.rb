# frozen_string_literal: true

# RSS Feed configuration for automated news scanning
class RssFeed < ApplicationRecord
  has_many :rss_feed_items, dependent: :destroy
  has_many :stories, through: :rss_feed_items

  validates :name, presence: true
  validates :url, presence: true, uniqueness: true,
    format: {with: URI::DEFAULT_PARSER.make_regexp(%w[http https])}

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :due_for_fetch, -> {
    active.where("last_fetched_at IS NULL OR last_fetched_at < ?", 1.hour.ago)
  }
  scope :by_category, ->(cat) { where(category: cat) }

  # Settings accessors
  def default_tags
    settings&.dig("default_tags") || []
  end

  def default_tags=(tags)
    self.settings = (settings || {}).merge("default_tags" => tags)
  end

  def relevance_keywords
    settings&.dig("relevance_keywords") || []
  end

  def relevance_keywords=(keywords)
    self.settings = (settings || {}).merge("relevance_keywords" => keywords)
  end

  def priority
    settings&.dig("priority") || 0
  end

  def priority=(value)
    self.settings = (settings || {}).merge("priority" => value)
  end

  # Mark feed as fetched
  def mark_fetched!(error: nil)
    update!(
      last_fetched_at: Time.current,
      last_error: error,
      fetch_count: fetch_count + 1
    )
  end

  # Increment story count when a story is created from this feed
  def increment_story_count!
    increment!(:story_count)
  end

  # Check if feed has errors
  def has_error?
    last_error.present?
  end

  # Statistics
  def pending_items_count
    rss_feed_items.where(processing_status: "pending").count
  end

  def relevant_items_count
    rss_feed_items.where(processing_status: "relevant").count
  end
end
