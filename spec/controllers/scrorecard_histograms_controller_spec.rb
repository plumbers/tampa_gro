require 'spec_helper'

describe ScorecardHistogramsController, :type => :controller do
  describe 'chart' do
    context 'get items' do

      include_context 'scorecard_cache_shared_context'

      it 'checks abilities with ScorecardHistogramAbility' do
        custom_login(user: supervisor, role: :sv)
        expect(ScorecardHistogram).to receive(:accessible_by).with(kind_of(Ability), :read).and_return(PositiveResponder.new)
        get :chart
      end

      it 'returns items for teamlead' do
        custom_login(user: supervisor, role: :sv)
        get :chart
        expect(assigns(:items).map{|e| e.id}).to include(@lenta_item.id)
      end
    end
  end
end