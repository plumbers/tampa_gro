class AddScorecardHistogramFacts < ActiveRecord::Migration

  def up

    create_table :scorecard_histogram_facts do |t|
      t.float     :answer
      t.float     :price
      t.jsonb     :h_vector
      t.date      :event_local_date

      t.integer   :question_id,  null: false
      t.integer   :hist_id,  null: false

      t.integer   :channel_id
      t.integer   :iformat_id
      t.integer   :company_name_id
      t.integer   :network_name_id
      t.integer   :signboard_name_id
      t.integer   :client_category_id
    end

    # add_index :scorecard_histogram_facts, :question_ids,      name: :scorecard_histogram_facts_question_ids_idx, using: :gin
    add_index :scorecard_histogram_facts, :question_id,       name: :scorecard_histogram_facts_question_id_idx
    add_index :scorecard_histogram_facts, :hist_id,           name: :scorecard_histogram_facts_hist_id_idx
    add_index :scorecard_histogram_facts, :event_local_date,  name: :scorecard_histogram_facts_event_local_date_idx

    add_index :scorecard_histogram_facts, :channel_id,        name: :scorecard_histogram_facts_channel_id_idx
    add_index :scorecard_histogram_facts, :iformat_id,        name: :scorecard_histogram_facts_iformat_id_idx
    add_index :scorecard_histogram_facts, :company_name_id,   name: :scorecard_histogram_facts_company_name_id_idx
    add_index :scorecard_histogram_facts, :network_name_id,   name: :scorecard_histogram_facts_network_name_id_idx
    add_index :scorecard_histogram_facts, :signboard_name_id, name: :scorecard_histogram_facts_signboard_name_id_idx
    add_index :scorecard_histogram_facts, :client_category_id,name: :scorecard_histogram_facts_client_category_id_idx

    statement = <<-SQL
        CREATE INDEX scorecard_histogram_facts_h_vector_idx ON scorecard_histogram_facts USING GIN(h_vector jsonb_path_ops);;
    SQL
    ActiveRecord::Base.connection_pool_execute statement
  end

  def down
    drop_table :scorecard_histogram_facts
  end

end
