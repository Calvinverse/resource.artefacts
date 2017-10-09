# frozen_string_literal: true

require 'spec_helper'

describe 'resource_artefacts::java' do
  context 'installs java' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'imports the java_se recipe' do
      expect(chef_run).to include_recipe('java_se')
    end
  end
end
