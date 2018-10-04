# coding: utf-8
And(/^I am on the locations list page$/) do
  visit '/locations'
end

def select_from_chosen text, options
  selector = options[:from]
  find(selector).click
  find("#{selector} ul.chosen-results li", :text => text).click
end

def approve_bootbox_modal
  page.find('.modal-dialog .btn-primary').click
end

Then(/^I see a list of locations$/) do
  Location.should be_any

  Location.owned_by_organization(@teamlead.organization_id).each do |location|
    page.should have_link location.address.strip
  end
end

def select_locations_presented_on_page initial_query
  available_on_page = page.all('table tr.single_location_row').map{|i| i[:id].match(/location_(\d+)_row/)[1]}
  initial_query.where(:locations => {:id => available_on_page})
end

When(/^I click on some location$/) do
  initial_query = Location.owned_by_organization(@teamlead.organization_id).
                    joins(:company).select('locations.*')
  @location = select_locations_presented_on_page(initial_query).first

  [1,2].each do |n|
    FactoryGirl.create :signboard, company: @location.company, name: "Вывеска #{n}"
  end
  @new_company = FactoryGirl.create :company, organization_id: @teamlead.organization_id
  %w[А Б].each do |n|
    FactoryGirl.create :signboard, company: @new_company, name: "Вывеска #{n}"
  end
  @location.update_attributes(:city => 'Moscow', :country => 'Russia') if @location.city.blank? || @location.country.blank?
  click_link @location.address
end

Then(/^I see this location description$/) do
  page.should have_content @location.address
end

And(/^There (?>are|is) some checkins$/) do
  location = Location.owned_by_organization(@teamlead.organization_id).first
  @checkins = [].tap do |checkins|
    3.downto(1).each do |n|
      time_to_travel = (Time.now - n.days).end_of_day - 5.hours
      Timecop.freeze(time_to_travel) do
        merch = FactoryGirl.create :merchendiser, supervisor: @teamlead
        one_checkin = FactoryGirl.build(:checkin, location: location, user: merch, finished_at: Time.now)
        creator = CheckinCreator.new(parameters: one_checkin.attributes, current_user: merch)
        creator.save
        checkins << creator.checkin
      end
    end
  end
  time_to_travel = (Time.now - 1.days).end_of_day - 4.hours
  Timecop.freeze(time_to_travel) do
    @other_checkins = [].tap do |arr|
      Location.owned_by_organization(@teamlead.organization_id).first(2).each do |location|
        one_checkin = FactoryGirl.build(:checkin, location: location, finished_at: Time.now)
        creator = CheckinCreator.new(parameters: one_checkin.attributes, current_user: one_checkin.user)
        creator.save
        arr << creator.checkin
      end
    end
  end
end

And(/^Visited locations should be marked with last visit time$/) do
  Location.where(:id => @checkins.map{|i| i.location_id}).pluck(:address).each do |address|
    within(:xpath, %Q{//a[contains(text(),"#{address}")]/../..}) do
      page.should have_content 'вчера'
    end
  end
end

And(/^Unvisited locations should be marked as unvisited$/) do
  Location.owned_by_organization(@teamlead.organization_id).where(:id.not_in => @checkins.map{|i| i.location_id}).each do |location|
    within(:xpath, %Q{//a[contains(text(),"#{location.address}")]/../..}) do
      page.should have_content 'Посещений не было'
    end
  end
end

Given(/^there is a confirmer in the database$/) do
  @confirmer = User.content_managers.first || FactoryGirl.create(:content_manager)
end

Then(/^I see location editing form$/) do
  page.should have_css "form#edit_location_#{@location.id}"
end

When(/^I change location type to something different$/) do
  @new_location_type = LocationType.where(:id.not_eq => @location.location_type_id).first.name
  select @new_location_type, from: 'Тип торговой точки'
end

And(/^confirmer receives a message with confirmation$/) do
  sleep(2)
  Message.where(receiver_id: @confirmer.id, sender_id: @teamlead.id, :title.matches => 'Подтверждение изменения%').should be_any
end

When(/^I re\-login as a confirmer$/) do
  visit '/users/sign_out'
  sign_in(@confirmer)
end

And(/^I click on location reference of the message$/) do
  within(:xpath, '//tr[contains(., "Location")]') do
    click_link 'Location'
  end
end

And(/^I confirm changes of (location|company)$/) do |object|
  outbound_tag =  if object == 'location'
                    "#confirm_location_#{@location.id}"
                  else
                    'body'
                  end
  within(outbound_tag) do
    page.find('.confirm_changes').click
  end
end

And /^I change company name to non-existant one$/ do
  @new_company_name = 'вот это поворот'
  fill_in 'location_company_name', with: @new_company_name
end

Then /^attributes are changed to the new ones$/ do
  old_company_id = @location.company_id
  @location.reload
  @location.company_id.should_not == old_company_id
  @location.company.name.should == @new_company_name
  @location.location_type.name.should == @new_location_type
end

And(/^message is sent to user who edited the location$/) do
  msg =   Message.where(receiver_id: @teamlead.id,
                        sender_id: @confirmer.id,
                        :body.matches => "%#{@location.address}%",
                        :body.matches => "%одобрен%",
                        :created_at.gteq => Time.now - 2.minutes)
  msg.should be_any
end

And(/^another teamlead in the database$/) do
  @another_teamlead = FactoryGirl.create :teamlead
  FactoryGirl.create :user, invited_by: @another_teamlead
end

When(/^I re\-login as another teamlead$/) do
  visit '/users/sign_out'
  sign_in(@another_teamlead)
end

And(/^visit this location$/) do
  visit "/locations/#{@location.id}"
end

And(/^location type is old$/) do
  page.should have_content @location.location_type.name
  page.should_not have_content @new_location_type
end

When(/^I change location$/) do
  step 'I click on some location that has photo'
  step 'I click on "Редактировать Т.Т."'
  step 'I see restriction message about editing locations'
  step 'I change location type to something different'
  step 'I change existing photo to something different'
end

Given /^confirmer refuses that change$/ do
  step "I re-login as a confirmer"
  step "I do not confirm the changes"
end

And(/^I do not confirm the changes$/) do
  sleep(2)
  page.find('.refuse_changes').click
end

Then(/^cancel confirmation message is sent to user who edited the location$/) do
  msg =   Message.where(receiver_id: @teamlead.id,
                        sender_id: @confirmer.id,
                        :body.matches => "%#{@location.address}%",
                        :body.matches => "%отклонен%",
                        :created_at.gteq => Time.now - 2.minutes)
  msg.should be_any
end

When(/^I re\-login as a teamlead$/) do
  visit '/users/sign_out'
  sign_in(@teamlead)
end
        
Given /^there are some subordinates$/ do
  emails = [{email: "otaraeva@test.com", name: 'Отараева'},{email: "frolova@test.com", name: 'Фролова'}]
  subordinates = User.where(:email => emails.map{|e| e[:email]}).all
  emails.each do |email|
    user = subordinates.find{|i| i.email == email[:email]}
    unless user 
      user = FactoryGirl.build :user
      user.email = email[:email]
      user.password = email[:email]
      user.password_confirmation = email[:email]
    end
    user.name = email[:name]
    user.role = "merchendiser"
    user.supervisor_id = @teamlead.id
    user.organization_id = @teamlead.organization_id
    user.save!
  end
end

When /^I go to the page of that location$/ do
  click_link @location.address
end

And /^I (?>should )?see that "(.+)" checkbox is( not)? checked$/ do |email, false_flag|
  user_id = User.where(:email => email).first.id
  checkbox = page.find("#location_inspector_ids_#{user_id}")
  if false_flag
    checkbox.should_not be_checked
  else
    checkbox.should be_checked
  end
end

And /^I swap "(.+)" with "(.+)"$/ do |user_was, user_now|
  check "#{user_now} (мерч)"
  uncheck "#{user_was} (мерч)"
  click_button "Сохранить"
end

And(/^I am at (?>owned )?location page$/) do
  user = @merchendiser || @teamlead || @user || @otaraeva
  @location = FactoryGirl.create(:location, :signboard_name => 'Магазинчик Бо', :organization_id => user.organization_id)
  #LocationOrganization.create(:location_id => @location.id, :organization_id => user.organization_id)
  visit location_path(@location)
end

And /^there are some skus in sku_categories exist$/ do
  SkuUploader.new({"user_organization_id" => @teamlead.organization_id, "behaviour" => "test"}).do_work
end

And /^locations exist in database$/ do
  db_name = Rails.configuration.database_configuration[Rails.env]["database"]
  `psql -h localhost -1 #{db_name} < data/companies.sql`
  `psql -h localhost -1 #{db_name} < data/locations_january.sql`
end

Given /^valid location_types and location_categories exist$/ do
  ['market', 'trade center', 'black merchant'].each do |i|
    LocationType.where(:name => i).first_or_create
  end
  
  ['A', 'B', 'C', 'D', 'E', 'F'].each do |i|
    LocationCategory.where(:name => i).first_or_create
  end
end

And /^there are locations owned by my organization$/ do
  # NOTE: don't touch! used by mapping_assign scenario, should use the addresses at given coordinates
  addresses =
    ["Москва, улица Трофимова, 15",
     "Москва, Барвихинская улица, 6",
     "Москва, Подольская улица, 20/23к1",
     "Москва, Ленинский проспект, 86",
     "Одинцовский район, поселок Горки-10, 21",
     "Одинцовский район, село Немчиновка, Амбулаторная улица, 49а",
     "Серпухов, улица Ворошилова, 241",
     "Санкт-Петербург, улица Седова, 15",
     "Санкт-Петербург, 13-я линия В.О., 12",
     "Нижний Новгород, микрорайон Ипподромный, Снежная улица, 14"
     ]

  Location.where(:address.in => addresses).each do |location|
    location.organization_id = @teamlead.organization_id
    location.company.organization_id = @teamlead.organization_id
    location.external_id = "SOME-ID#{location.id}"
    location.save!
  end
  #Location.where(:address.in => addresses).pluck(:id).each do |location_id|
  #  LocationOrganization.create :location_id => location_id, :organization_id => @teamlead.organization_id
  #end
end

And /^custom reports are assigned to locations$/ do
  Location.owned_by_organization(@teamlead.organization_id).each do |loc|
    loc.update! checkin_type: CheckinType.last
  end
end
    
Given /^I see only locations owned by my organization$/ do
  @owned_locations = Location.owned_by_organization(@teamlead.organization_id)
  @not_owned_locations = Location.where(:id.not_in => @owned_locations.pluck(:id))
  within('.locations_list') do
    @owned_locations.limit(5).pluck(:address).each do |address|
      page.should have_content address
    end
    page.should have_css('tr.single_location_row', count: @owned_locations.size)
  end
end

Then /^I should see only locations with that parameters$/ do
  locations_of_that_category = Location.where(:location_category_id => @category_id).pluck(:address)
  within('.locations_list') do
    locations_of_that_category[0..10].each do |location_address|
      page.should have_content location_address
    end
    page.should have_css('tr.single_location_row', count: locations_of_that_category.size)
  end
end

And /^I should see not only owned locations$/ do
  within('.locations_list') do
    page.should have_content @not_owned_locations.first.address
  end
end
    
When /^I remove "(\d+)" locations from owned list$/ do |amount|
  amount = amount.to_i
  @owned_locations = Location.owned_by_organization(@teamlead.organization_id).all
  @owned_locations[0..amount-1].each do |owned_loc|
    within('.locations_list') do
      check "location_#{owned_loc.id}"
      within "#company_#{owned_loc.company_id}_actions" do
        click_on 'Удалить из моего списка точек'
      end
    end
    click_on 'Продолжить'
    sleep(1)
  end
end
    
Then /^there should be "(\d+)" locations removed$/ do |amount|
  visit '/locations'
  sleep(2)
  amount = amount.to_i
  removed_locations = @owned_locations[0..amount-1]
  Location.where(id: removed_locations.map{|i| i.id}, organization_id: @teamlead.organization_id).should_not be_any
  #LocationOrganization.where(location_id: removed_locations.map{|i| i.id}, organization_id: @teamlead.organization_id).should_not be_any
  removed_locations.each do |location|
    page.should_not have_content location.address
  end
end

#Then /^I should see "(\d+)" locations removed and "(\d+)" added$/ do |removed_amount, added_amount|
Then /^there should be "(\d+)" locations removed and "(\d+)" added$/ do |removed_amount, added_amount|
  #visit '/locations'
  removed_amount  = removed_amount.to_i - 1
  added_amount    = added_amount.to_i - 1
  new_owned_size  = @owned_locations.size - removed_amount + added_amount
  #persistant_for_org = LocationOrganization.where(:organization_id => @teamlead.organization_id)
  persistant_for_org = Location.where(:organization_id => @teamlead.organization_id)
  persistant_for_org.where(:id => @owned_locations[0..removed_amount]).count.should == 0
  persistant_for_org.where(:id => @not_owned_locations[0..added_amount]).count.should == added_amount + 1

  #within('.locations_list') do
  #  @owned_locations[0..removed_amount].each do |was_owned_loc|
  #    within "#location_#{was_owned_loc.id}_row" do
  #      page.should_not have_text 'В моём списке'
  #    end
  #  end
  #  @not_owned_locations[0..added_amount].each do |was_not_owned_loc|
  #    within "#location_#{was_not_owned_loc.id}_row" do
  #      page.should have_text 'В моём списке'
  #    end
  #  end
  #  page.should have_text 'В моём списке', count: new_owned_size
  #end
end

And /^I click to (add|remove) all the locations of company$/ do |action|
  within "tr#company_#{@company.id}_actions" do
    click_on 'Выбрать все'
    case action
      when 'add' then click_on 'Добавить в мой список точек'
      when 'remove' then click_on 'Удалить из моего списка точек'
    end
    sleep 2
  end
  approve_bootbox_modal
  sleep 2
end

Then /^I should see all the locations of that company as (added|removed)$/ do |result|
  select_from_chosen @company.name, from: '#q_company_id_eq_chosen'
  within 'form#location_search' do
    find('button').click
  end

  were_owned = @owned_locations.select{|i| i.company_id == @company.id}
  currently_owned = Location.owned_by_organization(@teamlead.organization_id).where(company_id: @company.id).all

  within('.locations_list', visible: false) do
    case result
      when 'removed'
        were_owned.each do |location|
          within "#location_#{location.id}_row" do
            page.should_not have_text location.address
          end
        end
      when 'added'
        currently_owned.each do |location|
          within "#location_#{location.id}_row" do
            page.should have_text location.address
          end
        end
    end
  end
end

And(/^I see the list of company signboards in select field$/) do
  page.should have_select 'Вывеска', with_options: ['Вывеска 1', 'Вывеска 2']
end

When(/^I change the company$/) do
  fill_in 'location_company_name', with: @new_company.name
end

Then(/^list of signboards changes$/) do
  page.should have_select 'Вывеска', with_options: ['Вывеска А', 'Вывеска Б']
end

And(/^I don't see visits of other teams$/) do
  @other_checkins.each do |checkin|
    page.should_not have_content %Q|<a href="/checkins/#{checkin.id}">|
  end
end

Then(/^I should be able to delete location$/) do
  page.should have_field 'Удалить торговую точку?', type: 'checkbox'
end

When(/^I delete location with reason "(.+)"$/) do |reason|
  check 'Удалить торговую точку?'
  fill_in 'Причина удаления', with: reason
  click_on 'Сохранить'
end

And(/^I delete another location$/) do
  initial_query = Location.owned_by_organization(@teamlead.organization_id).joins(:company).
      select('locations.*').offset(1)
  #step 'I am on the locations list page'
  step 'I visit my locations list'
  @another_location = select_locations_presented_on_page(initial_query).first
  click_link @another_location.address
  step 'I click on "Редактировать Т.Т."'
  step 'I see restriction message about editing locations'
  step 'I delete location with reason "Просто так"'
end

And(/^he refuses to delete another location$/) do
  within("#confirm_location_#{@another_location.id}") do
    page.find('.refuse_changes').click
  end
end

Then(/^location is deleted$/) do
  Location.where(id: @location.id).should_not exist
end

And(/^another location is presented$/) do
  Location.where(id: @another_location.id).should exist
end

When /^I assign my subordinate as an inspector of the same location$/ do
  @my_merch = FactoryGirl.create(:merch, :supervisor_id => @teamlead.id, :organization_id => @teamlead.organization_id)
  visit "/locations/#{@location.id}"
  page.find("#location_inspector_ids_#{@my_merch.id}").set(true)
  click_on "Сохранить"
end
  
Then /^there should be two inspectors in a sum$/ do
  page.should have_content 'Список ответственных за посещение обновлен'
  InspectorLocation.where(:location_id => @location.id).pluck(:inspector_id).sort.should == [@another_merch.id, @my_merch.id]
end

Then /^I see restriction message about editing locations$/ do
  sleep(1)
  page.should have_content(I18n.t('alerts.resource_editing', :resource => 'точке'))
  approve_bootbox_modal
end

When(/^I visit my locations list$/) do
  visit '/locations'
end

Then /^location should have the freshly uploaded photo$/ do
  visit "/locations/#{@location.id}"
  @location.reload.photo.should_not be_nil
  @location.photo.image_file_name.should == 'tiger.jpg'
end

When(/^I click on some location that has photo$/) do
  step 'I click on some location'
  @initial_photo = FactoryGirl.create :photo, picturable: @location, picturable_type: 'Location'
end

When /^I ask to approve a photo for location$/ do
  step %Q{I click on some location}
  step %Q{I click on "Редактировать Т.Т."}
  step %Q{I see restriction message about editing locations}
  step %Q{I see location editing form}
  step %Q{I upload location photo}
  step %Q{I see message "Ваши изменения отправлены на подтверждение администратору"}
  step %Q{confirmer receives a message with confirmation}
end

And /^confirmer does not mind$/ do
  step %Q{I re-login as a confirmer}
  step %Q{I confirm changes of location}
end
      
When /^I change existing photo to something different$/ do
  find('#replace_location_photo').click
  step %Q{I upload location photo}
end
      
Then /^old location photo should not exist$/ do
  Photo.where(:id => @initial_photo.id).should_not be_any
end
    
And /^old photo is still shown$/ do
  photo_before_edit = @location.photo
  photo_now         = @location.reload.photo
  photo_before_edit.should == photo_now
end
    
When /^I click on location which is on confirmation by another team$/ do
  @another_address = 'Пермь, улица Павла Соловьева, 1'
  @location = Location.first
  @location.send_on_confirmation({object: {:address => @another_address}}, sender: FactoryGirl.create(:supervisor))
  visit "/locations/#{@location.id}"
end

And /^I should see the old information about it$/ do
  page.should_not have_text @another_address
  page.should have_text @location.address
  page.should_not have_text "Редактировать Т.Т."
end

When /^I upload invalid photo for location$/ do
  step 'I click on some location'
  step 'I click on "Редактировать Т.Т."'
  photo_path = %w(spec fixtures valid_locations.xlsx)
  find('#location_photo_attributes_image').set File.join(Rails.root, *photo_path)
  click_on 'Сохранить'
end

Then /^I should see an error about uploaded file$/ do
  page.should have_content 'тип файла не поддерживается'
  current_path.should == "/locations/#{@location.id}"
end

And /^changes should not be saved$/ do
  @location.reload.photo.should be_nil
end
    
Given /^I have "(\d+)" locations of "(.+)" owned$/ do |amount, company_name|
  @company = Company.find_by(name: company_name)
  @company.update_attribute :organization_id, @teamlead.organization_id
  locations = @company.locations.limit(amount.to_i)
  locations.update_all :organization_id => @teamlead.organization_id
  #locations.each do |loc|
  #  LocationOrganization.create location_id: loc.id, organization_id: @teamlead.organization_id
  #end
  @owned_locations = Location.owned_by_organization(@teamlead.organization_id)
end
    
When(/^I upload location photo$/) do
  photo_path = %w(spec fixtures tiger.jpg)
  find('#location_photo_attributes_image').set File.join(Rails.root, *photo_path)
  click_on 'Сохранить'
end
    
And /^all the locations are owned$/ do
  user    = @merchendiser || @teamlead || @user || @otaraeva
  org_id  = user.organization_id
  Location.update_all organization_id: org_id
  Company.update_all  organization_id: org_id
end

Then /^I should not see remove_location buttons$/ do
  page.should_not have_selector '.company_actions'
  page.should_not have_selector '.remove_selected'
  page.should_not have_selector '.select_all'
  page.should_not have_text 'Выбрать все'
  page.should_not have_text 'Удалить из моего списка точек'
end

And /^I should not see any input fields to mark them$/ do
  random_id = Location.where(organization_id: @teamlead.organization_id).first.id
  within "tr#location_#{random_id}_row" do
    page.should_not have_selector 'input'
    page.should have_selector '.in_my_list'
    page.should have_text "В моём списке"
  end
end

And(/^all my locations is unassigned$/) do
  InspectorLocation.joins(:location => :organization).where(location: {organization: {id: @teamlead.organization_id}}).destroy_all
end

When(/^I visit unassigned locations page$/) do
  visit '/locations/unassigned'
end

Then(/^I see unassigned locations$/) do
  @teamlead.organization.locations.unassigned.find_each do |location|
    page.should have_text location.full_name
  end
end

When(/^I check and delete unassigned locations$/) do
  within '.deletable_locations' do
    @teamlead.organization.locations.unassigned.find_each do |location|
      within 'tr', text: location.full_name do
        find('label').click
      end
    end
    click_on 'Удалить'
  end
  click_on 'Продолжить'
  sleep 0.5
end

Then(/^unassigned locations is removed$/) do
  Location.owned_by_organization(@teamlead.organization_id).unassigned.should_not be_any
end
