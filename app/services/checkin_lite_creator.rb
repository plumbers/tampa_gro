class CheckinLiteCreator
  attr_reader :checkin
  delegate :user_id, :location_id, :id, :errors, to: :checkin

  def initialize(checkin_parameters:, current_user:, photo_parameters:)
    @checkin          = CheckinLite.new(checkin_parameters)
    @current_user     = current_user
    @photo_parameters = photo_parameters
  end
  
  def save
    set_checkin_plan_item
    build_lenta_item
    build_photo
    if @checkin.save
      queue_upload_to_s3
      true
    else
      false
    end
  end

  private
  def queue_upload_to_s3
    if @checkin.photo
      uploader = Rails.configuration.aws_uploader
      uploader.perform_later(self.photo.id, nil)
    end
  end

  def set_checkin_plan_item
    plan_item_matcher = CheckinPlanItemMatcher.new(@checkin, @checkin.timezone, @current_user)
    @checkin.plan_item_id = plan_item_matcher.id if plan_item_matcher.obtain
  end

  def build_lenta_item
    @checkin.build_lenta_item user_id: @checkin.user.supervisor_id
  end

  def build_photo
    @checkin.build_photo(image: parse_base64_picture) if @photo_parameters
  end
  
  def parse_base64_picture
    tempfile      = ImageSerializer.parse_tempfile(image: @photo_parameters)
    photo_attrs   = { :tempfile => tempfile, :filename => @photo_parameters[:filename], :type => @photo_parameters[:content_type] }
    @photo        = ActionDispatch::Http::UploadedFile.new(photo_attrs)
  end

end
