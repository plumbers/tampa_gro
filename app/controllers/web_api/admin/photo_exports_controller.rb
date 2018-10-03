module WebApi
  module Admin
    class PhotoExportsController < ::WebApi::BaseController
      EXPORT_ATTRIBUTES = %w(id created_at started_at ended_at status photos_count percent)

      def index
        @exports = ::PhotoExport.order(created_at: :desc).paginate page: params[:page], per_page: 5
        respond_with (@exports.map do |export|
          res = export.attributes.slice(*EXPORT_ATTRIBUTES).
            merge(errors_count: export.export_errors&.size,
                  inner_text: I18n.t("statusable.statuses.#{export.status}"))
          res[:download] = export.aws_file.url if export.finished?
          res
        end).to_json

      end

      def create
        @export = ::PhotoExport.new create_params
        if @export.save
          jid = PhotoExportWorker.perform_at @export.process_at, @export.id
          @export.update! jid: jid
        end
        respond_with @export.attributes.
          slice(*EXPORT_ATTRIBUTES).
          merge(inner_text: I18n.t("statusable.statuses.#{@export.status}")).
          as_json, location: new_admin_photo_export_url
      end

      def companies
        require_params :business_id, :date_from, :date_till
        @facade = Facades::WebApi::Admin::PhotoExports::Companies.new(view_context)
        respond_with @facade.by_name.as_json
      end

      def signboards
        require_params :business_id, :date_from, :date_till
        @facade = Facades::WebApi::Admin::PhotoExports::Signboards.new(view_context)
        respond_with @facade.by_name.as_json
      end

      def users
        require_params :business_id
        @facade = Facades::WebApi::User.new(view_context)
        respond_with @facade.data.as_json
      end

      def checkin_types
        require_params :business_id, :date_from, :date_till
        @facade = Facades::WebApi::Admin::PhotoExports::CheckinTypes.new(view_context)
        respond_with @facade.by_name.as_json
      end

      def average_photo_count
        @facade = Facades::WebApi::Admin::PhotoExports::PhotoCounter.new(view_context)
        render json: { photo_count: @facade.count }
      end

      private

      def create_params
        params.permit(filters: PhotoExport::FILTERS.keys + [{signboard_ids: [], company_ids: [], checkin_type_ids: []}]).tap do |permitted|
          permitted[:status] = :not_started
          permitted[:process_at] = params[:process_at].present? ? DateTime.parse(params[:process_at]) : Time.now
          permitted[:user_id] = current_user.id
          permitted[:source_bucket_name] = Rails.application.config.aws_options[:s3_credentials][:bucket]
        end
      end

    end
  end
end
