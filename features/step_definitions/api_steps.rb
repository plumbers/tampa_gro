require Rails.root.join('spec/support/assistance.rb')

def prevent_image_from_aws_migration
  @eigenclass = class << AwsUploader; self; end
  @eigenclass.class_eval do
    alias_method :old_perform_later, :perform_later
    remove_method :perform_later
    def perform_later photo_id, checkin_id
    end
  end
end

def restore_aws_migration_functionality
  @eigenclass.class_eval do
    remove_method :perform_later
    alias_method :perform_later, :old_perform_later
    remove_method :old_perform_later
  end
end

def reupload_photo_to_aws
  checkin = Checkin.find(@checkin_id)
  photo   = checkin.photo_evaluations.first.photo
  AwsUploader.perform_later(photo.id, checkin.id)
end

def create_and_reload_checkin_types
  Rspec::Assistance.create_checkin_types
  Rspec::Assistance.reload_checkin_type_matcher
end

Given(/^I use api version (\d+) headers$/) do |version|
  @version_header = {'HTTP_ACCEPT' => "application/vnd.mobileforce+json; version=#{version}"}
end

Given /^I use api version (\d+)$/ do |api_ver|
  @api_version = api_ver
  create_and_reload_checkin_types
end

When(/^I log in through API using my credentials( and remember evaluations hashes)?$/) do |remember_evaluations|
  #FIXME: а где запоминание evaluations hashes?
  @user ||= User.find_by_email('otaraeva@test.com')
  @logged_user = @user
  @version_header = {'HTTP_ACCEPT' => "application/vnd.mobileforce+json; version=#{@api_version}"}
  valid_credentials = {:email => @user.email, :password => ApiEncryption.aes256_encrypt(@user.email)}
  post '/api/sessions.json', valid_credentials, @version_header
  json = JSON.parse last_response.body
  json['code'].should eq 200
  @auth_token = json['auth_token']
  @session_id = json['id']
  auth_header = { 'HTTP_AUTHORIZATION' => %Q{Token token="#{@auth_token}"} }
  @version_and_auth_header = @version_header.merge auth_header
  @session_hash = json
end

And(/^I get the list of my plans for today and tomorrow with today-tomorrow format$/) do
  today = Date.yesterday.next_working_day.strftime('%d.%m.%Y')
  tomorrow = Date.parse(today).next_working_day.strftime('%d.%m.%Y') 
  get '/api/plan_items.json', {}, @version_and_auth_header
  json = JSON.parse(last_response.body)
  json['code'].should eq 200
  json[today].should be_a Array
  json[today].size.should eq @user.plans_as_inspector.last.plan_items.size
end

And(/^I get the list of the nearby locations$/) do
  location = FactoryGirl.create(:location, organization_id: @user.organization_id)
  #FactoryGirl.create(:location_organization, :location_id => location.id, :organization_id => @user.organization_id)
  current_coordinates = {:latitude => location.lat, :longitude => location.long}
  get '/api/locations/nearby.json', current_coordinates, @version_and_auth_header
  json = JSON.parse(last_response.body)
  json['code'].should eq 200
  json['locations'].should be_a Array
  json['locations'].map {|loc| loc['name']}.should include location.signboard.name
end

And(/^I send a text report about one of them$/) do
  mobile_params = ["long", "lat", "location_id", "plan_item_id",
                   "started_at", "finished_at", "mobile_expected_photos_count"]
  @plan_item = @user.plans_as_inspector.last.plan_items.first
  @plan_item.location.update_attribute :organization_id, @user.organization_id
  checkin_hash = FactoryGirl.build(:checkin_with_plan_item, plan_item_id: @plan_item.id, long: @plan_item.location.long, lat: @plan_item.location.lat, user: @user, finished_at: Time.now).attributes.slice(*mobile_params).merge('mobile_expected_photos_count' => 1, 'finished_at' => Time.now)
  query_params = {checkin: checkin_hash}
  post '/api/checkins.json', query_params, @version_and_auth_header
  json = JSON.parse last_response.body
  json['code'].should eq 200
  @checkin_id = json['checkin_id']
end

And(/^I upload all the waiting for it photos$/) do
  @photo_hash = {
      data: Base64.encode64(File.open(Rails.root.join('spec/fixtures/rails.png')).read),
      filename: 'rails',
      content_type: 'image/png'
  }
  put "/api/checkins/#{@checkin_id}.json", {:photo => @photo_hash}, @version_and_auth_header
  json = JSON.parse last_response.body
  json['code'].should eq 200
end

When(/^I log out$/) do
  delete "/api/sessions/#{@session_id}.json", {}, @version_header.merge('HTTP_AUTHORIZATION' => %Q{Token token="#{@auth_token}"})
  json = JSON.parse last_response.body
  json['code'].should eq 200
end

Then(/^API key should be expired$/) do
  get '/api/plan_items.json', {}, @version_and_auth_header
  last_response.body.should eq "HTTP Token: Access denied.\n"
end

And(/^a finished checkin with photos should exist$/) do
  Checkin.where(:id => @checkin_id).count.should == 1
  Checkin.find(@checkin_id).extend(CheckinLentaDecorator).photos.size.should == 1 
end

And(/^a corresponding plan_item should be marked as finished$/) do
  plan_item = @plan_item || @plan.plan_items.first
  plan_item.reload.status_id.should eq PlanItem::FINISHED
end

And(/^there are some lenta_items of subordinates created$/) do
  user = FactoryGirl.create :user, organization: @user.organization
  checkin = FactoryGirl.create :mobile_checkin, :with_photos, user: user
  @lenta_items = FactoryGirl.create_list :lenta_item, 2, user: @user, checkin: checkin
end

When(/^I receive my v1 lenta information$/) do
  get '/api/lenta_items.json', {}, @version_and_auth_header
  json = JSON.parse last_response.body
  json['code'].should eq 200
  json['lenta'].map {|li| li['location']['name']}.to_set.should eq @lenta_items.map {|li| li.checkin.location.signboard.name}.to_set
end

Then /^I should see (merch) report in (v2|v3) lenta$/ do |report_type, lenta_v|
  get '/api/lenta_items.json', {}, @version_and_auth_header
  expected_result = method("get_expected_#{report_type}_lenta").call(lenta_v)
  full_response = JSON.parse(last_response.body)
  full_response['lenta'].first['photos']['links'].sort!
  expected_result['lenta'].first['photos']['links'].sort!
  full_response.should == expected_result
end

Then(/^I should see a list of photos for each checkin$/) do
  json = JSON.parse last_response.body
  @links = json['lenta'].map{|li| li['photos']['links']}.flatten
  @links.size.should eq @user.lenta_items.map{|i| i.checkin.extend(CheckinLentaDecorator)}.map(&:photos).flatten.size
end

def tempfile(body)
  tempfile = Tempfile.new('test_file')
  tempfile.binmode
  tempfile.write body
  tempfile.rewind
  tempfile
end

And(/^I should be able to follow that photos' links to watch them$/) do
  get @links.sample, {}, @version_and_auth_header
  get last_response.location
  photo = Photo.new image: tempfile(last_response.body)
  photo.should be_valid
end

And(/^I should be able to watch that photos in a custom size$/) do
  size = rand(200..300)
  get @links.sample, {size: "s_#{size}_height"}, @version_and_auth_header
  get last_response.location
  geometry = Paperclip::Geometry.from_file tempfile(last_response.body)
  geometry.height.should eq size
end

And(/^I am in ([\+\-]\d{1,2}) timezone$/) do |timezone|
  @timezone = timezone
end

And(/^I !SuBMiT! the checkin for one of planned location with finish time of (\d+):(\d+)$/) do |h, m|
  d = Date.today
  Timecop.travel d.year, d.month, d.day, h, m
  step 'I send a text report about one of them'
end

And(/^I ask for locations planned to visit$/) do
  today = Date.yesterday.next_working_day.strftime('%d.%m.%Y')
  get '/api/plan_items.json', {}, @version_and_auth_header
  @locations_planned_to_visit_for_today = JSON.parse(last_response.body)[today]
end

Then(/^that location has a "(.*?)" state$/) do |state|
  checkin = Checkin.find @checkin_id
  location_id = checkin.location.id
  @locations_planned_to_visit_for_today.select{|elem| elem['location_id'] == location_id}[0]['status'].should eq state
end

And(/^that location is marked as "(.*?)" in nearby locations list aswell$/) do |status|
  location = Checkin.find(@checkin_id).location
  current_coordinates = {:latitude => location.lat, :longitude => location.long}
  get '/api/locations/nearby.json', current_coordinates, @version_and_auth_header
  json = JSON.parse(last_response.body)
  json['locations'].select{|loc| loc['location_id'] == location.id}[0]['status'].should eq status
end

And /^I get the list of my plans for today and tomorrow with dates format$/ do
  today_date = Date.yesterday.next_working_day.strftime('%d.%m.%Y')
  get '/api/plan_items.json', {}, @version_and_auth_header
  response_body = JSON.parse(last_response.body)
  response_body['code'].should eq 200
  response_body[today_date].should be_a Array
  response_body[today_date].size.should eq @user.plans_as_inspector.last.plan_items.size
  @visit_id = response_body[today_date].first['plan_item_id']
  @location_id = response_body[today_date].first['location_id']
end

And /^I get the dates available to move one of visits to$/ do
  get "/api/plan_items/#{@visit_id}.json", {}, @version_and_auth_header
  response_body = JSON.parse(last_response.body)
  response_body['move_to'].each do |available_date|
    (available_date =~ /^\d{1,2}\.\d{1,2}\.\d{4}$/).should_not be_nil
  end
  @move_to = response_body['move_to'].sample
  PlanItem.joins(:plan).where(:plans => {:thedate => Date.parse(@move_to)}, :plan_items => {:location_id => @location_id}).count.should eq 0
end

And /^I move visit to one of that dates$/ do
  put "/api/plan_items/#{@visit_id}.json", {transfer_date: @move_to}, @version_and_auth_header
  JSON.parse(last_response.body)['code'].should eq 200
end


Then /^I should not see that visit in plan for today$/ do
  today_date = Date.yesterday.next_working_day.strftime('%d.%m.%Y')
  get '/api/plan_items.json', {}, @version_and_auth_header
  JSON.parse(last_response.body)[today_date].any?{|i| i['plan_item_id'] == @visit_id }.should eq false
end

And /^that visit should be obtained by the new plan$/ do
  PlanItem.joins(:plan).where(:plans => {:thedate => Date.parse(@move_to)}, :plan_items => {:location_id => @location_id}).count.should eq 1
end

Then /^I should see a notification that visit has been moved forward$/ do
  today_date = Date.yesterday.next_working_day.strftime('%d.%m.%Y')

  get '/api/messages.json', {}, @version_and_auth_header
  response_body = JSON.parse(last_response.body)
  message = response_body['messages'].last
  
  response_body['code'].should eq 200
  response_body['messages'].should be_kind_of Array
  response_body['messages'].size.should == 1
  
  message['visit_id'].should eq @visit_id
  message['date_from'].should eq today_date
  message['date_to'].should eq @move_to
  message['action'].should eq 'moved'
  message['sender'].should eq User.where(:email => 'otaraeva@test.com').first.name_or_email
  message['location']['address'].should eq Location.joins(:plan_items).where(plan_items: {id: @visit_id}).first.address
end

And /^I re-login as a supervisor$/ do
  delete "/api/sessions/#{@session_id}.json", {}, @version_and_auth_header
  @user = @supervisor = User.where(:email => 'proligin@test.com').first
  valid_credentials = {:email => 'proligin@test.com', :password =>ApiEncryption.aes256_encrypt("proligin@test.com")}
  post '/api/sessions.json', valid_credentials, @version_header
  json = JSON.parse last_response.body
  json['code'].should eq 200
  @auth_token = json['auth_token']
  @session_id = json['id']
  auth_header = { 'HTTP_AUTHORIZATION' => %Q{Token token="#{@auth_token}"} }
  @version_and_auth_header = @version_header.merge auth_header
end

And /^I move that visit back$/ do
  confirmation = MoveVisitConfirmation.last
  from_date = confirmation.date_from
  Timecop.travel(from_date.year, from_date.month, from_date.day, 14, 00, 00) do
    ApiKey.last.update_attribute :expires_at, Time.now + 10.days 
    put "/api/move_visit_confirmations/#{confirmation.id}/refuse.json", {}, @version_and_auth_header
  end
  JSON.parse(last_response.body)['code'].should eq 200
end

And /^I re-login as merchendiser$/ do
  delete "/api/sessions/#{@session_id}.json", {}, @version_and_auth_header
  @user = @merchendiser = User.where(:email => 'otaraeva@test.com').first
  step "I log in through API using my credentials"
end

Then /^I should see a notification that visit has been moved back$/ do
  get '/api/messages.json', {}, @version_and_auth_header
  response_body = JSON.parse(last_response.body)
  message = response_body['messages'].last
  response_body['code'].should eq 200
  response_body['messages'].should be_kind_of Array
  response_body['messages'].size.should == 1
  message['visit_id'].should eq @visit_id
  message['action'].should eq 'refused'
  message['sender'].should eq User.where(:email => 'proligin@test.com').first.name_or_email
end

And /^the mentioned visit should belong to previous plan$/ do
  today_date = Date.yesterday.next_working_day.strftime('%d.%m.%Y')
  get '/api/plan_items.json', {}, @version_and_auth_header
  JSON.parse(last_response.body)[today_date].any?{|i| i['plan_item_id'] == @visit_id }.should eq true
  PlanItem.joins(:plan).where(:plans => {:thedate => Date.parse(@move_to)}, :plan_items => {:location_id => @location_id}).count.should eq 0
end

And /^there are some trade points with skus$/ do
  company     = FactoryGirl.create(:company, organization_id: @user.organization_id)
  @location   = FactoryGirl.create(:location, organization_id: @user.organization_id, company_id: company.id)
  @category   = FactoryGirl.create(:sku_category, :organization_id => @user.organization_id)
  @sku        = FactoryGirl.create(:sku, :with_brand, sku_category: @category)
  assortment  = FactoryGirl.create(:assortment, :with_locations => [@location], :with_skus => [@sku], :organization => @user.organization)
end

And /^I am near the planned location$/ do
  @plan = FactoryGirl.create(:plan, :with_visits => [@location], :inspector => @user, :thedate => Date.today)
end

And /^I get list of skus of nearby location$/ do
  get "/api/locations/#{@location.id}/sku_categories.json", {}, @version_and_auth_header

  response_body = JSON.parse(last_response.body)
  response_body['categories'].map{|i| i['name']}.should == [@category.name]
  
  skus_of_this_category = response_body['categories'].find{|i| i['name'] == @category.name}['elements']
  skus_of_this_category.map{|i| i['id'].to_i}.should == [@sku.id]

  @obtained_skus_hash = response_body['categories']
end

def actually_send_checkin
  post "/api/checkins.json", @results_hash, @version_and_auth_header
  response_body = JSON.parse(last_response.body)
  response_body['code'].should eq 200
  @checkin_id = response_body['checkin_id']
  @checkin_id.should be_kind_of Numeric
end

And /^I send a processed (merch) checkin$/ do |checkin_type|
  @results_hash = Cucumber::Assistance.send("valid_#{checkin_type}_checkin_hash", {:location => @location, :category => @category, :sku => @sku, :plan => @plan})
  actually_send_checkin
end

Then /^a checkin with appropriate values should be created$/ do
  evaluations_size =  @results_hash[:checkin].
                        except(:long,
                               :lat,
                               :location_id,
                               :plan_item_id,
                               :started_at,
                               :mobile_api,
                               :finished_at).
                        values.flatten.size

  evaluations_size += @photos.size

  checkin = Checkin.find(@checkin_id)
  checkin.mobile_api.should eq @api_version.to_i
  checkin.checkin_evaluations.count.should eq evaluations_size 
  checkin.location_id.should eq @location.id
  @lenta_items ||= [checkin.lenta_items.first]
end

And /^location should be marked as processed in nearby locations list$/ do
  position_hash = {latitude: @location.lat, longitude: @location.long}
  get "/api/locations/nearby.json", position_hash, @version_and_auth_header
  response_body = JSON.parse(last_response.body)
  processed_location = response_body['locations'].find{|i| i['location_id'] == @location.id}
  processed_location['status'].should == 'finished'
end

And /^location should be marked as processed in plan for today$/ do
  working_day = Date.yesterday.next_working_day.strftime('%d.%m.%Y')
  get "/api/plan_items.json", {}, @version_and_auth_header
  response_body = JSON.parse(last_response.body)
  processed_location = response_body[working_day].find{|i| i['location_id'] == @location.id && i['plan_item_id'] == @plan.plan_items.first.id}
  if Date.today.saturday? || Date.today.sunday? 
    processed_location.should be_nil
  else
    processed_location['status'].should == 'finished'
  end
end

def get_photos_for photo_type
  result = [
    {
      photo: {
        filename: 'photo1',
        content_type: 'image/png',
        data: Base64.encode64(File.open(Rails.root.join('spec/fixtures/rails.png')).read)
      },
      evaluation: {
        sku_category_id: @category.id,
        placement_id: CheckinEvaluation::SHELF,
        stage_id: CheckinEvaluation::INITIAL
      }
    },
    {
      photo: {
        filename: 'photo2',
        content_type: 'image/png',
        data: Base64.encode64(File.open(Rails.root.join('spec/fixtures/rails.png')).read)
      },
      evaluation: {
        sku_category_id: @category.id,
        placement_id: CheckinEvaluation::ADDITIONAL,
        stage_id: CheckinEvaluation::SECONDARY
      }
    }
  ]
  case photo_type
  when 'merch'
    return result
  when 'PEPSI-MILK'
    result[0][:evaluation][:note] = 'street'
    result[1][:evaluation][:note] = 'lipton'
    return result
  when 'PEPSI-WATER'
    result[0][:evaluation][:note] = 'street'
    result[1][:evaluation][:note] = 'child_less_3_cold'
    return result
  else
    raise "unknown photo type"
  end
end

And /^I upload some v2-formatted (.+) photos$/ do |photo_type|
  @photos = get_photos_for photo_type
  @checkin_id ||= JSON.parse(last_response.body)['checkin_id']
  @photos.each do |photo|
    put "/api/checkins/#{@checkin_id}.json", photo, @version_and_auth_header
    JSON.parse(last_response.body)['code'].should eq 200
  end
end

And(/^there are some lenta_items of subordinates created with evaluations$/) do
  FactoryGirl.create :sku_category, :organization_id => @user.organization_id, :with_skus => [FactoryGirl.create(:sku)]
  checkins = FactoryGirl.create_list :checkin, 2, :with_photos, :with_evaluations, user: @user
  @lenta_items = checkins.map{|checkin| FactoryGirl.create(:lenta_item, user: @user, checkin: checkin)}
end

When(/^I re\-login through API as a teamlead$/) do
  @user = @teamlead
  step 'I log in through API using my credentials'
end

When(/^I re\-login through API as supervisor$/) do
  @user = @supervisor
  step 'I log in through API using my credentials'
end

Given /^I gonna send (.+) checkin$/ do |checkin_type|
  @results_hash = Cucumber::Assistance.send("valid_#{checkin_type}_checkin_hash", {:location => @location, :category => @category, :sku => @sku, :plan => @plan})
end

Given /^there (?>is|are) "(.+)" evaluation(?>s)?(?> with "(.+)" value)?$/ do |evaluation_name, value|
  if value
    evaluation = Evaluation.joins(:evaluation_type).where(:evaluations => {:name => value})
    case evaluation_name
      when "initial price tags"
        hash = @results_hash[:checkin][:price_tag_evaluations_attributes]
        evaluation = evaluation.where(:evaluation_types => {:name => "freshness"}).first
        element_index = hash.find_index{|i| i[:stage_id] == 4 && i[:placement_id] == 2}
        hash[element_index][:evaluation_id] = evaluation.id
      when "initial category stock"
        hash = @results_hash[:checkin][:category_stock_evaluations_attributes]
        evaluation = evaluation.where(:evaluation_types => {:name => "yesnocritical"}).first
        element_index = hash.find_index{|i| i[:stage_id] == 4 && i[:placement_id] == 2}
        hash[element_index][:evaluation_id] = evaluation.id
      when "overall faces amount"
        hash = @results_hash[:checkin][:faces_amount_evaluations_attributes]
        element_index = hash.find_index{|i| i[:note] == 'overall'}
        hash[element_index][:faces_amount] = value.to_i
      when "company faces amount"
        hash = @results_hash[:checkin][:faces_amount_evaluations_attributes]
        element_index = hash.find_index{|i| i[:note] == 'company'}
        hash[element_index][:faces_amount] = value.to_i
      when "brands faces amount"
        hash = @results_hash[:checkin][:faces_amount_evaluations_attributes]
        element_index = hash.find_index{|i| i[:brand_id].present?}
        hash[element_index][:faces_amount] = value.to_i 
    end
  end
end
        
And /^there is no evaluation for "(.+)"$/ do |evaluation_name|
  case evaluation_name
  when "in stock"
    @results_hash[:checkin].delete(:in_stock_evaluations_attributes)
  when "secondary merchandising"
    hash = @results_hash[:checkin][:merchandising_state_evaluations_attributes]
    index_to_delete = hash.find_index{|i| i[:stage_id] == 5 && i[:placement_id] == 1}
    hash.delete_at(index_to_delete)
  when "initial merchandising"
    hash = @results_hash[:checkin][:merchandising_state_evaluations_attributes]
    index_to_delete = hash.find_index{|i| i[:stage_id] == 4 && i[:placement_id] == 1}
    hash.delete_at(index_to_delete)
  when "initial price tags"
    hash = @results_hash[:checkin][:price_tag_evaluations_attributes]
    index_to_delete = hash.find_index{|i| i[:stage_id] == 4 && i[:placement_id] == 2}
    hash.delete_at(index_to_delete)
  when "secondary price tags"
    hash = @results_hash[:checkin][:price_tag_evaluations_attributes]
    index_to_delete = hash.find_index{|i| i[:stage_id] == 5 && i[:placement_id] == 2}
    hash.delete_at(index_to_delete)
  when "secondary category stock"
    hash = @results_hash[:checkin][:category_stock_evaluations_attributes]
    index_to_delete = hash.find_index{|i| i[:stage_id] == 5 && i[:placement_id] == 2}
    hash.delete_at(index_to_delete)
  else
    raise "unhandled case"
  end
end
     
When /^I send a checkin$/ do
  post "/api/checkins.json", @results_hash, @version_and_auth_header
end

Then /^I should (not )?receive an error(?> "(.+)")?$/ do |without_error, message|
  response_body = JSON.parse(last_response.body)
  if without_error
    response_body['code'].should eq 200
  else
    response_body['code'].should eq 400
    response_body['errors'].any?{|i| i.include?(message)}.should == true
  end
end

Then /^I should see both displayed properly for v1$/ do
  @response.status.should == 200
  json = JSON.parse(@response.body)
  json['lenta'].map{|i| i['merchandiser']}.sort.should == [@merch.name, @teamlead.name].sort
end

Then /^I should see both displayed properly for v2$/ do
  @response.status.should == 200
  json = JSON.parse(@response.body)
  json['lenta'].map{|i| i['merchandiser']}.sort.should == [@merch.name, @teamlead.name].sort

  merch_lenta_item = json['lenta'].find{|i| i['merchandiser'] == @merch.name}
  merch_lenta_item['report']['additional']['merchandising'] == 'удовлетворительно'
  merch_lenta_item['report']['additional']['price_tags'] == 'fresh'
  merch_lenta_item['report']['additional']['skus'] == {"critical"=>1, "total"=>1}
  
  tl_lenta_item = json['lenta'].find{|i| i['merchandiser'] == @teamlead.name}
  tl_lenta_item['report']['additional']['merchandising'] == 'хорошо'
  tl_lenta_item['report']['additional']['price_tags'] == 'not_fresh'
  tl_lenta_item['report']['additional']['skus'] == {"critical"=>1, "total"=>1}
end

When /^I retrieve my v(.+) lenta feed$/ do |version|
  get '/api/lenta_items.json', {}, @version_and_auth_header
  @response = last_response
end
  
And /^AWS migration has some kind of bottleneck$/ do
  prevent_image_from_aws_migration
end
    
Then /^I should not see any still_expected_photos at \/nearby or \/plan_items query$/ do
  location = Location.joins(:checkins).where(checkins: {id: @checkin_id}).first
  current_coordinates = {latitude: location.lat, longitude: location.long}

  get '/api/locations/nearby.json', current_coordinates, @version_and_auth_header
  json = JSON.parse last_response.body
  expect(json['locations'].find{|i| i["location_id"] == location.id}['checkin_photos_waiting']).to eq 0

  get '/api/plan_items.json', {}, @version_and_auth_header
  json = JSON.parse last_response.body
  expect(json['20.03.2015'].find{|i| i['location_id'] == location.id}['checkin_photos_waiting']).to eq 0
end
    
And /^my supervisor should see those photos as not processed still$/ do
  step "I re-login through API as supervisor" 
  get '/api/lenta_items.json', {}, @version_and_auth_header
  json = JSON.parse last_response.body
  expect(json['lenta'][0]['photos']['waiting']).to eq 1
end

And /^he should see them as processed after S3 migration is done$/ do
  restore_aws_migration_functionality
  reupload_photo_to_aws
  
  get '/api/lenta_items.json', {}, @version_and_auth_header
  json = JSON.parse last_response.body
  expect(json['lenta'][0]['photos']['waiting']).to eq 0
end
