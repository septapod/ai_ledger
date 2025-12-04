# frozen_string_literal: true

# Bot user functionality for AI Agent automated submissions
module BotUser
  extend ActiveSupport::Concern

  included do
    scope :bot_users, -> { where(is_bot: true) }
    scope :active_bots, -> { bot_users.where(bot_enabled: true) }

    has_many :approved_stories,
      class_name: "Story",
      foreign_key: "approved_by_user_id",
      inverse_of: :approved_by,
      dependent: :nullify
  end

  class_methods do
    # Get the AI agent bot user
    def ai_agent
      find_by(username: Rails.application.config.ai_ledger.bot_username)
    end
  end

  # Check if this is a bot user
  def is_bot_user?
    is_bot == true
  end

  # Check if bot can auto-submit stories
  def can_auto_submit?
    is_bot? && bot_enabled? && bot_auto_submit_enabled?
  end

  # Check if bot has reached daily submission limit
  def can_submit_more_today?
    return true unless is_bot?
    daily_submission_count < max_daily_submissions
  end

  # Count stories submitted in last 24 hours
  def daily_submission_count
    stories.where("created_at > ?", 24.hours.ago).count
  end

  # Bot settings accessors
  def bot_auto_submit_enabled?
    bot_settings&.dig("auto_submit_enabled") == true
  end

  def max_daily_submissions
    bot_settings&.dig("max_daily_submissions") || 50
  end

  def relevance_threshold
    bot_settings&.dig("relevance_threshold") || 0.5
  end

  def preferred_tags
    bot_settings&.dig("preferred_tags") || []
  end

  def excluded_domains
    bot_settings&.dig("excluded_domains") || []
  end

  # Update bot settings
  def update_bot_settings(new_settings)
    self.bot_settings = (bot_settings || {}).merge(new_settings.stringify_keys)
    save
  end
end
