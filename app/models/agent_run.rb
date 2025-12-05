# frozen_string_literal: true

# Tracks a single execution cycle of an Agent
class AgentRun < ApplicationRecord
  include Token

  belongs_to :agent
  has_many :agent_candidates, dependent: :destroy

  validates :started_at, presence: true
  validates :status, presence: true, inclusion: {in: %w[running completed failed]}

  scope :running, -> { where(status: "running") }
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :recent, -> { order(created_at: :desc) }

  # Create a new run for an agent
  def self.start_for!(agent)
    create!(
      agent: agent,
      started_at: Time.current,
      status: "running"
    )
  end

  # Mark run as completed
  def complete!(candidates_found: 0, candidates_vetted: 0, candidates_llm_scored: 0, posts_created: 0)
    update!(
      status: "completed",
      completed_at: Time.current,
      candidates_found: candidates_found,
      candidates_vetted: candidates_vetted,
      candidates_llm_scored: candidates_llm_scored,
      posts_created: posts_created
    )
  end

  # Mark run as failed
  def fail!(error_message)
    update!(
      status: "failed",
      completed_at: Time.current,
      error_message: error_message
    )
  end

  # Metrics accessors
  def add_metric(key, value)
    self.metrics = (metrics || {}).merge(key.to_s => value)
    save
  end

  def metric(key)
    metrics&.dig(key.to_s)
  end

  # Duration
  def duration
    return nil unless completed_at

    completed_at - started_at
  end

  def duration_display
    secs = duration
    return "Running..." if secs.nil?

    if secs < 60
      "#{secs.round(1)}s"
    elsif secs < 3600
      "#{(secs / 60).round(1)}m"
    else
      "#{(secs / 3600).round(1)}h"
    end
  end

  # Status helpers
  def running?
    status == "running"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def success?
    completed? && posts_created.positive?
  end
end
