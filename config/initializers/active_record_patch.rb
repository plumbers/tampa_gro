class ActiveRecord::Base
  def attr_valid? *attributes
    self.valid?
    attributes.all?{ |attr| self.errors[attr].blank? }
  end

  def self.sanitize_parameters *params_array
    params_array = [params_array] unless params_array.kind_of? Array
    params_array.each do |param|
      
      define_method param do
        string = super()
        if string.kind_of?(String) && string.present?
          CGI.unescapeHTML string
        else
          string
        end
      end

      before_validation do
        sanitize_param param
      end
    end
  end

  def sanitize_param param
    original_value = self.send(param)
    if original_value
      sanitized = Sanitize.fragment(original_value, Sanitize::Config::DEFAULT).strip
      self.send("#{param}=", sanitized)
    end
  end

  def self.connection_pool_execute query
    ActiveRecord::Base.connection_pool.with_connection{|conn| conn.execute query}
  end

  def self.batch_import_records(target_model, src_data_relation, batch_size = 1024)
    wrapped_src_data_relation = target_model.select('*').from(Arel.sql("(#{src_data_relation.to_sql}) AS #{target_model.table_name}"))
    attrs_list = wrapped_src_data_relation.first.attributes.keys
    wrapped_src_data_relation.find_in_batches(batch_size: batch_size).each do |src_data_rows|
      attrs, values = attrs_list, src_data_rows.map { |row| row.attributes.values }
      target_model.import attrs, values, validate: false
    end
  end
end

module ActiveRecord::AttributeAssignmentOverride
  def assign_attributes(new_attributes, options={})
    return super(new_attributes) if options.fetch(:override, true)
    super(new_attributes.select {|k,_| self[k].nil? })
  end
end

class ActiveRecord::Base
  include ActiveRecord::AttributeAssignmentOverride
end
