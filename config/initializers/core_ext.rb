require 'hashie/extensions/deep_find'
include Hashie::Extensions::DeepFind

class Hash
  def unnest
    new_hash = {}
    each do |key,val|
      if val.is_a?(Hash)
        new_hash.merge!(val.prefix_keys("#{key}-"))
      else
        new_hash[key] = val
      end
    end
    new_hash
  end

  def prefix_keys(prefix)
    Hash[map{|key,val| [prefix + key, val]}].unnest
  end

  def deep_diff(b)
    a = self
    (a.keys | b.keys).inject({}) do |diff, k|
      if a[k] != b[k]
        if a[k].respond_to?(:deep_diff) && b[k].respond_to?(:deep_diff)
          diff[k] = a[k].deep_diff(b[k])
        else
          diff[k] = [a[k], b[k]]
        end
      end
      diff
    end
  end

  def deepest_changed_keys(b)
    a = self
    (a.keys | b.keys).inject([]) do |res, k|
      if a[k] != b[k]
        if a[k].respond_to?(:deepest_changed_keys) && b[k].respond_to?(:deepest_changed_keys)
          res << a[k].deepest_changed_keys(b[k])
        else
          res << k
        end
      end
      res
    end.flatten
  end

  def compact
    delete_if{|k, v|
      (v.is_a?(Hash) and v.respond_to?('empty?') and v.compact.empty?) or
      (v.nil?)  or
      (v.is_a?(String) and v.empty?) or
      (v.is_a?(Array) and v.empty?)
    }
  end

end
