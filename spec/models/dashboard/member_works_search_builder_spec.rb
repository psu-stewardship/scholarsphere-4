# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::MemberWorksSearchBuilder do
  subject(:builder) { described_class.new(service) }

  let(:service) { Blacklight::SearchService.new(config: Blacklight::Configuration.new, user_params: {}, **context) }
  let(:context) { { current_user: user } }
  let(:user) { create(:user) }

  describe '.default_processor_chain' do
    its(:default_processor_chain) do
      is_expected.to include(
        :restrict_search_to_work_titles,
        :apply_gated_edit,
        :limit_to_public_resources
      )
    end
  end

  describe '#processed_parameters' do
    let(:parameters) { builder.processed_parameters }

    it 'searches only published work versions' do
      expect(parameters['fq']).to include(
        '{!terms f=model_ssi}Work'
      )
    end
  end
end
