require 'spec_helper'

describe WebApi::LocationsController, type: [:request, :controller]  do

  let!(:organization){ FactoryGirl.create(:organization) }
  let!(:teamlead){ FactoryGirl.create(:teamlead, organization: organization, supervisor: regional_manager) }
  let!(:supervisor){ FactoryGirl.create(:sv, organization_id: organization.id, supervisor: teamlead) }
  let!(:merch){ FactoryGirl.create(:merch, organization_id: organization.id, supervisor: supervisor) }

  before do
    sign_in teamlead
    # custom_login(user: teamlead, role: :teamlead)
  end

  describe ".send_message" do

    context "send FCM message to list of recipients", :aggregate_failures do
      include_context "foreign_lenta_items_variables"

      let(:location){ create :location }
      subject(:enqueue_message) do
        put '/web_api/locations/send_message', params: { title: 'title', body: 'body', external_id: location.external_id, format: :json }, headers: {}
      end

      it "returns ok" do
        binding.pry
        expect{ send_msg }.to  change{ FcmMessage.count }.by(1)
        expect(response).to have_http_status :ok
        expect_any_instance_of(FcmPushMsgWorker).to receive(:perform).with(FcmMessage.first.id).exactly(1).times
        # expect(json_body).to include('encryption_key_version')
        # expect(json_body['encryption_key_version']).to be_instance_of Fixnum
      end
    end

  end
end
