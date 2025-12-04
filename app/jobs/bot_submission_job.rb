# frozen_string_literal: true

# Submits relevant RSS items as stories via the bot user
class BotSubmissionJob < ApplicationJob
  queue_as :default

  def perform
    return unless bot_enabled?

    Rails.logger.info "[BotSubmissionJob] Starting bot submission run..."

    submitted = 0
    skipped = 0

    RssFeedItem.ready_to_submit.find_each do |item|
      # Check if bot can still submit
      unless User.ai_agent&.can_submit_more_today?
        Rails.logger.info "[BotSubmissionJob] Daily limit reached, stopping"
        break
      end

      result = BotStorySubmitter.new(item).submit!

      if result[:success]
        submitted += 1
        Rails.logger.info "[BotSubmissionJob] Submitted: #{item.title&.truncate(50)}"
      else
        skipped += 1
        Rails.logger.warn "[BotSubmissionJob] Skipped: #{item.title&.truncate(50)} - #{result[:error]}"
      end

      # Rate limit: small delay between submissions
      sleep(2)
    end

    Rails.logger.info "[BotSubmissionJob] Completed: #{submitted} submitted, #{skipped} skipped"
  end

  private

  def bot_enabled?
    bot = User.ai_agent
    return false unless bot
    return false unless bot.bot_enabled?
    return false unless bot.can_auto_submit?
    true
  end
end
