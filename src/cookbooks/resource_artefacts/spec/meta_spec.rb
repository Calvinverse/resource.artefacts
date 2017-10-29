# frozen_string_literal: true

require 'spec_helper'

describe 'resource_artefacts::meta' do
  context 'updates the /etc/environment file' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'writes the product name to the environment variables' do
      expect(chef_run).to run_ruby_block('set_environment_product_name')
    end

    it 'writes the product version to the environment variables' do
      expect(chef_run).to run_ruby_block('set_environment_version')
    end
  end
end
