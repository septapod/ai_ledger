# frozen_string_literal: true

# Scores content relevance for AI + Credit Union topics
class RelevanceScorer
  CREDIT_UNION_KEYWORDS = [
    "credit union", "credit unions", "cu ", "cuso", "ncua", "cuna", "nafcu",
    "league", "member-owned", "cooperative", "member services",
    "credit union industry", "cu industry"
  ].freeze

  AI_KEYWORDS = [
    "artificial intelligence", " ai ", "machine learning", " ml ",
    "llm", "large language model", "gpt", "chatgpt", "chatbot",
    "automation", "nlp", "natural language", "neural network",
    "deep learning", "generative", "predictive", "algorithm",
    "data science", "computer vision"
  ].freeze

  FINTECH_KEYWORDS = [
    "fintech", "banking", "digital banking", "core system",
    "loan", "lending", "mortgage", "payment", "fraud", "compliance",
    "member experience", "mobile banking", "online banking",
    "financial services", "financial technology", "regtech",
    "risk management", "underwriting"
  ].freeze

  NEGATIVE_KEYWORDS = [
    "crypto", "bitcoin", "nft", "blockchain", "meme",
    "celebrity", "entertainment", "sports"
  ].freeze

  def initialize(title:, content:, url:)
    @title = normalize_text(title)
    @content = normalize_text(content)
    @url = normalize_text(url)
    @combined_text = "#{@title} #{@content} #{@url}"
  end

  # Calculate overall relevance score (0.0 - 1.0)
  def score
    @score ||= calculate_score
  end

  # Check if content meets relevance threshold
  def relevant?(threshold: 0.5)
    score >= threshold
  end

  # Get detailed scoring breakdown
  def breakdown
    {
      credit_union_score: credit_union_score,
      ai_score: ai_score,
      fintech_score: fintech_score,
      negative_score: negative_score,
      total_score: score
    }
  end

  private

  def calculate_score
    cu_score = credit_union_score
    ai = ai_score
    fintech = fintech_score
    negative = negative_score

    # Must have AI content
    return 0.0 if ai < 0.15

    # Apply negative penalty
    return 0.0 if negative > 0.3

    # Calculate weighted score
    base_score = ai * 0.4
    context_score = [cu_score * 1.2, fintech].max * 0.4
    cu_bonus = cu_score > 0.3 ? 0.2 : 0
    negative_penalty = negative * 0.3

    final_score = base_score + context_score + cu_bonus - negative_penalty
    [[final_score, 0.0].max, 1.0].min
  end

  def credit_union_score
    @cu_score ||= keyword_score(CREDIT_UNION_KEYWORDS, boost_title: true)
  end

  def ai_score
    @ai_score ||= keyword_score(AI_KEYWORDS, boost_title: true)
  end

  def fintech_score
    @fintech_score ||= keyword_score(FINTECH_KEYWORDS, boost_title: false)
  end

  def negative_score
    @negative_score ||= keyword_score(NEGATIVE_KEYWORDS, boost_title: false)
  end

  def keyword_score(keywords, boost_title: false)
    title_matches = keywords.count { |kw| @title.include?(kw) }
    content_matches = keywords.count { |kw| @combined_text.include?(kw) }

    # Boost title matches
    if boost_title
      effective_matches = (title_matches * 2) + (content_matches - title_matches)
    else
      effective_matches = content_matches
    end

    # Normalize score (cap at 5 matches for max score)
    [effective_matches.to_f / 5.0, 1.0].min
  end

  def normalize_text(text)
    text.to_s.downcase.gsub(/[^a-z0-9\s]/, " ").squeeze(" ")
  end
end
