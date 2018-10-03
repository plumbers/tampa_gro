module UserModules
  module Versioning
    extend ActiveSupport::Concern

    included do
      VERSIONING_IGNORED_ATTRIBUTES = %i(current_sign_in_at
                                         current_sign_in_ip
                                         last_sign_in_at
                                         last_sign_in_ip
                                         sign_in_count
                                         mobile_login_count)

      has_paper_trail meta: { h_vector: :ancestor_ids, timezone: :get_timezone },
                      class_name: 'UserVersion',
                      ignore: VERSIONING_IGNORED_ATTRIBUTES
    end

    def current_version
      versions.order(:created_at).last
    end

  end
end
