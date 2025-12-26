class GoalContribution < ApplicationRecord
  include Monetizable

  CONTRIBUTION_TYPES = %w[manual automatic linked].freeze

  belongs_to :goal
  belongs_to :related_transaction, class_name: "Transaction", foreign_key: "transaction_id", optional: true

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :contribution_date, presence: true
  validates :contribution_type, presence: true, inclusion: { in: CONTRIBUTION_TYPES }

  enum :contribution_type, CONTRIBUTION_TYPES.index_by(&:itself), prefix: true

  monetize :amount

  scope :by_date, -> { order(contribution_date: :desc) }
  scope :manual, -> { where(contribution_type: "manual") }

  after_create :update_goal_progress!
  after_destroy :update_goal_progress!

  private

    def update_goal_progress!
      goal.update_progress! if goal.goal_type_custom?
    end
end
