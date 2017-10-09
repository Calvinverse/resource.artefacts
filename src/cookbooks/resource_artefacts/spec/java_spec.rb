# frozen_string_literal: true

require 'spec_helper'

describe 'resource_artefacts::java' do
  context 'installs java' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'adds the openjdk-r-ppa apt repository' do
      expect(chef_run).to add_apt_repository('openjdk-r-ppa').with(
        uri: 'ppa:openjdk-r'
      )
    end

    it 'installs the java JRE' do
      expect(chef_run).to install_apt_package('openjdk-9-jre-headless').with(
        options: %w[-o Dpkg::Options::=--force-overwrite],
        version: '9~b114-0ubuntu1'
      )
    end

    it 'installs the additional fonts' do
      expect(chef_run).to install_apt_package(%w[libfontconfig1 fonts-dejavu fonts-dejavu-core fonts-dejavu-extra xvfb])
    end
  end
end
