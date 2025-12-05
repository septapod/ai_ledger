# frozen_string_literal: true

# A candidate link discovered by an Agent during a run
# Tracks scoring and status through the vetting pipeline
class AgentCandidate < ApplicationRecord
  include Token

  belongs_to :agent
  belongs_to :agent_run
  belongs_to :story, optional: true

  validates :source_type, presence: true, inclusion: {in: %w[rss web_search]}
  validates :url, presence: true, length: {maximum: 500}
  validates :title, length: {maximum: 500}, allow_nil: true
  validates :status, presence: true,
    inclusion: {in: %w[pending vetted llm_scored submitted rejected]}

  scope :pending, -> { where(status: "pending") }
  scope :vetted, -> { where(status: "vetted") }
  scope :llm_scored, -> { where(status: "llm_scored") }
  scope :submitted, -> { where(status: "submitted") }
  scope :rejected, -> { where(status: "rejected") }
  scope :from_rss, -> { where(source_type: "rss") }
  scope :from_web_search, -> { where(source_type: "web_search") }
  scope :by_score, -> { order(final_score: :desc) }
  scope :recent, -> { order(created_at: :desc) }

  # Create from RSS feed item
  def self.create_from_rss_item!(agent:, agent_run:, rss_feed_item:)
    create!(
      agent: agent,
      agent_run: agent_run,
      source_type: "rss",
      source_id: rss_feed_item.id,
      url: rss_feed_item.url,
      title: rss_feed_item.title,
      content: rss_feed_item.content,
      status: "pending"
    )
  end

  # Create from web search result
  def self.create_from_web_result!(agent:, agent_run:, url:, title:, content: nil)
    create!(
      agent: agent,
      agent_run: agent_run,
      source_type: "web_search",
      url: url,
      title: title,
      content: content,
      status: "pending"
    )
  end

  # Check for duplicates
  def self.exists_for_agent?(agent:, url:)
    where(agent: agent, url: url).exists?
  end

  # Scoring methods
  def set_rule_score!(score)
    update!(rule_score: score, status: "vetted")
  end

  def set_llm_score!(score)
    update!(llm_score: score, status: "llm_scored")
    calculate_final_score!
  end

  def calculate_final_score!
    # If LLM scoring was done, weight it more heavily
    if llm_score.present?
      final = (rule_score.to_f * 0.3) + (llm_score.to_f * 0.7)
    else
      final = rule_score.to_f
    end
    update!(final_score: final)
  end

  # Status transitions
  def mark_submitted!(story:)
    update!(
      status: "submitted",
      story: story
    )
  end

  def reject!(reason:)
    update!(
      status: "rejected",
      rejection_reason: reason
    )
  end

  # Predicates
  def pending?
    status == "pending"
  end

  def vetted?
    status == "vetted"
  end

  def submitted?
    status == "submitted"
  end

  def rejected?
    status == "rejected"
  end

  def from_rss?
    source_type == "rss"
  end

  def from_web_search?
    source_type == "web_search"
  end

  # Display helpers
  def truncated_title(length: 60)
    return nil if title.blank?
    title.truncate(length)
  end

  def score_display
    if final_score.present?
      "#{(final_score * 100).round}%"
    elsif rule_score.present?
      "#{(rule_score * 100).round}% (rule)"
    else
      "-"
    end
  end

  def source_display
    from_rss? ? "RSS" : "Web Search"
  end

  # Get domain from URL
  def domain
    URI.parse(url).host&.sub(/^www\./, "")
  rescue URI::InvalidURIError
    nil
  end
end
