class SentimentAnalyzer
  POSITIVE_KEYWORDS = %w[great excellent love amazing good happy satisfied].freeze
  NEGATIVE_KEYWORDS = %w[bad terrible hate awful poor disappointed unhappy].freeze

  def self.call(feedback)
    new(feedback).call
  end

  def initialize(feedback)
    @feedback = feedback
  end

  def call
    return sentiment_from_score if feedback.score.present?

    sentiment_from_comment
  end

  private

  attr_reader :feedback

  def sentiment_from_score
    case feedback.score
    when 4..5 then "positive"
    when 1..2 then "negative"
    else "neutral"
    end
  end

  def sentiment_from_comment
    text = feedback.comment.to_s.downcase
    positive_hits = POSITIVE_KEYWORDS.count { |word| text.include?(word) }
    negative_hits = NEGATIVE_KEYWORDS.count { |word| text.include?(word) }

    return "neutral" if positive_hits == negative_hits

    positive_hits > negative_hits ? "positive" : "negative"
  end
end
