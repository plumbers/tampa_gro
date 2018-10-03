module WebApi
  module Admin
    class PhotoExportsController < ::WebApi::BaseController
      EXPORT_ATTRIBUTES = %w(id created_at started_at ended_at status photos_count percent)
      FILTERS = %w(companies signboards location_types location_ext_ids checkin_types questions)
      LOC_DATA_FILTERS = %w(client_category region channel iformat territory territory_type network_name)

      def index
        @exports = ::PhotoExport.order(created_at: :desc).paginate page: params[:page], per_page: 5
        respond_with (@exports.map do |export|
          res = export.attributes.slice(*EXPORT_ATTRIBUTES).
            merge(errors_count: export.export_errors&.size,
                  inner_text: localized_status(export))
          res[:download] = export.aws_file.url if export.finished?
          res
        end).to_json
      end

      def create
        Rails.logger.info create_params
        @export = ::PhotoExport.new create_params
        if @export.save
          jid = PhotoExportWorker.perform_at @export.process_at, @export.id
          @export.update! jid: jid
        end
        Rails.logger.info @export.errors.inspect
        respond_with @export.attributes.
          slice(*EXPORT_ATTRIBUTES).
          merge(inner_text: localized_status(@export)).
          as_json, location: new_admin_photo_export_url
      end

      def users
        require_params :business_id
        @facade = Facades::WebApi::User.new(view_context)
        respond_with @facade.data.as_json
      end

      FILTERS.each do |filter|
        define_method filter do
          require_params :business_id, :date_from, :date_till
          filter_class = "Facades::WebApi::Admin::PhotoExports::#{filter.camelize}".constantize
          @facade = filter_class.send :new, view_context
          respond_with @facade.by_name.as_json
        end
      end

      LOC_DATA_FILTERS.each do |filter|
        define_method filter do
          require_params :business_id, :date_from, :date_till
          @facade = Facades::WebApi::Admin::PhotoExports::LocationData.new(view_context)
          respond_with @facade.by_name(filter).as_json
        end
      end

      def photo_count
        @facade = Facades::WebApi::Admin::PhotoExports::PhotoCounter.new(view_context)
        render json: { count: @facade.count }
        # render json: { count: 42 }
      end

      private

      def create_params
        params.slice(PhotoExport::FILTERS.keys).permit!.tap do |permitted|
          permitted[:filters] = params.permit(PhotoExport::FILTERS.keys)
          permitted[:status]  = :not_started
          permitted[:process_at] = params[:process_at].present? ? DateTime.parse(params[:process_at]) : Time.now
          permitted[:user_id] = current_user&.id||3483
          permitted[:source_bucket_name] = Rails.application.config.aws_options[:s3_credentials][:bucket]
        end
      end

      def localized_status(export)
        I18n.t("statusable.statuses.#{export.status}")
      end
    end
  end
end
