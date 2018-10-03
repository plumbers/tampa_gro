class Api::V9::EncryptionController < Api::ApiBaseController

  def key
    authorize! :read, EncryptionKey
    @key = current_user.encryption_key&.invoke_key_by(params[:version]&.to_i)
    raise ActiveRecord::RecordNotFound if @key.nil?
  end

end
