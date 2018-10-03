class Admin::LogUploadsController < ApplicationController
  before_action :authenticate_user!
  authorize_resource class: false
  before_action :set_breadcrumb

  def index
    @uploads = LogUpload.order(id: :desc).paginate(page: params[:page], per_page: 25)
  end

  def show
    add_breadcrumb t('admin.log_uploads.show.breadcrumb', id: params[:id])
    @upload_facade = Facades::LogUploads.new(view_context)
  end

  def download
    @upload_facade = Facades::LogUploads.new(view_context)
    stream = @upload_facade.send_file
    send_data stream.string, filename: "#{@upload_facade.upload.id}.zip", type: 'application/zip'
  end

  private

  def set_breadcrumb
    add_breadcrumb '<i class="icon-home"></i>'.html_safe
    add_breadcrumb t('admin.log_uploads.index.breadcrumb'), admin_log_uploads_path
  end

  def specific_ability
    AdministrationAbility.new(current_user)
  end

end
