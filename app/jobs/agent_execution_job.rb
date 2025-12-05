# frozen_string_literal: true

# Executes a single agent's content curation cycle
# 1. Search (RSS + Web)
# 2. Vet candidates (Rules + LLM)
# 3. Submit top stories
class AgentExecutionJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 5.minutes, attempts: 3

  def perform(agent_id)
    @agent = Agent.find_by(id: agent_id)
    return unless @agent&.enabled?

    Rails.logger.info "[AgentExecutionJob] Starting execution for agent: #{@agent.name}"

    @agent.mark_run_started!
    @run = AgentRun.start_for!(@agent)

    begin
      # Phase 1: Search for candidates
      candidates_found = search_for_candidates

      # Phase 2: Vet candidates with rules
      candidates_vetted = vet_candidates_with_rules

      # Phase 3: LLM scoring for top candidates (if enabled)
      candidates_llm_scored = score_with_llm

      # Phase 4: Submit top candidates as stories
      posts_created = submit_stories

      @run.complete!(
        candidates_found: candidates_found,
        candidates_vetted: candidates_vetted,
        candidates_llm_scored: candidates_llm_scored,
        posts_created: posts_created
      )

      Rails.logger.info "[AgentExecutionJob] Completed for #{@agent.name}: " \
                        "#{candidates_found} found, #{candidates_vetted} vetted, " \
                        "#{candidates_llm_scored} LLM scored, #{posts_created} posted"

    rescue => e
      @run.fail!(e.message)
      Rails.logger.error "[AgentExecutionJob] Failed for #{@agent.name}: #{e.message}"
      raise
    end
  end

  private

  def search_for_candidates
    Rails.logger.info "[AgentExecutionJob] Phase 1: Searching for candidates..."

    # Search RSS feeds
    rss_candidates = search_rss_feeds
    Rails.logger.info "[AgentExecutionJob] Found #{rss_candidates} RSS candidates"

    # Search web if enabled
    web_candidates = 0
    if @agent.web_search_enabled?
      web_candidates = search_web
      Rails.logger.info "[AgentExecutionJob] Found #{web_candidates} web search candidates"
    end

    rss_candidates + web_candidates
  end

  def search_rss_feeds
    count = 0
    @agent.rss_feeds.active.each do |feed|
      feed.rss_feed_items.where(processing_status: %w[pending relevant]).find_each do |item|
        next if already_candidate?(item.url)
        next if already_posted?(item.url)
        next unless matches_keywords?(item)

        AgentCandidate.create_from_rss_item!(
          agent: @agent,
          agent_run: @run,
          rss_feed_item: item
        )
        count += 1
      end
    end
    count
  rescue => e
    Rails.logger.error "[AgentExecutionJob] RSS search error: #{e.message}"
    0
  end

  def search_web
    return 0 unless @agent.web_search_enabled?

    searcher = AgentWebSearcher.new(@agent, @run)
    searcher.search
  rescue => e
    Rails.logger.error "[AgentExecutionJob] Web search error: #{e.message}"
    0
  end

  def vet_candidates_with_rules
    Rails.logger.info "[AgentExecutionJob] Phase 2: Vetting candidates with rules..."

    count = 0
    @run.agent_candidates.pending.find_each do |candidate|
      scorer = AgentRelevanceScorer.new(agent: @agent, candidate: candidate)
      score = scorer.score

      if score >= @agent.relevance_threshold
        candidate.set_rule_score!(score)
        count += 1
      else
        candidate.reject!(reason: "Below relevance threshold (#{(score * 100).round}%)")
      end
    end

    Rails.logger.info "[AgentExecutionJob] #{count} candidates passed rule-based vetting"
    count
  end

  def score_with_llm
    return 0 unless @agent.llm_vetting_enabled?

    Rails.logger.info "[AgentExecutionJob] Phase 3: LLM scoring top candidates..."

    # Get top candidates by rule score, limited to max_candidates_for_llm
    top_candidates = @run.agent_candidates
      .vetted
      .order(rule_score: :desc)
      .limit(@agent.max_candidates_for_llm)

    count = 0
    top_candidates.each do |candidate|
      analyzer = LlmQualityAnalyzer.new(candidate, @agent)
      result = analyzer.analyze

      if result[:score] >= @agent.llm_min_score
        candidate.set_llm_score!(result[:score])
        count += 1
      else
        candidate.reject!(reason: "LLM score below threshold (#{(result[:score] * 100).round}%)")
      end
    end

    Rails.logger.info "[AgentExecutionJob] #{count} candidates passed LLM scoring"
    count
  end

  def submit_stories
    Rails.logger.info "[AgentExecutionJob] Phase 4: Submitting stories..."

    return 0 unless @agent.can_post_more_today?

    # Get best candidates (LLM scored if enabled, otherwise rule scored)
    candidates = if @agent.llm_vetting_enabled?
      @run.agent_candidates.llm_scored.by_score
    else
      @run.agent_candidates.vetted.by_score
    end

    # Limit to effective posts per run
    candidates = candidates.limit(@agent.effective_posts_per_run)

    count = 0
    candidates.each do |candidate|
      break unless @agent.can_post_more_today?

      submitter = AgentStorySubmitter.new(@agent, candidate)
      result = submitter.submit!

      if result[:success]
        candidate.mark_submitted!(story: result[:story])
        count += 1
        Rails.logger.info "[AgentExecutionJob] Submitted: #{candidate.truncated_title}"
      else
        candidate.reject!(reason: result[:error])
        Rails.logger.warn "[AgentExecutionJob] Failed to submit: #{result[:error]}"
      end

      # Small delay between submissions
      sleep(1)
    end

    @agent.increment_post_count!(count) if count.positive?
    count
  end

  def already_candidate?(url)
    AgentCandidate.exists_for_agent?(agent: @agent, url: url)
  end

  def already_posted?(url)
    normalized = Utils.normalize_url(url)
    Story.where(normalized_url: normalized).exists?
  rescue
    false
  end

  def matches_keywords?(item)
    return true if @agent.required_keywords.empty?

    text = "#{item.title} #{item.content}".downcase
    @agent.required_keywords.any? { |kw| text.include?(kw.downcase) }
  end
end
