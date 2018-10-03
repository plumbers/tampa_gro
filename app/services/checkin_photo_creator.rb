class CheckinPhotoCreator
  class ForeignCheckinError < StandardError; end
  class PhotoSaveError < StandardError; end

  attr_reader :evaluation

  def initialize current_user, parameters
    @user       = current_user 
    @parameters = parameters
    @checkin    = Checkin.where(id: parameters[:id]).first
  end

  def save!
    ensure_checkin_belongs_to_user!
    parse_base64_picture
    build_evaluation
    
    if @evaluation.save
      update_received_photos_counter
      queue_upload_to_s3
      return true
    else
      raise PhotoSaveError
    end
  end

  private
  
  def update_received_photos_counter
    Checkin.increment_counter(:received_photos_count, @evaluation.checkin_id)
  end

  def queue_upload_to_s3
    Rails.configuration.aws_uploader.perform_later(@evaluation.photo.id, @evaluation.checkin_id)
  end
  
  def ensure_checkin_belongs_to_user!
    raise ForeignCheckinError if checkin_author_id_not_match && checkin_author_phone_not_match
  end
  
  def checkin_author_id_not_match
    @checkin.user_id != @user.id
  end

  def checkin_author_phone_not_match
    User.where(id: [@checkin.user_id, @user.id]).select('DISTINCT(mobile_phone)').count > 1
  end
  
  def parse_base64_picture
    tempfile      = ImageSerializer.parse_tempfile(image: @parameters[:photo])
    photo_attrs   = { :tempfile => tempfile, :filename => @parameters[:photo][:filename], :type => @parameters[:photo][:content_type] }
    @photo        = ActionDispatch::Http::UploadedFile.new(photo_attrs)
  end

  def build_evaluation
    @evaluation = @checkin.photo_evaluations.build(photo_load_params)
    @evaluation.build_photo({image: @photo})
  end

  def photo_load_params
    @parameters[:evaluation].slice(:placement_id, :stage_id, :sku_category_id, :promo_id, :note).permit! rescue {}
  end

end
