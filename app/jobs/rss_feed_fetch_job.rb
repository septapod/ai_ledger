# frozen_string_literal: true

# Fetches a single RSS feed and processes its items
class RssFeedFetchJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 5.minutes, attempts: 3

  def perform(feed_id)
    feed = RssFeed.find_by(id: feed_id)
    return unless feed&.active?

    Rails.logger.info "[RssFeedFetchJob] Fetching feed: #{feed.name}"

    fetcher = RssFetcher.new(feed)
    items_count = fetcher.fetch_and_process

    Rails.logger.info "[RssFeedFetchJob] Processed #{items_count} items from #{feed.name}"
  rescue StandardError => e
    Rails.logger.error "[RssFeedFetchJob] Error fetching #{feed&.name}: #{e.message}"
    raise
  end
end
