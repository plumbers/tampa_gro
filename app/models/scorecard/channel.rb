require 'periscope-activerecord'

class Channel < ActiveRecord::Base
  self.primary_key = 'id'
  self.table_name  = 'channels'

  def self.reload_rows
    ActiveRecord::Base.transaction do

      statement = <<-SQL

      INSERT INTO channels(channel)
      SELECT DISTINCT channel
      FROM scorecard_histogram sh
      LEFT OUTER JOIN channels ch ON ch.channel=sh.channel
      WHERE ch.id IS NULL;

      SQL
      ActiveRecord::Base.connection_pool_execute statement

    end
  end
end

