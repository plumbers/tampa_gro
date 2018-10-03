require 'spec_helper'

describe Order, :type => :model do
  let(:order){ FactoryGirl.create(:order, author: author) }

  describe '#author_role' do
    subject { order.author_role }

    context 'supervisor' do
      let(:author){ FactoryGirl.create :supervisor, organization: organization }
      context 'tdm organization' do
        let(:organization){ FactoryGirl.create :organization, is_tdm_org: true }

        it 'tdm' do
          expect(subject).to eq I18n.t('roles.tdm')
        end
      end

      context 'not tdm organization' do
        let(:organization){ FactoryGirl.create :organization, is_tdm_org: false }

        it 'author role' do
          expect(subject).to eq I18n.t("roles.#{author.role}")
        end
      end
    end

    context 'not supervisor' do
      let(:author){ FactoryGirl.create :teamlead, organization: organization }

      context 'tdm organization' do
        let(:organization){ FactoryGirl.create :organization, is_tdm_org: true }

        it 'author role' do
          expect(subject).to eq I18n.t("roles.teamlead-Sales")
        end
      end

      context 'not tdm organization' do
        let(:organization){ FactoryGirl.create :organization, is_tdm_org: false }

        it 'author role' do
          expect(subject).to eq I18n.t("roles.#{author.role}")
        end
      end
    end
  end

  describe '#performer_name' do
    let(:author) { FactoryGirl.create(:teamlead) }
    let(:performer) { with_versioning { FactoryGirl.create(:merchendiser) } }
    let(:order){ FactoryGirl.create(:order, author: author, performer: performer) }

    it 'returns nil if new' do
      expect(order.performer_name).to be_nil
    end

    it 'returns agency_name if have visit_plan' do
      order.update!(status: Order::STATUSES[:success])
      visit_plan = create(:visit_plan, user: performer, location: order.location)
      expect(order.performer_name).to eq(visit_plan.agency_name)
    end

    it 'returns default agency_name text if have not visit_plan' do
      order.update!(status: Order::STATUSES[:success])
      expect(order.performer_name).to eq(I18n.t('models.location_events.order.agency'))
    end
  end
end
