# frozen_string_literal: true

require 'spec_helper'

describe 'resource_artefacts::default' do
  context 'configures the operating system' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'has the correct platform_version' do
      expect(chef_run.node['platform_version']).to eq('16.04')
    end
  end
end
