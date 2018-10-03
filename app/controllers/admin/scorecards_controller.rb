class Admin::ScorecardsController < ApplicationController
  before_action :authenticate_user!
  authorize_resource class: false
  before_action :set_breadcrumb

  def index
    @jobs = ScorecardJob.order('scorecard_date DESC').paginate page: params[:page], per_page: 25
    gon.push progress_status_model: 'ScorecardJob'
  end

  def restart
    @job = ScorecardJob.find(params[:id])
    @job.reset!
    ScorecardGeneratorJob.perform_later @job.id
    redirect_to :back
  end

  def show
    @job  = ScorecardJob.find(params[:id])
  end



  private

  def set_breadcrumb
    add_breadcrumb '<i class="icon-home"></i>'.html_safe
    add_breadcrumb 'Scorecard'
  end

  def specific_ability
    AdministrationAbility.new(current_user)
  end

end
