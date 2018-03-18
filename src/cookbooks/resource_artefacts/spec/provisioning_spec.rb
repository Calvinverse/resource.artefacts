# frozen_string_literal: true

require 'spec_helper'

describe 'resource_artefacts::provisioning' do
  context 'configures provisioning' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates provision_image.sh in the /etc/init.d directory' do
      expect(chef_run).to create_file('/etc/init.d/provision_image.sh')
    end

    it 'enables the provisioning service' do
      expect(chef_run).to enable_service('provision.service')
    end
  end
end
