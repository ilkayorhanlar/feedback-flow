class TenantAggregate < ApplicationRecord
  SENTIMENT_COLUMNS = {
    "positive" => "positive_count",
    "negative" => "negative_count",
    "neutral" => "neutral_count"
  }.freeze

  belongs_to :tenant
end
