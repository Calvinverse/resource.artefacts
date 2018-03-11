# frozen_string_literal: true

require 'spec_helper'

describe 'resource_artefacts::provisioning' do
  context 'configures provisioning' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'enables the provisioning service' do
      expect(chef_run).to enable_service('provision.service')
    end
  end
end
