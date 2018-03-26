# frozen_string_literal: true

require 'spec_helper'

nexus_management_port = 8081
nexus_proxy_path = '/artefacts'

describe 'resource_artefacts::nexus_service' do
  context 'configures the service' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'disables the nexus service' do
      expect(chef_run).to disable_service('nexus')
    end

    it 'updates the nexus service' do
      expect(chef_run).to create_systemd_service('nexus').with(
        action: [:create],
        after: %w[network.target],
        description: 'nexus service',
        wanted_by: %w[multi-user.target],
        exec_start: '/opt/nexus/bin/nexus start',
        exec_stop: '/opt/nexus/bin/nexus stop',
        limit_nofile: 65_536,
        restart: 'on-abort',
        type: 'forking',
        user: 'nexus'
      )
    end
  end

  context 'enables the reverse proxy path' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    nexus_properties_content = <<~PROPERTIES
      # Jetty section
      application-port=#{nexus_management_port}
      application-host=0.0.0.0
      nexus-args=${jetty.etc}/jetty.xml,${jetty.etc}/jetty-http.xml,${jetty.etc}/jetty-requestlog.xml
      nexus-context-path=#{nexus_proxy_path}
    PROPERTIES
    it 'creates the /home/nexus/etc/nexus.properties' do
      expect(chef_run).to create_file('/home/nexus/etc/nexus.properties')
        .with_content(nexus_properties_content)
    end
  end
end
