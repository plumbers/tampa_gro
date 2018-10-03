class ErrorsController < ActionController::Base
  def not_found
    render_error 404, 'not found'
  end

  def exception
    exception_object = env["action_dispatch.exception"] || "unknown exception"
    #NewRelic::Agent.notice_error(exception_object, :request_params => request.params, :uri => request.path, :type => :web_error)
    Rollbar.error(exception_object, rollbar_request_data, rollbar_person_data, type: :web_error, uri: request.path)
    render_error 500, 'internal server error'
  end

  private

  def render_error(code, status)
    if json_request?
      render json: {code: code, status: status}.to_json, status: code
    else
      render "public/#{code}", status: code, layout: false
    end
  end

  def json_request?
    env['REQUEST_PATH'] =~ /\.json$/
  end
end
