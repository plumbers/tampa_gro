namespace :one_time do
  def execution_time(t)
    ap "Task executed in #{(Time.now - t)/60} minutes"
  end

  desc "clear teamlead descendants and location_organizations for given phones"
  task :clear_teamlead_descendants_and_my_locations => :environment do
    phones = ENV['PHONES'].split(',').map(&:strip)
    phones.each do |phone|
      cu = User.find_by(mobile_phone: phone, role: :teamlead)
      cu.descendants.where(role: :merchendiser).find_each do |merch|
        destroyer = UserDestroyer.new(cu)
        destroyer.destroy(merch)
        ap destroyer.notifications
      end
      cu.descendants.where(role: :supervisor).find_each do |sv|
        destroyer = UserDestroyer.new(cu)
        destroyer.destroy(sv)
        ap destroyer.notifications
      end
      cu.organization.location_organizations.destroy_all
    end
  end

  def create_boss_version(boss)
    boss.touch_with_version
    boss.versions.first
  end

  desc 'fill in h_vector and timezone for UserVersion'
  task :fill_h_vector_and_timezone => :environment do
    t = Time.now

    sql = <<-SQL.strip_heredoc
      SELECT uv1.*, uv3.h_vector AS new_h_vector, uv3.timezone AS new_timezone FROM user_versions uv1 
        LEFT JOIN LATERAL (
          SELECT uv2.*
          FROM user_versions uv2 
          WHERE uv1.item_id = uv2.item_id 
          AND uv2.created_at > uv1.created_at 
          AND (uv2.h_vector->>1) IS NOT NULL
          AND uv2.h_vector @> (uv1.object_changes->'supervisor_id'->1)
          AND uv2.h_vector != uv1.h_vector
          AND uv2.timezone != 'uninhabited'
          ORDER BY uv2.created_at 
          LIMIT 1) uv3
        ON true
        WHERE (uv1.created_at::date BETWEEN '2017-01-01' AND '2017-06-14')
        AND (uv1.object_changes->'supervisor_id'->>1) IS NOT NULL
        AND ((uv1.h_vector->>1) IS NULL
          OR NOT uv1.h_vector @> (uv1.object_changes->'supervisor_id'->1))
    SQL

    vers = UserVersion.find_by_sql(sql)
    ap "Found #{vers.size} affected versions"

    vers.each do |ver|
      ap "start #{ver.id}"

      ActiveRecord::Base.transaction do
        if ver.new_h_vector.present? && ver.new_h_vector.include?(ver.actual_attr_set['supervisor_id'])

          ver.h_vector = ver.new_h_vector
          ver.timezone = ver.new_timezone

        else

          hierarchy = []
          timezone = nil
          time_point = ver.created_at

          supervisor_id = ver.actual_attr_set['supervisor_id']
          next if supervisor_id.nil?

          until supervisor_id.nil? do
            hierarchy << supervisor_id
            # boss          = UserUnscoped.find(supervisor_id)

            boss_version = UserVersion.where(item_id: supervisor_id).
              where('created_at <= ?', time_point).
              order(:created_at).last

            if boss_version.nil? || boss_version.event == 'destroy'
              supervisor_id = nil
              # boss_version = create_boss_version(boss)
              # boss_version.update_columns created_at: ver.created_at - 1.minute
            else

              attrs = boss_version.actual_attr_set
              # ap attrs

              (timezone = attrs['timezone'] || boss_version.user.timezone) if attrs['role'] == 'supervisor'

              supervisor_id = attrs['supervisor_id']
            end

          end

          ver.timezone ||= timezone
          ver.h_vector = hierarchy

        end
        ap ver.changes
        ver.save!
      end

    end
    ap execution_time(t)
  end


  def no_changes?(version)
    if @processed_versions.present? && last_event = @processed_versions.select { |v| v.event == version.event }.last
      @processed_versions.last.id if last_event.diff(version).blank?
    elsif @existing_versions.present? && last_event = @existing_versions.select { |v| v.created_at <= version.created_at && v.event == version.event }.last
      last_event.id if last_event.diff(version).blank?
    else
      false
    end
  end

  def rerouting?(history, i)
    i > 0 &&
      (history[i-1].diff(history[i]).keys - ['route_id']).blank? &&
      history[i].route_id.nil? &&
      history[i+1] &&
      history[i+1].route_id != nil &&
      history[i+1].created_at - history[i].created_at < 2.seconds
  end

  desc 'fill in h_vector for Checkin'
  task :fill_checkin_h_vector_from_user_version => :environment do
    puts ActiveSupport::Deprecation.warn("This rake task is deprecated. It's remains for history only")
    exit
    t = Time.now
    skipped = 0
    ap "Getting checkins"
    checkins = Checkin.where('created_at > ?', '2015-12-01'.in_time_zone('Asia/Vladivostok'))

    total = checkins.count
    left = total
    ap "Total: #{total}"

    ap "Processing checkins"
    checkins.find_in_batches(batch_size: 2000).each do |b|
      ap "--------- Processing 2000 of #{left} left ------------"
      left = left - 2000
      b.each do |c|
        #next unless c.h_vector.blank?
        ver = UserVersion.where(item_id: c.user_id).
          where('created_at < ?', c.created_at).
          order(:created_at).last

        if ver
          ap "Using version at #{ver.created_at}, checkin: #{c.created_at}" #To prevent disconnect
          c.update_column :h_vector, ver.h_vector.to_json
        else
          skipped += 1
          euv = c.user.versions.order(:created_at).first
          ap "Checkin skipped:  id => #{c.id}, started_at => #{c.started_at}, created_at => #{c.created_at}, earliest user_version => #{euv.created_at}"
        end
      end
    end
    ap "Task executed in #{Time.now - t} seconds"
    ap "Skipped checkins: #{skipped} of #{total}"
  end

  desc 'fill in user_version_id for Checkin'
  task :fill_checkin_user_version_id => :environment do
    t = Time.now
    skipped = 0
    ap "Getting checkins"
    checkins = Checkin.where('created_at > ?', '2015-12-01'.in_time_zone('Asia/Vladivostok'))

    total = checkins.count
    left = total
    ap "Total: #{total}"

    ap "Processing checkins"
    checkins.find_in_batches(batch_size: 2000).each do |b|
      ap "--------- Processing 2000 of #{left} left ------------"
      left = left - 2000
      b.each do |c|
        #next unless c.h_vector.blank?
        ver = UserVersion.where(item_id: c.user_id).
          where('created_at < ?', c.created_at).
          order(:created_at).last

        if ver
          ap "Using version at #{ver.created_at}, checkin: #{c.created_at}" #To prevent disconnect
          c.update_column :user_version_id, ver.id
        else
          skipped += 1
          euv = c.user.versions.order(:created_at).first
          ap "Checkin skipped:  id => #{c.id}, started_at => #{c.started_at}, created_at => #{c.created_at}, earliest user_version => #{euv.created_at}"
        end
      end
    end
    ap "Task executed in #{Time.now - t} seconds"
    ap "Skipped checkins: #{skipped} of #{total}"
  end

  desc 'Invoke all tasks needed for new scorecard export system'
  task :scorecard_infrastructure_prepare => :environment do
    ['one_time:create_versions_from_history',
     'one_time:fill_h_vector_and_timezone',
     'one_time:fill_checkin_user_version_id'].each do |task_name|
      Rake::Task[task_name].invoke
    end
  end

  desc 'Change ScorecardCache event_type from Checkin to AuditCheckin if entry is audited checkin'
  task :scorecard_cache_checkin_to_audit_checkin => :environment do
    ScorecardCache.where(event_type: 'Checkin').where("event @> ?", '{"merchendiser_fio": "N/A", "merchendiser_tel": "N/A"}').find_each do |cache|
      cache.update_column :event_type, 'AuditCheckin'
    end
  end

  desc 'Restart ScorecardJob to partially include missing plan items'
  task :scorecard_cache_partial_update => :environment do
    date_range = Date.parse('2016-07-01')..Date.parse('2016-07-05')
    date_range.each do |parse_date|
      ScorecardJob.where(scorecard_date: parse_date).each do |job|
        jid = ScorecardGeneratorWorker.perform_async(job.id)
        job.update! jid: jid
      end
    end
  end

  desc 'Set location_id and checkin_user_id for lenta_items'
  task set_data_to_lenta_items: :environment do
    puts 'START'
    max_id = LentaItem.order(:id).last.try(:id)
    if max_id
      min_id = max_id - 10000
      min_id = 0 if min_id < 0
      while max_id > 0
        puts "#{min_id} - #{max_id}"
        ActiveRecord::Base.connection.execute <<-SQL
          update lenta_items set location_id = (select c.location_id
            from checkins c
            where c.id = lenta_items.checkin_id
          ),
          checkin_user_id = (select c.user_id
            from checkins c
              where c.id = lenta_items.checkin_id
          )
          where lenta_items.id between #{min_id} AND #{max_id}
            AND (lenta_items.location_id is null OR lenta_items.checkin_user_id is null)
            AND lenta_items.checkin_id is not null;

          update lenta_items set location_id = (select c.location_id
            from checkin_lites c
            where c.id = lenta_items.checkin_lite_id
          ),
          checkin_user_id = (select c.user_id
            from checkins c
              where c.id = lenta_items.checkin_lite_id
          )
          where lenta_items.id between #{min_id} AND #{max_id}
            AND (lenta_items.location_id is null OR lenta_items.checkin_user_id is null)

            AND lenta_items.checkin_lite_id is not null;
        SQL
        max_id = min_id
        min_id = max_id - 10000
        min_id = 0 if min_id < 0
      end
    end
    puts 'END'
  end

  desc 'Update Location#timezone'
  task :update_location_timezone => :environment do
    Location.where(timezone: nil).find_each do |loc|
      timezone = loc.send(:set_timezone)
      loc.update_columns timezone: timezone
    end
  end

  desc 'Update User.supervisors#timezone'
  task :update_supervisor_timezone => :environment do
    i = 0
    User.supervisors.where(timezone: nil).find_each do |supervisor|
      merch = supervisor.descendants.merchendisers.first
      next unless merch
      tz = merch.inspector_locations.first.try(:location).try(:timezone)
      supervisor.timezone = tz
      supervisor.save(validate: false)
      supervisor.descendants.each do |user|
        user.timezone = tz
        user.save(validate: false)
      end
      i +=1
    end
    ap "Updated #{i} supervisors"
  end

  desc 'Update User.merchendisers#timezone'
  task :update_merchendiser_timezone => :environment do
    i = 0
    merches = User.merchendisers.where(timezone: nil).where.not(supervisor_id: nil)
    merches_count = merches.size
    merches.find_each do |merch|
      tz = merch.inspector_locations.first.try(:location).try(:timezone)
      merch.timezone = tz
      merch.save(validate: false)
      i += 1
      ap "Updated #{i} of #{merches_count} merchendisers" if i%100 == 0
    end
    ap "Updated #{i} merchendisers"
  end

  desc 'Clean spaces from location critical fields'
  task clean_spaces_from_location_critical_fields: :environment do
    Location.includes(:company, :signboard).find_each do |loc|
      a0 = loc.address
      if a0
        a1 = a0.to_s.gsub(/[[:space:]]+/, ' ').strip
        if a0 != a1
          loc.update_column(:address, a1)
          ap "#{a0} -> #{a1}"
        end
      end

      s0 = loc.signboard.try(:name)
      if s0
        s1 = s0.to_s.gsub(/[[:space:]]+/, ' ').strip
        if s0 != s1
          loc.signboard.update_column(:name, s1)
          ap "#{s0} -> #{s1}"
        end
      end

      c0 = loc.company.try(:name)
      if c0
        c1 = c0.to_s.gsub(/[[:space:]]+/, ' ').strip
        if c0 != c1
          loc.company.update_column(:name, c1)
          ap "#{c0} -> #{c1}"
        end
      end
    end
  end

  desc 'Set businesses to descendants of executives'
  task set_businesses_to_descendants: :environment do
    User.where(role: 'executive') do
      user.descendants.where(business_id: nil).update_all(business_id: user.business_id) if user.business_id.present?
    end
  end

  desc 'set organization_id in [checkins, checkin_lites]'
  task :set_org_lenta_items => :environment do
    t = Time.now
    [:checkins, :checkin_lites].each do |table|
        statement = <<-SQL
        DROP INDEX index_#{table}_on_organization_id;
        UPDATE #{table}
        SET organization_id = user_org_id
        FROM (
              SELECT ch.id chid, u.organization_id user_org_id
              FROM #{table} ch
              INNER JOIN users u ON u.id=user_id
        )d
        WHERE id=chid;
        CREATE INDEX index_#{table}_on_organization_id  ON public.#{table} (organization_id);
        SQL
        ActiveRecord::Base.connection.execute statement
    end
    execution_time(t)
  end

  desc 'remove duplicates of kpi_aggregates'
  task remove_kpi_aggregates_duplicates: :environment do
    months = Hash.new { |hash, key| hash[key] = [] }
    puts 'START'
    KpiAggregate.transaction do
      KpiAggregate.select('location_ext_id, kpi_template_id, plan_month, count(*)').
        group('location_ext_id, kpi_template_id, plan_month').
        having('count(*) > 1').each do |agg|
        real = KpiAggregate.where(location_ext_id: agg.location_ext_id,
                                  kpi_template_id: agg.kpi_template_id,
                                  plan_month: agg.plan_month).
          order(:created_at).last
        puts real.id
        KpiAggregate.where(location_ext_id: agg.location_ext_id,
                           kpi_template_id: agg.kpi_template_id,
                           plan_month: agg.plan_month).
          where.not(id: real.id).
          delete_all
        date = agg.plan_month

        months[date] << agg.kpi_template_id
      end

      months.each do |date, kpi_template_ids|
        puts "START RECALC FOR #{date}"
        Kpi::Checkins::MonthCalculator.new(date, kpi_template_ids: kpi_template_ids.uniq).calculate!
        puts "END RECALC FOR #{date}"
      end
    end
    puts 'END'
  end

  desc 'remove company and signboard duplicates'
  task remove_company_signboard_duplicates: :environment do
    puts 'START'
    OneTime::RemoveCompanyDuplicatesService.call
    puts 'END'
  end

  desc 'set checkin_started_at for lenta_items'
  task set_checkin_started_at: :environment do
    puts 'START'
     max_id = LentaItem.order(:id).last.try(:id)
     if max_id
       min_id = max_id - 10000
       min_id = 0 if min_id < 0
       while max_id > 0
         puts "#{min_id} - #{max_id}"
         ActiveRecord::Base.connection.execute <<-SQL
           update lenta_items set checkin_started_at = (select c.started_at
             from checkins c
             where c.id = lenta_items.checkin_id
           )
           where lenta_items.id between #{min_id} AND #{max_id}
             AND lenta_items.checkin_started_at is null
             AND lenta_items.checkin_id is not null;

           update lenta_items set checkin_started_at = (select c.started_at
             from checkin_lites c
             where c.id = lenta_items.checkin_lite_id
           )
           where lenta_items.id between #{min_id} AND #{max_id}
             AND lenta_items.checkin_started_at is null
             AND lenta_items.checkin_lite_id is not null;
         SQL
         max_id = min_id
         min_id = max_id - 10000
         min_id = 0 if min_id < 0
       end
     end
     puts 'END'
  end

  desc 'set broken_photos_count default in checkins'
  task :set_broken_photos_count_default => :environment do
    t = Time.now
    statement = <<-SQL
        UPDATE checkins
        SET broken_photos_count = 0
        WHERE broken_photos_count IS NULL;
    SQL
    ActiveRecord::Base.connection.execute statement
    puts "Task executed in #{(Time.now - t)/60} minutes"
  end

  desc 'Update checkins#planned to true if plan_item_id is present'
  task update_checkins_planned_value: :environment do
    t = Time.now
    OneTime::UpdateCheckinsPlannedValueService.call
    puts "Task executed in #{(Time.now - t)/60} minutes"
  end

  desc 'create checkins by checkin_lites'
  task create_checkins_by_checkin_lites: :environment do
    puts 'START'
    class CheckinLite < ActiveRecord::Base
      belongs_to :location_including_deleted, class_name: 'LocationUnscoped',
                 foreign_key: 'location_id'
    end

    CheckinLite.
      includes(:location_including_deleted).
      joins(
        <<-SQL
          LEFT OUTER join checkins on checkins.user_id = checkin_lites.user_id 
            AND checkins.location_id = checkin_lites.location_id 
            AND checkins.started_at = checkin_lites.started_at
      SQL
      ).
      where('checkin_lites.started_at > ?', Time.now - 1.month).
      where(checkins: { id: nil }).find_each do |checkin_lite|
      begin
        location = checkin_lite.location_including_deleted
        started_date = checkin_lite.started_at.in_time_zone(location.timezone).to_date
        checkin = Checkin.new(
          started_at: checkin_lite.started_at,
          location_id: checkin_lite.location_id,
          user_id: checkin_lite.user_id,
          plan_item_id: checkin_lite.plan_item_id,
          created_at: checkin_lite.created_at,
          updated_at: checkin_lite.updated_at,
          api_key_id: checkin_lite.api_key_id,
          organization_id: checkin_lite.organization_id,
          started_date: started_date
        )
        if checkin.valid?
          checkin.save!
          LentaItem.where(checkin_lite_id: checkin_lite.id).update_all(checkin_id: checkin.id)
        end
      rescue ActiveRecord::RecordNotUnique
      rescue Exception => e
        puts "Error on checkin_lite with ID='#{checkin_lite.id}'"
        raise e
      end
      LentaItem.where.not(checkin_lite_id: nil).where(checkin_id: nil).delete_all
    end
    puts 'END'
  end

  desc 'RUN FIRST AT FENRIR!!! update scorecard cache set incorrect planned checkins as unplanned'
  task update_false_planned_scorecard_checkins_to_unplanned: :environment do
    t = Time.now
    checkins = Checkin.where(plan_item_id: nil, planned: true).
      where('created_at >= ?', Date.parse('2017-02-14')).to_a
    caches = ScorecardCache.where(event_type: 'Checkin', event_id: checkins.map(&:id))
    total = caches.count
    ap "Found #{total} caches"
    caches.each do |cache|
      cache.event['fact_visit'] = 0
      cache.event['planned_visit'] = 0
      cache.event['unplanned_visit'] = 1
      cache.save!
    end
    execution_time t
  end


  desc 'update checkin.planned based on plan_item_id, starting from 14.02.2017'
  task update_false_planned_checkins_to_unplanned: :environment do
    t = Time.now
    checkins = Checkin.where(plan_item_id: nil, planned: true).
      where('created_at >= ?', Date.parse('2017-02-14'))
    total = checkins.count
    ap "Found #{total} checkins"
    checkins.update_all(planned: false)
    execution_time t
  end


  desc 'update audit checkin type role'
  task update_checkin_type_role: :environment do
    puts 'START'
    OneTime::UpdateCheckinTypeRole.call
    puts 'END'
  end

  desc 'convert 17.03.2017 Gorbachev checkins to new format'
  task convert_checkins_to_new_format: :environment do
    t = Time.now
    org_ids = User.find(104).organization_ids
    checkins = Checkin.joins(:user).where.not(finished_at: nil)
                      .where(updated_at: DateTime.parse('2017-03-17 00:00:00 +12')...Date.parse('2017-03-18 00:00:00 -11'))
                      .where(_visit: [false, nil])
                      .where(users: {organization_id: org_ids})

    total = checkins.size
    i = 0

    checkins.find_each do |checkin|
      if checkin.reports.create!(checkin_type_id: checkin.checkin_type_id, evaluations: checkin.evaluations)
        checkin.update_column :_visit, true
        i +=1
      end
      ap "Processed #{i} checkins of #{total}" if (i % 1000).zero?
    end

    execution_time t
  end

  desc 'create LocationEventCache for period 90 days'
  task create_location_events: :environment do
    t = Time.now
    puts 'START'
    ((Date.today - 90.days)..(Date.today - 60.days)).each do |date|
      Business.pluck(:id).each do |business_id|
        job = LocationEventsGeneratorJob.find_or_create_by!(
          date: date,
          business_id: business_id
        )
        jid = LocationEventsGeneratorWorker.perform_async(job.id)
        job.update! jid: jid
      end
    end

    execution_time t
    puts 'END'
  end

  desc 'set checkin_id in photos'
  task set_photos_checkin_id: :environment do
    puts 'START'

    t = Time.now

    totals = Photo.where(checkin_id: nil, picturable_type: 'CheckinEvaluation').count

    puts "Photos without checkin_id: #{totals}"

    max_id = Photo.where(checkin_id: nil).maximum(:id)

    finished = false

    loop do
      puts "processing max_id: #{max_id}"

      Photo.transaction do
        updated_count =
          Photo.connection.update_sql <<-SQL.gsub(':max_id', max_id.to_s)
            UPDATE photos
            SET
              checkin_id = checkin_evaluations.checkin_id
            FROM checkin_evaluations
            WHERE
              photos.checkin_id IS NULL AND
              photos.picturable_type = 'CheckinEvaluation' AND
              photos.picturable_id = checkin_evaluations.id AND
              checkin_evaluations.type = 'PhotoEvaluation' AND
              photos.id BETWEEN :max_id - 1000 AND :max_id
          SQL

        puts "updated_count = #{updated_count}"
        finished = updated_count == 0

        max_id -= 1001
      end

      break if finished
    end

    execution_time t
    puts 'END'
  end

  desc 'Set visits completed_at'
  task set_completed_at: :environment do
    measure_time(name: 'set checkins.completed_at') do
      max_id = Checkin.where(completed_at: nil).where.not(finished_at: nil).maximum(:id)

      with_step(max_id: max_id, step: 10_000) do |min_id, max_id|
        updated_count =
          Checkin.connection.update_sql <<-SQL.sub(':min_id', min_id.to_s).sub(':max_id', max_id.to_s)
            UPDATE checkins
            SET
              completed_at = updated_at
            WHERE
              finished_at IS NOT NULL AND completed_at IS NULL AND
              id BETWEEN :min_id AND :max_id
          SQL
        puts "-> updated_count = #{updated_count}"
      end
    end

    measure_time(name: 'set visit_plans.visit_completed_at') do
      max_id = VisitPlan.finished.maximum(:id)

      finished_state = VisitPlan.states[:finished].to_s

      with_step(max_id: max_id, step: 10_000) do |min_id, max_id|
        updated_count =
          VisitPlan.connection.update_sql(
            <<-SQL.sub(':min_id', min_id.to_s).sub(':max_id', max_id.to_s).sub(':state', finished_state)
              UPDATE visit_plans
              SET
                visit_completed_at = visits.completed_at
              FROM checkins AS visits
              WHERE
                visit_plans.state = :state AND visit_plans.deleted_at IS NULL AND
                visit_plans.hash_key = visits.visit_plan_hash_key AND
                visit_plans.id BETWEEN :min_id AND :max_id
            SQL
          )
        puts "-> updated_count = #{updated_count}"
      end
    end
  end

  desc 'Set visit_plans timezone'
  task set_visit_plans_timezone: :environment do
    measure_time(name: 'set visit_plans.timezone') do
      max_id = VisitPlan.maximum(:id)

      with_step(max_id: max_id, step: 10_000) do |min_id, max_id|
        updated_count =
          VisitPlan.connection.update_sql(
            <<-SQL.sub(':min_id', min_id.to_s).sub(':max_id', max_id.to_s)
              UPDATE visit_plans
              SET
                timezone = user_versions.timezone
              FROM user_versions
              WHERE
                visit_plans.user_version_id = user_versions.id AND
                visit_plans.timezone IS NULL AND
                visit_plans.id BETWEEN :min_id AND :max_id
            SQL
          )
        puts "-> updated_count = #{updated_count}"
      end
    end
  end

  desc 'Set organization_id for signboards'
  task set_signboards_organization_ids: :environment do
    measure_time(name: 'set_signboards_organization_ids') do
      max_id = Signboard.maximum(:id)
      with_step(max_id: max_id, step: 1000) do |min_id, max_id|
        updated_count = Signboard.connection.update_sql(
          <<-SQL.sub(':min_id', min_id.to_s).sub(':max_id', max_id.to_s)
            UPDATE signboards
              SET organization_id = companies.organization_id
              FROM companies  
              WHERE companies.id = signboards.company_id AND
                signboards.id BETWEEN :min_id AND :max_id
          SQL
        )
        puts "-> updated_count = #{updated_count}"
      end
    end
  end

  desc 'Set kpi_template_ids for kpi_uploads'
  task set_kpi_template_ids: :environment do
    measure_time(name: 'set kpi_template_ids') do
      KpiUpload.connection.execute <<-SQL
        update uploads
        set options = options || 
          ('{ "kpi_template_ids": [' || cast(options->>'kpi_template_id' as text) || ']}')::jsonb
        where type = 'KpiUpload'
      SQL
    end
  end

  desc 'Create/Update Calendar from InspectorLocation/Timetable'
  task create_calendars: :environment do
    measure_time(name: 'create_calendars') do
      scope =
        InspectorLocation.joins(:inspector).
          includes(:inspector, :location).where.not(users: { business_id: nil })

      count = scope.count

      puts "Total inspector locations count #{count}"

      scope.find_in_batches(batch_size: 1_000) do |group|
        group.each do |il|
          begin
            timetables =
              Timetable.where(location_id: il.location_id, user_id: il.inspector_id).
                order(:week_num, :day_num).pluck(:must_visit).map { |v| v ? 1 : 0 }

            calendar = Calendar.find_or_initialize_by(location_id: il.location_id,
                                                      user_id: il.inspector_id)

            calendar.update!(
              matrix:               timetables.each_slice(7).to_a,
              route_id:             il.inspector.route_id,
              location_external_id: il.location.external_id,
              planned_work_time:    il.planned_time,
              planned_move_time:    il.planned_move_time,
              merchendising_type:   il.merchendising_type,
              agency_name:          il.agency_name
            )
          rescue Exception => e
            puts "Error: InspectorLocation #{il.id}, #{e.message}"
          end
        end

        count -= group.size

        puts "Rest #{count}"
      end
    end
  end

  desc 'Drop VisitPlans from future'
  task drop_visit_plans_from_future: :environment do
    measure_time(name: 'drop_visit_plans_from_future') do
      scope =
        VisitPlan.where.not(timezone: ['uninhabited', nil]).
          where("(now() AT TIME ZONE timezone)::date < thedate").
          where(state: VisitPlan.states[:pending])

      count = scope.count
      puts "Total VisitPlans from future #{count}"

      loop do
        updated_count = scope.limit(1_000).update_all(deleted_at: Time.now)
        break if updated_count == 0

        count -= updated_count
        puts "Rest #{count}"
      end
    end
  end

  def measure_time(name: nil)
    puts "Starting -> #{name}"
    t = Time.now
    yield
    execution_time t
    puts "End -> #{name}"
  end

  def with_step(max_id:, step:)
    puts max_id
    puts step
    if max_id.present? && max_id > 0
      begin
        min_id = max_id > step ? max_id - step : 0
        puts "processing #{min_id} - #{max_id}"
        yield(min_id, max_id)
        max_id = min_id
      end while max_id > 0
    else
      puts "nothing to process"
    end
  end

  desc 'fill business id for user_versions (LESS then 5 minutes)'
  task fill_business_id_for_user_versions: :environment do
    t = Time.now

    sql = <<-SQL
      UPDATE user_versions AS uv
      SET business_id = u.business_id
      FROM users AS u
      WHERE u.id = uv.item_id
      AND u.business_id IS NOT NULL
      AND u.role IN ('merchendiser', 'supervisor')
    SQL
    ActiveRecord::Base.connection.execute sql

    execution_time(t)
  end

  desc 'fill timezone for checkins (LESS then 5 minutes)'
  task fill_timezone_for_checkins: :environment do
    t = Time.now

    sql = <<-SQL
      UPDATE checkins
      SET timezone = u.timezone
      FROM user_versions AS u
      WHERE u.id = checkins.user_version_id
      AND checkins.created_at >= '2017-03-01 00:00:00'::timestamp
    SQL
    ActiveRecord::Base.connection.execute sql

    execution_time(t)
  end

  desc ' fill business id for scorecard caches'
  task fill_business_id_for_scorecard_caches: :environment do
    caches = ScorecardCache.where(:created_at.gte => '2017-05-01', state: 0, business_id: nil)\
                 .select('(h_vector->>0)::integer, json_agg(id)')\
                 .group('(h_vector->>0)::integer')

    cids = Hash[caches.pluck('(h_vector->>0)::integer, json_agg(id)')]
    business_ids = UserUnscoped.where(id: cids.keys).select(:id, :business_id).pluck(:id, :business_id)

    business_ids.each do |bid|
      ScorecardCache.where(id: cids[bid.first]).update_all business_id: bid.last
    end
  end

  desc 'fill updated_at in scorecard_caches'
  task set_updated_at_in_scorecard_caches: :environment do
    puts 'START'
    t = Time.now

    ScorecardCache.connection.execute 'update scorecard_caches set updated_at = created_at;'

    execution_time(t)
    puts 'END'
  end

  desc 'fill photos counter for checkins and reports'
  task fill_photos_counter_for_checkins_and_reports: :environment do
    sql = <<-SQL
      create index concurrently if not exists checkins_temp_index on checkins (created_at asc, id asc) 
      where photos_count IS NULL
    SQL
    ap 'Creating temporaty checkins index on created_at and id...'
    ActiveRecord::Base.connection.execute sql
    ap 'Done.'
    total = Checkin.where('created_at >= ?', Date.parse('2017-05-01').beginning_of_day).where(photos_count: nil).count
    ap "Total checkins count: #{total}"

    checkins = get_checkins; nil
    while checkins.size > 0 do
      t = Time.now
      ap "Processing next 1000 checkins from #{total}"
      checkins.each do |checkin|
        Checkin.reset_counters(checkin.id, :photos)
        checkin.reports.each do |report|
          Report.reset_counters(report.id, :photos)
        end
      end
      last_id = checkins.map(&:id).max
      checkins = get_checkins(last_id)
      total -= 1000
      execution_time(t)
    end

    sql = <<-SQL
      drop index checkins_temp_index
    SQL
    ActiveRecord::Base.connection.execute sql
  end

  def get_checkins(last_id = nil)
    scope = Checkin.where('created_at >= ?', Date.parse('2017-05-01').beginning_of_day)
    scope = scope.where('id > ?', last_id) if last_id
    scope = scope.where(photos_count: nil).order(:created_at, :id).includes(:reports).limit(1000)
    scope.to_a
  end

  desc 'update digits max count for Questions'
  task update_max_in_questions: :environment do
    Question.where(question_type: 'number').update_all(max: 999_999_999)
    Question.where(question_type: 'price').update_all(max: 1_000_000_000.00)
  end

  desc 'set questionaries feature for current businesses'
  task set_questionaries_feature: :environment do
    puts 'START'
    Business.find_each do |business|
      puts business.id
      business.features += ['questionaries']
      business.save!(validate: false)
    end
    puts 'END'
  end

  desc 'set states to AP uploads'
  task set_ap_uploads_states: :environment do
    {
      in_progress: :processing,
      finished: :processed,
      error: :not_processed,
      not_started: :queued,
    }.each do |status, state|
      puts status
      ApUpload.where(state: nil, status: Upload.statuses[status]).update_all(state: state.to_s)
    end
  end

  desc 'fill encryption key for users'
  task fill_encryption_key_for_users: :environment do
    active_users = User.all
    ap "users to update in total #{active_users.size}"
    active_users.each do |user|
      if user.encryption_key.nil?
        user.create_encryption_key.regenerate!
      else
        user.encryption_key.regenerate!
      end
    end
    execution_time(t)
  end

end
