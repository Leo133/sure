class GoalsController < ApplicationController
  before_action :set_goal, only: %i[show edit update destroy add_contribution]

  def index
    @active_goals = Current.family.goals.active.by_target_date
    @completed_goals = Current.family.goals.completed.order(completed_at: :desc)
  end

  def show
    @contributions = @goal.goal_contributions.by_date.limit(10)
  end

  def new
    @goal = Current.family.goals.new(
      currency: Current.family.currency,
      start_date: Date.current,
      color: Goal::COLORS&.sample || "#3B82F6"
    )
  end

  def create
    @goal = Current.family.goals.new(goal_params)

    if @goal.save
      redirect_to goal_path(@goal), notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @goal.update(goal_params)
      @goal.update_progress!
      redirect_to goal_path(@goal), notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @goal.destroy!
    redirect_to goals_path, notice: t(".deleted")
  end

  def add_contribution
    @contribution = @goal.goal_contributions.new(contribution_params)

    if @contribution.save
      @goal.update_progress!
      redirect_to goal_path(@goal), notice: t(".contribution_added")
    else
      redirect_to goal_path(@goal), alert: @contribution.errors.full_messages.to_sentence
    end
  end

  private

    def set_goal
      @goal = Current.family.goals.find(params[:id])
    end

    def goal_params
      params.require(:goal).permit(
        :name,
        :goal_type,
        :target_amount,
        :currency,
        :target_date,
        :status,
        :start_date,
        :color,
        :lucide_icon,
        :description,
        linked_account_ids: []
      )
    end

    def contribution_params
      params.require(:goal_contribution).permit(:amount, :notes).merge(
        currency: @goal.currency,
        contribution_date: Date.current,
        contribution_type: "manual"
      )
    end
end
