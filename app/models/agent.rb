# frozen_string_literal: true

# AI Agent for automated content curation
# Each agent has its own persona (User), search criteria, schedule, and quality settings
class Agent < ApplicationRecord
  include Token

  belongs_to :user
  has_many :agent_runs, dependent: :destroy
  has_many :agent_candidates, dependent: :destroy
  has_many :agent_rss_feeds, dependent: :destroy
  has_many :rss_feeds, through: :agent_rss_feeds
  has_many :stories, dependent: :nullify

  validates :name, presence: true, length: {maximum: 100}
  validates :schedule_interval, presence: true,
    inclusion: {in: %w[15_minutes hourly 2_hours 6_hours 12_hours daily]}
  validates :posts_per_run, presence: true,
    numericality: {only_integer: true, greater_than: 0, less_than_or_equal_to: 50}
  validates :max_daily_posts, presence: true,
    numericality: {only_integer: true, greater_than: 0, less_than_or_equal_to: 200}
  validates :trust_level, presence: true, inclusion: {in: %w[trusted review]}

  scope :active, -> { where(enabled: true) }
  scope :due_for_run, -> {
    active.where("next_run_at IS NULL OR next_run_at <= ?", Time.current)
  }
  scope :trusted, -> { where(trust_level: "trusted") }
  scope :needs_review, -> { where(trust_level: "review") }

  # Schedule intervals in seconds
  SCHEDULE_INTERVALS = {
    "15_minutes" => 15.minutes,
    "hourly" => 1.hour,
    "2_hours" => 2.hours,
    "6_hours" => 6.hours,
    "12_hours" => 12.hours,
    "daily" => 1.day
  }.freeze

  # Search config accessors
  def assigned_rss_feed_ids
    search_config&.dig("rss_feeds") || []
  end

  def web_search_enabled?
    search_config&.dig("web_search_enabled") == true
  end

  def web_search_queries
    search_config&.dig("web_search_queries") || []
  end

  def required_keywords
    search_config&.dig("required_keywords") || []
  end

  def excluded_keywords
    search_config&.dig("excluded_keywords") || []
  end

  def domain_whitelist
    search_config&.dig("domain_whitelist") || []
  end

  def domain_blacklist
    search_config&.dig("domain_blacklist") || []
  end

  def max_age_hours
    search_config&.dig("max_age_hours") || 72
  end

  # Quality config accessors
  def relevance_threshold
    quality_config&.dig("relevance_threshold") || 0.5
  end

  def llm_vetting_enabled?
    quality_config&.dig("llm_vetting_enabled") == true
  end

  def llm_min_score
    quality_config&.dig("llm_min_score") || 0.7
  end

  def max_candidates_for_llm
    quality_config&.dig("max_candidates_for_llm") || 20
  end

  def trusted_domains
    quality_config&.dig("trusted_domains") || []
  end

  def rule_weights
    quality_config&.dig("rule_weights") || {
      "domain_reputation" => 0.3,
      "keyword_match" => 0.4,
      "source_trust" => 0.3
    }
  end

  # Settings accessors
  def setting(key)
    settings&.dig(key.to_s)
  end

  def update_setting(key, value)
    self.settings = (settings || {}).merge(key.to_s => value)
    save
  end

  # Trust level helpers
  def auto_approve?
    trust_level == "trusted"
  end

  def requires_approval?
    trust_level == "review"
  end

  # Scheduling
  def schedule_next_run!
    interval = SCHEDULE_INTERVALS[schedule_interval] || 1.day
    update!(next_run_at: Time.current + interval)
  end

  def mark_run_started!
    update!(last_run_at: Time.current)
    increment!(:run_count)
  end

  def increment_post_count!(count = 1)
    increment!(:post_count, count)
  end

  # Check daily limit
  def can_post_more_today?
    daily_post_count < max_daily_posts
  end

  def daily_post_count
    stories.where("created_at > ?", 24.hours.ago).count
  end

  def remaining_daily_posts
    [max_daily_posts - daily_post_count, 0].max
  end

  # Effective posts per run considering daily limit
  def effective_posts_per_run
    [posts_per_run, remaining_daily_posts].min
  end

  # Recent activity
  def last_run
    agent_runs.order(created_at: :desc).first
  end

  def last_successful_run
    agent_runs.where(status: "completed").order(created_at: :desc).first
  end

  def recent_runs(limit: 10)
    agent_runs.order(created_at: :desc).limit(limit)
  end

  # Statistics
  def success_rate
    total = agent_runs.count
    return 0.0 if total.zero?

    successful = agent_runs.where(status: "completed").count
    (successful.to_f / total * 100).round(1)
  end

  def average_posts_per_run
    completed_runs = agent_runs.where(status: "completed")
    return 0.0 if completed_runs.empty?

    (completed_runs.sum(:posts_created).to_f / completed_runs.count).round(1)
  end

  # Display helpers
  def schedule_display
    case schedule_interval
    when "15_minutes" then "Every 15 minutes"
    when "hourly" then "Every hour"
    when "2_hours" then "Every 2 hours"
    when "6_hours" then "Every 6 hours"
    when "12_hours" then "Every 12 hours"
    when "daily" then "Once daily"
    else schedule_interval.humanize
    end
  end

  def status_display
    if !enabled?
      "Disabled"
    elsif next_run_at.nil? || next_run_at <= Time.current
      "Ready to run"
    else
      "Next run: #{next_run_at.strftime('%Y-%m-%d %H:%M')}"
    end
  end
end
