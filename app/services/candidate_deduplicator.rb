# frozen_string_literal: true

# Checks for duplicate URLs across stories and candidates
class CandidateDeduplicator
  def initialize(agent:, url:)
    @agent = agent
    @url = url
    @normalized_url = normalize_url
  end

  def duplicate?
    already_posted? || already_candidate? || recently_rejected?
  end

  def already_posted?
    return false if @normalized_url.blank?

    Story.where(normalized_url: @normalized_url).exists?
  end

  def already_candidate?
    AgentCandidate.exists_for_agent?(agent: @agent, url: @url)
  end

  def recently_rejected?
    # Check if this URL was rejected in the last 7 days
    AgentCandidate.where(agent: @agent, url: @url, status: "rejected")
      .where("created_at > ?", 7.days.ago)
      .exists?
  end

  private

  def normalize_url
    Utils.normalize_url(@url)
  rescue
    nil
  end
end
