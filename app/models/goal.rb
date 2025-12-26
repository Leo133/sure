class Goal < ApplicationRecord
  include Monetizable

  GOAL_TYPES = %w[savings debt_payoff net_worth emergency_fund custom].freeze
  STATUSES = %w[active completed paused].freeze
  DEFAULT_MILESTONES = [25, 50, 75, 100].freeze

  belongs_to :family
  has_many :goal_contributions, dependent: :destroy

  validates :name, presence: true
  validates :goal_type, presence: true, inclusion: { in: GOAL_TYPES }
  validates :target_amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  enum :goal_type, GOAL_TYPES.index_by(&:itself), prefix: true
  enum :status, STATUSES.index_by(&:itself), prefix: true

  monetize :target_amount, :current_amount

  scope :active, -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }
  scope :by_target_date, -> { order(target_date: :asc, created_at: :asc) }

  before_create :set_defaults
  after_save :check_completion!, if: :should_check_completion?

  # Calculate progress as a percentage (0-100)
  def progress_percentage
    return 0 if target_amount.nil? || target_amount.zero?
    return 100 if current_amount >= target_amount

    ((current_amount.to_f / target_amount.to_f) * 100).round(1)
  end

  # Check if progress is on track based on time elapsed
  def on_track?
    return true if completed?
    return true if target_date.nil?
    return false if target_date < Date.current

    progress_percentage >= expected_progress
  end

  # Calculate expected progress based on time elapsed
  def expected_progress
    return 100 if target_date.nil? || target_date <= Date.current
    return 0 if effective_start_date >= target_date

    total_days = (target_date - effective_start_date).to_f
    elapsed_days = (Date.current - effective_start_date).to_f

    return 0 if elapsed_days <= 0

    ((elapsed_days / total_days) * 100).round(1)
  end

  # Calculate days remaining until target date
  def days_remaining
    return nil if target_date.nil?
    return 0 if target_date < Date.current

    (target_date - Date.current).to_i
  end

  # Calculate amount needed per month to reach goal
  def required_monthly_contribution
    return 0 if completed?
    return nil if target_date.nil?

    remaining = target_amount - current_amount
    return 0 if remaining <= 0

    months_remaining = months_until_target
    return remaining if months_remaining <= 0

    (remaining / months_remaining).round(2)
  end

  # Update current amount based on goal type
  def update_progress!
    new_amount = calculate_progress_for_type

    if new_amount != current_amount
      update!(current_amount: new_amount)
      check_milestones!
    end
  end

  # Mark milestone percentages as reached
  def check_milestones!
    return if milestones.blank?

    updated_milestones = milestones.map do |milestone|
      if milestone["reached_at"].nil? && progress_percentage >= milestone["percentage"]
        milestone.merge("reached_at" => Time.current.iso8601)
      else
        milestone
      end
    end

    update_column(:milestones, updated_milestones) if updated_milestones != milestones
  end

  # Auto-complete when target reached
  def check_completion!
    return unless status_active?
    return unless current_amount >= target_amount

    update!(status: "completed", completed_at: Time.current)
  end

  # Get linked accounts
  def linked_accounts
    return Account.none if linked_account_ids.blank?

    family.accounts.where(id: linked_account_ids)
  end

  # Check if goal is behind schedule
  def behind_schedule?
    return false if target_date.nil? || completed?

    progress_percentage < expected_progress
  end

  # Get status for display (on_track, behind, completed)
  def tracking_status
    return "completed" if completed?
    return "on_track" if on_track?

    "behind"
  end

  # Initialize default milestones
  def initialize_milestones!
    default_milestones = DEFAULT_MILESTONES.map do |percentage|
      { "percentage" => percentage, "reached_at" => nil }
    end

    update!(milestones: default_milestones)
  end

  private

    def set_defaults
      self.start_date ||= Date.current
      self.current_amount ||= 0
      self.milestones = DEFAULT_MILESTONES.map { |p| { "percentage" => p, "reached_at" => nil } } if milestones.blank?
    end

    def effective_start_date
      start_date || created_at&.to_date || Date.current
    end

    def months_until_target
      return 0 if target_date.nil? || target_date <= Date.current

      # Calculate days remaining and convert to approximate months
      days_remaining = (target_date - Date.current).to_f
      (days_remaining / 30.0).ceil
    end

    def calculate_progress_for_type
      case goal_type
      when "savings"
        calculate_savings_progress
      when "debt_payoff"
        calculate_debt_payoff_progress
      when "net_worth"
        calculate_net_worth_progress
      when "emergency_fund"
        calculate_emergency_fund_progress
      when "custom"
        calculate_custom_progress
      else
        current_amount
      end
    end

    def calculate_savings_progress
      return current_amount if linked_account_ids.blank?

      linked_accounts.sum(:balance).to_d
    end

    def calculate_debt_payoff_progress
      return current_amount if linked_account_ids.blank?

      # For debt payoff, progress is the reduction from original balance
      # Debt accounts have positive balances representing the amount owed
      # Progress = how much of the original debt has been paid off
      original_debt = target_amount
      current_debt = linked_accounts.sum(:balance).to_d

      # If current debt is negative (overpayment), treat as fully paid
      return original_debt if current_debt <= 0

      [original_debt - current_debt, 0].max
    end

    def calculate_net_worth_progress
      family.balance_sheet.net_worth.to_d
    end

    def calculate_emergency_fund_progress
      return current_amount if linked_account_ids.blank?

      linked_accounts.sum(:balance).to_d
    end

    def calculate_custom_progress
      goal_contributions.sum(:amount).to_d
    end

    def should_check_completion?
      saved_change_to_current_amount? && status_active?
    end

    def completed?
      status_completed?
    end
end
