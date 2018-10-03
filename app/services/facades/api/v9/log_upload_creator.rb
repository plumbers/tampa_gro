module Facades
  module Api
    module V9
      class LogUploadCreator < Facades::Base
        UploadError                     = Class.new(StandardErrorWithI18n)
        UploadContentTypeError          = Class.new(UploadError)
        UploadFileSizeError             = Class.new(UploadError)
        UploadEncryptionKeyVersionError = Class.new(UploadError)

        def create!
          object = LogUpload.new(
              file: attachment_file,
              encryption_key_version: encryption_key_version,
              user_id: current_user.id
          )
          object.save || raise_custom_error!(object)
        end

        private

        def attachment_file
          @attachment_file ||= params[:data]
        end

        def encryption_key_version
          @encryption_key_version ||= params[:encryption_key_version]
        end

        def raise_custom_error!(object)
          raise UploadContentTypeError if object.errors.has_key?(:file_content_type)
          raise UploadFileSizeError    if object.errors.has_key?(:file_file_size)
          raise UploadEncryptionKeyVersionError if attachment_has_invalid_version
        end

        def create_attachment!
          LogUpload.create!(
            file: attachment_file,
            encryption_key_version: encryption_key_version,
            user_id: current_user.id
          )
        end

        def attachment_has_invalid_version
          encryption_key_version.blank? || (encryption_key_version.to_i rescue nil).nil?
        end
      end
    end
  end
end
