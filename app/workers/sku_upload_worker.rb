class SkuUploadWorker
  include Sidekiq::Worker

  sidekiq_options retries: false, queue: :sku_upload_jobs

  def perform parameters
    @object = SkuUploader.new(parameters)
    @object.report_start
    @object.do_work
    @object.report_end
  end
  
end
