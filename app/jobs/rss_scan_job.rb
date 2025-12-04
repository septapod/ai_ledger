# frozen_string_literal: true

# Orchestrates RSS feed scanning - runs hourly
class RssScanJob < ApplicationJob
  queue_as :default

  def perform
    return unless rss_scanning_enabled?

    Rails.logger.info "[RssScanJob] Starting RSS scan..."

    feeds_due = RssFeed.due_for_fetch
    Rails.logger.info "[RssScanJob] Found #{feeds_due.count} feeds due for fetching"

    feeds_due.find_each do |feed|
      RssFeedFetchJob.perform_later(feed.id)
    end

    Rails.logger.info "[RssScanJob] Queued #{feeds_due.count} feed fetch jobs"
  end

  private

  def rss_scanning_enabled?
    Rails.application.config.ai_ledger.rss_scan_enabled
  end
end
