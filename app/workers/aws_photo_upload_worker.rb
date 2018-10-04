class AwsPhotoUploadWorker
  include Sidekiq::Worker
  sidekiq_options retry: 5,
                  queue: :aws_photo_upload_jobs

  def perform(photo_id, checkin_id)
    AwsUploader.perform_later(photo_id, checkin_id)
  end

end
