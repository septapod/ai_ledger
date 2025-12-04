# frozen_string_literal: true

require "rss"
require "open-uri"

# Fetches and processes RSS feed items
class RssFetcher
  def initialize(feed)
    @feed = feed
  end

  # Fetch new items from the feed and process them
  def fetch_and_process
    items = fetch_items
    process_items(items)
    @feed.mark_fetched!
    items.count
  rescue StandardError => e
    @feed.mark_fetched!(error: e.message)
    Rails.logger.error("RSS fetch error for #{@feed.name}: #{e.message}")
    raise
  end

  private

  def fetch_items
    content = URI.open(@feed.url, read_timeout: 30, open_timeout: 10).read
    rss = RSS::Parser.parse(content, false)

    return [] unless rss

    rss.items.map do |item|
      {
        guid: extract_guid(item),
        url: extract_url(item),
        title: extract_title(item),
        content: extract_content(item),
        published_at: extract_date(item)
      }
    end.compact
  end

  def extract_guid(item)
    if item.respond_to?(:guid) && item.guid
      item.guid.respond_to?(:content) ? item.guid.content : item.guid.to_s
    else
      item.link
    end
  end

  def extract_url(item)
    item.link
  end

  def extract_title(item)
    item.title&.strip
  end

  def extract_content(item)
    # Try various RSS content fields
    content = if item.respond_to?(:content_encoded) && item.content_encoded
      item.content_encoded
    elsif item.respond_to?(:description) && item.description
      item.description
    elsif item.respond_to?(:summary) && item.summary
      item.summary
    else
      ""
    end

    # Strip HTML tags for relevance scoring
    ActionController::Base.helpers.strip_tags(content).to_s.strip
  end

  def extract_date(item)
    item.pubDate || item.try(:dc_date)
  end

  def process_items(items)
    items.each do |item_data|
      # Skip if already processed
      next if @feed.rss_feed_items.exists?(guid: item_data[:guid])
      next if item_data[:url].blank?

      feed_item = @feed.rss_feed_items.create!(
        item_data.merge(processing_status: "pending")
      )

      score_and_classify(feed_item)
    end
  end

  def score_and_classify(feed_item)
    # Check for duplicates first
    if feed_item.already_submitted?
      feed_item.mark_duplicate!
      return
    end

    # Score relevance
    scorer = RelevanceScorer.new(
      title: feed_item.title,
      content: feed_item.content,
      url: feed_item.url
    )

    threshold = bot_user&.relevance_threshold || 0.5
    notes = scorer.breakdown.to_json

    if scorer.relevant?(threshold: threshold)
      feed_item.mark_relevant!(scorer.score, notes)
    else
      feed_item.mark_irrelevant!(scorer.score, notes)
    end
  end

  def bot_user
    @bot_user ||= User.ai_agent
  end
end
