# frozen_string_literal: true

require 'spec_helper'

describe 'resource_artefacts::nexus' do
  context 'configures nexus' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs nexus' do
      expect(chef_run).to install_nexus3('nexus')
    end
  end

  context 'configures the firewall for consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'opens the Nexus HTTP port' do
      expect(chef_run).to create_firewall_rule('nexus-http').with(
        command: :allow,
        dest_port: 8081,
        direction: :in
      )
    end
  end
end
