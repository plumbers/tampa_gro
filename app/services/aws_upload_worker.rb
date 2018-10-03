class AwsUploadWorker

  def self.perform_later photo_id, checkin_id
    self.new(photo_id, checkin_id).perform
  end

  def initialize photo_id, checkin_id
    @photo      = Photo.find(photo_id)
    @checkin_id = checkin_id
  end

  def perform
    if @photo.aws_image.blank?
      migrate_to_aws
      increment_photos_count
      remove_local_file
    end
  end
  
  private

  def migrate_to_aws
    @photo.aws_image = @photo.image
    @photo.save!
  end

  def increment_photos_count
    Checkin.increment_counter(:cloud_photos_count, @checkin_id) if @checkin_id
  end

  def remove_local_file
    @photo.image.clear
    @photo.save!
  end
  
end
