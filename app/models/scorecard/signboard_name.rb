require 'periscope-activerecord'

class SignboardName < ActiveRecord::Base
  self.primary_key = 'id'
  self.table_name = 'signboard_names'

  def self.reload_rows
    ActiveRecord::Base.transaction do

      statement = <<-SQL

      INSERT INTO signboard_names(signboard_name)
      SELECT DISTINCT signboard_name
      FROM scorecard_histogram sh
      LEFT OUTER JOIN signboard_names sn ON sn.signboard_name=sh.signboard_name
      WHERE sn.id IS NULL;


      SQL
      ActiveRecord::Base.connection_pool_execute statement

    end
  end
end

