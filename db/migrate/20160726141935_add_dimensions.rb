class AddDimensions < ActiveRecord::Migration

  DIMENSIONS = %w( channel iformat company_name network_name signboard_name client_category )

  def up
    DIMENSIONS.each do |dim|
      table_name = dim.pluralize
      statement = <<-SQL
          CREATE TABLE #{table_name} AS
          SELECT (ROW_NUMBER() OVER()) id, #{dim} as name, ARRAY_AGG(id) ids
          FROM scorecard_histogram
          GROUP BY #{dim} LIMIT 1;
          TRUNCATE TABLE #{table_name};

          CREATE INDEX #{table_name}_name_idx ON #{table_name}(name);
          CREATE INDEX #{table_name}_ids_idx ON #{table_name} USING GIN(ids) ;
      SQL
      ActiveRecord::Base.connection_pool_execute statement
      ActiveRecord::Base.connection.serial_sequence(table_name, :id)
    end
  end

  def down
    ActiveRecord::Base.transaction do
      DIMENSIONS.each do |dim|
        table_name = dim.pluralize
        statement = <<-SQL
            DROP TABLE #{table_name};
        SQL
        ActiveRecord::Base.connection_pool_execute statement
      end
    end
  end

end
