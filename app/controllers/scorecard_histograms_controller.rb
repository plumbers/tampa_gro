class ScorecardHistogramsController < ApplicationController

  # FILTER_FIELDS = %w( channel iformat company_name network_name signboard_name client_category )
  FILTER_FIELDS = %w( channel client_category )

  def chart
    prepare_filters

    @data = []
    @items, @base_items = find_items
    @items.each do |d|
      build_answer_data(d)
    end

    respond_to do |format|
      format.html { render 'chart' }
      format.js { }
    end
  end

  private

  def build_answer_data(d)
    base_item_median_answer = @base_items[d.question][0].median_answer rescue 0
    return if (d.median_answer<0.01 && base_item_median_answer<0.01)
    if d.question.size>40
      sub_length=d.question[0..(d.question.size/2).to_i].rindex(' ')||0
      title = d.question[0..sub_length]
      subtitle = d.question[sub_length..-1]
    else
      title = d.question
      subtitle = ''
    end
    @data<<{"title"     => title,
            "subtitle"  => subtitle,
            "ranges"    => [d.median_answer, 0, 0],
            "measures"  => [base_item_median_answer],
            "markers"   => d.markers.split(',').map(&:to_i)}
  end

  def specific_ability
    ScorecardHistogramAbility.new(current_user)
  end

  def find_items
    filtered_items = find_filtered_items
    base_items     = find_base_items_for_compare filtered_items

    [filtered_items, base_items]
  end

  def find_base_items_for_compare filtered_questions
    base_query.periscope(filter_base_params).
                select(def_select).
                where("question_id IN (?)", filtered_questions.pluck(:question_id)).
                group("question_id, question").
                order("question_id").
                to_a.group_by{ |i| i['question']}
  end

  def find_filtered_items
    base_query.periscope(filter_params).
                select(def_select).
                group("question_id, question").
                order("question_id").paginate(page: params[:page], per_page: 10)
  end

  def hist_params
    @hist_params = params[:histogram].compact rescue {}
  end

  def hist_param key
    hist_params.try(:[], key)
  end

  def filter_params
    hist_params.select{|k,v| not k=~/_base/}
  end

  def filter_base_params
    hist_params.select{|k,v| k=~/_base/}
  end

  def prepare_filters
    @end_date     = hist_param(:end_date).present?    ? Date.parse(hist_param(:end_date))   : Date.yesterday
    @start_date   = hist_param(:begin_date).present?  ? Date.parse(hist_param(:begin_date)) : @end_date.beginning_of_month

    @filter_items      = {}
    FILTER_FIELDS.each do |filter|
      @filter_items[filter] = filter.classify.constantize.select('name, id')
    end
    @users = users
  end

  def users
    # @users ||= User.where(current_user.all_subordinates_with_self_query).order('users.name')
    @users ||= User.where(User.find_by(id: 104).all_subordinates_with_self_query).order('users.name')
  end

  def base_query
    # ScorecardHistogramFact.requester(104).in_period(@start_date, @end_date).
    #   joins("INNER JOIN scorecard_histogram_questions hq ON hq.id=question_id")
    ScorecardHistogramFact.requester(current_user.id).where(event_local_date: @start_date..@end_date).
      joins("INNER JOIN scorecard_histogram_questions hq ON hq.id=question_id")
  end

  def def_select
    # " question,
    #   CASE WHEN MAX(answer)=1.0 OR MAX(answer)=1 THEN
    #     ROUND((count(answer) FILTER(WHERE answer>0.0)*100.)/count(answer),2)
    #        ELSE
    #     (AVG(answer)*100.)::int
    #   END
    #     median_answer
    # "
    " question,
      CASE
          WHEN MAX(answer)=1.0 OR MAX(answer)=1 THEN ((count(answer) FILTER(WHERE answer>0.0)*100.)/(count(answer) FILTER(WHERE answer IS NOT NULL)))::int
          WHEN AVG(price)::int IS NOT NULL THEN AVG(price)::int
          --WHEN MAX(answer)>1.0 OR MAX(answer)>1 THEN (AVG(answer)*100./MAX(answer))::int
          ELSE
            AVG(answer)::int
      END
          median_answer,
      CASE
          WHEN MAX(answer)=1.0 OR MAX(answer)=1 THEN 100::text
          WHEN AVG(price)::int IS NOT NULL THEN 100::text
          ELSE ''''||MIN(answer)||','||AVG(answer)||','||MAX(answer)||''''
      END
          markers
    "
    # "question, MAX(max_answer) max_answer"

  end
end
