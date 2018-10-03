require 'spec_helper'

describe 'LogUploadsController API V9', type: :request do
  before { allow_any_instance_of(User).to receive(:paid_account?).and_return(true) }
  let!(:user) { create(:merch) }
  let!(:file) { fixture_file_upload("#{Rails.root}/spec/fixtures/log_uploads/logs.zip") }
  include_context 'api_shared_variables', 9

  describe "POST '/api/log_uploads.json'" do
    let(:params){
      { encryption_key_version: Time.now.to_i.to_s, data: file }
    }
    context 'when data is valid' do

      it "creates LogUpload" do
        post api_log_uploads_path(format: :json), params: params, headers: version_and_auth_header
        expect(response).to have_http_status(200)
        upload = LogUpload.last
        expect(upload).to have_attributes(file_file_name: 'logs.zip',
                                                  file_content_type: 'application/zip')
        expect(upload.encryption_key_version).to eq params[:encryption_key_version]

      end

    end

    context 'when data is invalid' do

      it 'returns unsupported media type (415) code' do
        post '/api/log_uploads.json',
             params: params.merge({ data: fixture_file_upload("#{Rails.root}/spec/fixtures/tiger.jpg") }),
             headers: version_and_auth_header
        expect(response).to have_http_status(415)
        expect(JSON.parse(response.body)['errors'].join).to include(I18n.t('errors.facades.api.v9.log_upload_creator.upload_content_type_error'))
      end

    end

    context 'when data not found' do
      it 'returns bad request (400) code' do
        post '/api/log_uploads.json',
             params: params.merge({ encryption_key_version: nil }),
             headers: version_and_auth_header
        expect(response).to have_http_status(400)
        expect(JSON.parse(response.body)['errors'].join).to include(I18n.t('errors.facades.api.v9.log_upload_creator.upload_encryption_key_version_error'))
      end
    end

    context "when file size exceedes specified size" do
      before do
        stub_const("#{LogUpload}::MAX_FILE_SIZE", 300.kilobytes)
      end

      it 'returns request entity too large (413) code' do
        post '/api/log_uploads.json',
             params: params.merge({ data: fixture_file_upload("#{Rails.root}/spec/fixtures/log_uploads/logs.zip")  }),
             headers: version_and_auth_header
        expect(response).to have_http_status(413)
        expect(JSON.parse(response.body)['errors'].join).to include(I18n.t('errors.facades.api.v9.log_upload_creator.upload_file_size_error'))
      end
    end

  end

end
