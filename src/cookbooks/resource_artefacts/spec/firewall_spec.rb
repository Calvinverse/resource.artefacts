# frozen_string_literal: true

require 'spec_helper'

describe 'resource_artefacts::firewall' do
  context 'configures the firewall' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs the default firewall' do
      expect(chef_run).to install_firewall('default')
    end

    it 'opens the SSH TCP port' do
      expect(chef_run).to create_firewall_rule('ssh').with(
        command: :allow,
        dest_port: 22,
        direction: :in,
        protocol: :tcp
      )
    end
  end
end
