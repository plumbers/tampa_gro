class UsersEncryptionKeyRegenerationWorker
    include Sidekiq::Worker

    sidekiq_options retry: 0

    def perform(business_id = nil)
      active_users = User.where(business_id: business_id)
      active_users.find_each do |user|
        if user.encryption_key.nil?
          user.create_encryption_key
        else
          user.encryption_key.regenerate!
        end
      end
    rescue => error
      ap error.message
      ap error.backtrace.first(15)
      raise error
    end
end
