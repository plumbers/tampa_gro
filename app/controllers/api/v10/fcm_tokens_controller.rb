class Api::V10::FcmTokensController < Api::ApiBaseController

  def subscribe_token
    authorize! :write, FcmToken
    token = FcmToken.find_or_initialize_by user_id: current_user.id, key: create_params[:key], api_session_id: current_user.token_id
    if token.save
      render status: 200, json: { code: 200, token_id: token.id }
    else
      render_api_error(422, :'Something goes wrong')
    end
  end

  protected

  def create_params
    params.require(:token).permit(:key)
  end

end
