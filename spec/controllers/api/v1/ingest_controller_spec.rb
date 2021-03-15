# frozen_string_literal: true

require 'rails_helper'
require 'scholarsphere/client'

# @note While this is technically a controller test, because it's testing our REST API, we're really using it as a
# feature test to ensure end-to-end functionality of our ingest API.

RSpec.describe Api::V1::IngestController, type: :controller do
  let(:api_token) { create(:api_token).token }
  let(:user) { build(:actor) }
  let(:creator) do
    {
      display_name: "#{user.given_name} #{user.surname}",
      actor_attributes: {
        email: user.email,
        given_name: user.given_name,
        surname: user.surname,
        psu_id: user.psu_id
      }
    }
  end

  let(:metadata) { attributes_for(:work_version, :able_to_be_published) }

  let(:json_response) { HashWithIndifferentAccess.new(JSON.parse(response.body)) }

  before { request.headers[:'X-API-Key'] = api_token }

  describe 'POST #create' do
    context 'with valid input' do
      before do
        post :create, params: {
          metadata: {
            title: metadata[:title],
            description: metadata[:description],
            published_date: metadata[:published_date],
            creators_attributes: [creator]
          },
          depositor: { given_name: user.given_name, surname: user.surname, email: user.email, psu_id: user.psu_id },
          content: [{ file: fixture_file_upload(File.join(fixture_path, 'image.png')) }]
        }
      end

      it 'publishes a new work' do
        expect(response).to be_ok
        expect(response.body).to eq(
          "{\"message\":\"Work was successfully created\",\"url\":\"/resources/#{Work.last.uuid}\"}"
        )
      end
    end

    context 'when uploading files from S3' do
      before do
        path = Pathname.new(fixture_path).join('image.png')
        file = Scholarsphere::S3::UploadedFile.new(path)
        Scholarsphere::S3::Uploader.new.upload(file)
        post :create, params: {
          metadata: {
            title: metadata[:title],
            description: metadata[:description],
            published_date: metadata[:published_date],
            creators_attributes: [creator]
          },
          content: [{ file: file.to_shrine.to_json }],
          depositor: { given_name: user.given_name, surname: user.surname, email: user.email, psu_id: user.psu_id }
        }
      end

      it 'publishes a new work' do
        expect(response).to be_ok
        expect(response.body).to eq(
          "{\"message\":\"Work was successfully created\",\"url\":\"/resources/#{Work.last.uuid}\"}"
        )
      end
    end

    context 'with missing parameters' do
      before do
        path = Pathname.new(fixture_path).join('image.png')
        file = Scholarsphere::S3::UploadedFile.new(path)
        post :create, params: {
          metadata: { title: FactoryBotHelpers.work_title },
          content: [{ file: file.to_shrine.to_json }]
        }
      end

      it 'reports the error with the missing parameter' do
        expect(response).to be_bad_request
        expect(response.body).to eq(
          '{"message":"Bad request","errors":["param is missing or the value is empty: depositor"]}'
        )
      end
    end

    context 'with missing metadata' do
      before do
        post :create, params: {
          metadata: { title: nil },
          depositor: { given_name: user.given_name, surname: user.surname, email: user.email, psu_id: user.psu_id },
          content: [{ file: fixture_file_upload(File.join(fixture_path, 'image.png')) }]
        }
      end

      it 'reports the error' do
        expect(response.status).to eq(422)
        expect(json_response[:message]).to eq('Unable to complete the request')
        expect(json_response[:errors]).to include(
          "Versions title can't be blank"
        )
      end
    end

    context 'with missing files' do
      before do
        post :create, params: {
          metadata: {
            title: metadata[:title],
            description: metadata[:description],
            published_date: metadata[:published_date],
            creators_attributes: [creator]
          },
          depositor: { given_name: user.given_name, surname: user.surname, email: user.email, psu_id: user.psu_id }
        }
      end

      it 'reports the error' do
        expect(response.status).to eq(422)
        expect(json_response[:message]).to eq('Unable to complete the request')
        expect(json_response[:errors]).to include(
          "Versions file resources can't be blank"
        )
      end
    end

    context 'with missing creators' do
      before do
        post :create, params: {
          metadata: {
            title: metadata[:title],
            description: metadata[:description],
            published_date: metadata[:published_date]
          },
          depositor: { given_name: user.given_name, surname: user.surname, email: user.email, psu_id: user.psu_id },
          content: [{ file: fixture_file_upload(File.join(fixture_path, 'image.png')) }]
        }
      end

      it 'reports the error' do
        expect(response.status).to eq(422)
        expect(json_response[:message]).to eq('Unable to complete the request')
        expect(json_response[:errors]).to include(
          "Versions creators can't be blank"
        )
      end
    end
  end

  def i18n_error_message(attr, validation)
    wv = WorkVersion.new
    wv.errors.full_message(
      attr,
      wv.errors.generate_message(attr, validation)
    )
  end
end
