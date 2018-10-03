class Api::V9::LogUploadsController < Api::ApiBaseController
  SERVICE_PROVIDER = Facades::Api::V9::LogUploadCreator

  def create
    service = SERVICE_PROVIDER.new(view_context)
    service.create!

    render status: :ok, json: { code: 200 }
  rescue SERVICE_PROVIDER::UploadFileSizeError => e
    render status: :payload_too_large, json: { code: 413, errors: [e.message] }
  rescue SERVICE_PROVIDER::UploadContentTypeError => e
    render status: :unsupported_media_type, json: { code: 415, errors: [e.message] }
  rescue SERVICE_PROVIDER::UploadError, ActiveRecord::RecordInvalid => e
    Rollbar.error(e, 'api_v9 could not save log_upload - logs in zip archive')
    render status: :bad_request, json: { code: 400, errors: [e.message] }
  end
  
  private

  def upload_params
    params.permit(:content_type, :file_name, :data, :encryption_key_version)
  end

end
