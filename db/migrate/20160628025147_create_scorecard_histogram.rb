class CreateScorecardHistogram < ActiveRecord::Migration

  def up
    unless index_exists?(:checkins, :checkin_type_id, name: :checkins_checkin_type_id_non_photo_blank_idx)
      add_index :checkins, :checkin_type_id, name: :checkins_checkin_type_id_non_photo_blank_idx,  where: "checkin_type_id NOT IN (NULL, 3)"
    end
    unless index_exists?(:scorecard_caches, [:event_local_date, :event_type], name: :scorecard_caches_event_local_date_event_type_idx)
      add_index :scorecard_caches, [:event_local_date, :event_type], name: :scorecard_caches_event_local_date_event_type_idx,  where: "checkin_type='Checkin'"
    end

    unless table_exists? :scorecard_histogram
      create_table :scorecard_histogram do |t|
        t.integer :edge_id
        t.integer :scid, :null => false

        t.string  :question
        t.float   :answer
        t.float   :price

        t.jsonb   :h_vector
        t.date    :event_local_date

        t.string  :channel
        t.string  :iformat
        t.string  :company_name
        t.string  :network_name
        t.string  :signboard_name
        t.string  :client_category

        t.timestamps
      end

      add_index :scorecard_histogram, :event_local_date, name: :scorecard_histogram_event_local_date_idx
      add_index :scorecard_histogram, :channel, name: :scorecard_histogram_channel_idx,  where: "channel IS NOT NULL AND channel!=''"
      add_index :scorecard_histogram, :signboard_name, name: :scorecard_histogram_signboard_name_idx,  where: "signboard_name IS NOT NULL AND signboard_name!=''"
      add_index :scorecard_histogram, :client_category, name: :scorecard_histogram_client_category_idx,  where: "client_category IS NOT NULL AND client_category!=''"
      add_index :scorecard_histogram, :question, name: :scorecard_histogram_question_idx

      statement = <<-SQL
          CREATE INDEX scorecard_histogram_h_vector_idx ON scorecard_histogram USING GIN(h_vector jsonb_path_ops);
        SQL
      ActiveRecord::Base.connection_pool_execute statement
    end

  end

  def down
    remove_index :checkins, name: :checkins_checkin_type_id_non_photo_blank     if index_exists?(:checkins, :checkin_type_id, name: :checkins_checkin_type_id_non_photo_blank)
    remove_index :scorecard_caches, name: :scorecard_caches_event_type_checkins if index_exists?(:scorecard_caches, :event_type, name: :scorecard_caches_event_type_checkins)

    drop_table :scorecard_histogram if table_exists? :scorecard_histogram
  end
end
