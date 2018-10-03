class UsersEncryptionKeyRegeneration < BaseScheduledTask
  def run
    Business.pluck(:id).each do |business_id|
      UsersEncryptionKeyRegenerationWorker.perform_async business_id
    end
    UsersEncryptionKeyRegenerationWorker.perform_async
  end
end
