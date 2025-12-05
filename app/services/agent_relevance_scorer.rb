# frozen_string_literal: true

# Scores content relevance for an Agent based on its configuration
class AgentRelevanceScorer
  def initialize(agent:, candidate:)
    @agent = agent
    @candidate = candidate
    @weights = agent.rule_weights
  end

  # Calculate overall relevance score (0.0 - 1.0)
  def score
    @score ||= calculate_score
  end

  # Get detailed scoring breakdown
  def breakdown
    {
      domain_score: domain_score,
      keyword_score: keyword_match_score,
      source_score: source_trust_score,
      total_score: score
    }
  end

  private

  def calculate_score
    # Apply weights from agent config
    domain_weight = @weights["domain_reputation"].to_f
    keyword_weight = @weights["keyword_match"].to_f
    source_weight = @weights["source_trust"].to_f

    weighted_score = (domain_score * domain_weight) +
                     (keyword_match_score * keyword_weight) +
                     (source_trust_score * source_weight)

    # Apply penalties
    penalty = negative_keyword_penalty + excluded_domain_penalty
    final = weighted_score - penalty

    [[final, 0.0].max, 1.0].min
  end

  def domain_score
    @domain_score ||= begin
      domain = @candidate.domain
      return 0.5 if domain.nil?

      # Check trusted domains (from agent config)
      return 1.0 if @agent.trusted_domains.include?(domain)

      # Check domain whitelist
      return 0.9 if @agent.domain_whitelist.present? && @agent.domain_whitelist.include?(domain)

      # Check if domain has previous stories (established)
      existing_stories = Story.joins(:domain).where(domains: {domain: domain}).count
      if existing_stories > 10
        0.8
      elsif existing_stories > 0
        0.6
      else
        0.4
      end
    end
  end

  def keyword_match_score
    @keyword_score ||= begin
      return 1.0 if @agent.required_keywords.empty?

      text = combined_text
      matches = @agent.required_keywords.count { |kw| text.include?(kw.downcase) }
      total = @agent.required_keywords.size

      (matches.to_f / total).round(2)
    end
  end

  def source_trust_score
    @source_score ||= begin
      # Higher score for RSS (curated sources) vs web search
      base_score = @candidate.from_rss? ? 0.8 : 0.5

      # Boost if from assigned feed with good history
      if @candidate.from_rss? && @candidate.source_id.present?
        feed_item = RssFeedItem.find_by(id: @candidate.source_id)
        if feed_item&.rss_feed
          feed = feed_item.rss_feed
          # Feeds with more successful stories get higher scores
          if feed.story_count > 20
            base_score = 1.0
          elsif feed.story_count > 5
            base_score = 0.9
          end
        end
      end

      base_score
    end
  end

  def negative_keyword_penalty
    return 0.0 if @agent.excluded_keywords.empty?

    text = combined_text
    matches = @agent.excluded_keywords.count { |kw| text.include?(kw.downcase) }

    # Each match adds 0.2 penalty, max 1.0
    [matches * 0.2, 1.0].min
  end

  def excluded_domain_penalty
    return 0.0 if @agent.domain_blacklist.empty?

    domain = @candidate.domain
    return 0.0 if domain.nil?

    @agent.domain_blacklist.include?(domain) ? 1.0 : 0.0
  end

  def combined_text
    @combined_text ||= "#{@candidate.title} #{@candidate.content}".to_s.downcase
  end
end
