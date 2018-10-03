class ApiSessionCreator
  attr_reader :response, :params

  def initialize(response, params)
    @response, @params = response, params
  end

  def create!
    api_session = ApiSession.create!(mandatory_params.merge! optional_params)
    if api_session.persisted?
      return api_session
    else
      raise ::OAuthErrors::ApiSessionCreateError
    end
  end

  private

  def mandatory_params
    {
      oauth_access_token_id: response.token.id,
      token: response.token.token,
      user_id: response.token.resource_owner_id,
      expires_at: Time.now + Doorkeeper.configuration.access_token_expires_in,
      client_device: present_client_device(params)
    }
  end

  def optional_params
    {
      timezone: params.try(:[], :timezone),
      client_type: params.try(:[], :client_type),
      client_version: params.try(:[], :version)
    }.reject{ |_,v| v.blank? }
  end

  def present_client_device(params)
    client_device = params[:client_device]
    return {} unless client_device.is_a?(Hash)
    return {} unless [:os, :model, :brand].inject(true){ |result, k| result && client_device.respond_to?(k); result }
    client_device
  end
end
