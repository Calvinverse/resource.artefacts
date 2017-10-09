# frozen_string_literal: true

require 'spec_helper'

describe 'resource_artefacts::provisioning' do
  context 'configures provisioning' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs the dos2unix package' do
      expect(chef_run).to install_apt_package('dos2unix')
    end

    it 'installs the pwgen package' do
      expect(chef_run).to install_apt_package('pwgen')
    end

    it 'creates provision.sh in the /etc/init.d directory' do
      expect(chef_run).to create_file('/etc/init.d/provision.sh')
    end

    it 'creates provision service in the /etc/systemd/system directory' do
      expect(chef_run).to create_file('/etc/systemd/system/provision.service')
    end

    it 'enables the provisioning service' do
      expect(chef_run).to enable_service('provision.service')
    end
  end
end
