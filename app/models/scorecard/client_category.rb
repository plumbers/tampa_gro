require 'periscope-activerecord'

class ClientCategory < ActiveRecord::Base
  self.primary_key = 'id'
  self.table_name  = 'client_categories'

  def self.reload_rows
    ActiveRecord::Base.transaction do

      statement = <<-SQL

      INSERT INTO client_categories(client_category)
      SELECT DISTINCT client_category
      FROM scorecard_histogram sh
      LEFT OUTER JOIN client_categories cc ON cc.client_category=sh.client_category
      WHERE cc.id IS NULL;

      SQL
      ActiveRecord::Base.connection_pool_execute statement

    end
  end
end

