require 'spec_helper'

describe 'Schedule' do
  include Shoulda::Whenever

  let(:whenever) do
    Whenever::JobList.new(file: Rails.root.join('config', 'schedule.rb').to_s)
  end

  context 'task that is scheduled', :aggregate_failures do
    scheduled_classes = Dir.glob('app/scheduled_tasks/*.rb').
                            reject{|f| f =~ /base_scheduled_task/}.
                            map{ |f| File.basename(f,File.extname(f)) }

    scheduled_classes.each do |camelized_class|
      it "#{camelized_class} passes" do
        worker_klass = camelized_class.split('_').map{ |word| word[0] = word[0].upcase; word }.join
        expect(whenever).to schedule("#{worker_klass}.run")
      end unless ENV["skip_#{camelized_class}"]
    end
  end

  it "schedules users encryption key regeneration each 3 month, first day at 00-30 am", :aggregate_failures do
    expect(whenever).to schedule('UsersEncryptionKeyRegeneration.run').every('30 0 1 */3 *')
  end

end
