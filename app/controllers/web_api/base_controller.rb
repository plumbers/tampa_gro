module WebApi
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :options
    respond_to :json

    protected

    def require_params(*keys)
      keys.each do |param|
        raise ActionController::ParameterMissing.new(param) unless params.has_key?(param)
      end
    end


  end
end
