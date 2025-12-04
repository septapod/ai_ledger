# frozen_string_literal: true

# Individual items fetched from RSS feeds
class RssFeedItem < ApplicationRecord
  belongs_to :rss_feed
  belongs_to :story, optional: true

  PROCESSING_STATUSES = %w[pending relevant irrelevant duplicate submitted error].freeze

  validates :guid, presence: true, uniqueness: {scope: :rss_feed_id}
  validates :url, presence: true
  validates :processing_status, inclusion: {in: PROCESSING_STATUSES}

  scope :pending, -> { where(processing_status: "pending") }
  scope :relevant, -> { where(processing_status: "relevant") }
  scope :irrelevant, -> { where(processing_status: "irrelevant") }
  scope :duplicate, -> { where(processing_status: "duplicate") }
  scope :submitted, -> { where(processing_status: "submitted") }
  scope :errored, -> { where(processing_status: "error") }
  scope :ready_to_submit, -> { relevant }
  scope :unprocessed, -> { pending }

  # Check if this URL has already been submitted as a story
  def already_submitted?
    normalized = normalize_url(url)
    Story.where(url: url).exists? ||
      Story.where(normalized_url: normalized).exists?
  end

  # Get normalized URL for comparison
  def normalized_url
    @normalized_url ||= normalize_url(url)
  end

  # Status checks
  def pending?
    processing_status == "pending"
  end

  def relevant?
    processing_status == "relevant"
  end

  def submitted?
    processing_status == "submitted"
  end

  # Mark as relevant with score
  def mark_relevant!(score, notes = nil)
    update!(
      processing_status: "relevant",
      relevance_score: score,
      processing_notes: notes
    )
  end

  # Mark as irrelevant with score
  def mark_irrelevant!(score, notes = nil)
    update!(
      processing_status: "irrelevant",
      relevance_score: score,
      processing_notes: notes
    )
  end

  # Mark as duplicate
  def mark_duplicate!(notes = nil)
    update!(
      processing_status: "duplicate",
      processing_notes: notes || "URL already submitted"
    )
  end

  # Mark as submitted with story reference
  def mark_submitted!(created_story)
    update!(
      processing_status: "submitted",
      story: created_story
    )
    rss_feed.increment_story_count!
  end

  # Mark as error
  def mark_error!(error_message)
    update!(
      processing_status: "error",
      processing_notes: error_message
    )
  end

  private

  def normalize_url(input_url)
    # Simple URL normalization - remove trailing slashes, www, etc.
    uri = URI.parse(input_url)
    host = uri.host&.sub(/^www\./, "")
    path = uri.path&.chomp("/")
    "#{uri.scheme}://#{host}#{path}"
  rescue URI::InvalidURIError
    input_url
  end
end
