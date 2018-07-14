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
        unit_after: %w[network.target],
        unit_description: 'nexus service',
        install_wanted_by: %w[multi-user.target],
        service_exec_start: '/opt/nexus/bin/nexus start',
        service_exec_stop: '/opt/nexus/bin/nexus stop',
        service_limit_nofile: 65_536,
        service_restart: 'on-abort',
        service_type: 'forking',
        service_user: 'nexus'
      )
    end
  end

  context 'adds the jolokia settings to the jvm properties' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    nexus_jvm_properties_content = <<~PROPERTIES
      -Xms1200M
      -Xmx1200M
      -XX:MaxDirectMemorySize=2G
      -XX:+HeapDumpOnOutOfMemoryError
      -XX:+UnlockDiagnosticVMOptions
      -XX:+UnsyncloadClass
      -XX:+LogVMOutput
      -Djava.net.preferIPv4Stack=true
      -Dkaraf.home=.
      -Dkaraf.base=.
      -Dkaraf.etc=etc/karaf
      -Djava.util.logging.config.file=etc/karaf/java.util.logging.properties
      -Dkaraf.data=/home/nexus
      -Djava.io.tmpdir=/home/nexus/tmp
      -XX:LogFile=/home/nexus/log/jvm.log
      -Dkaraf.startLocalConsole=false
      -javaagent:/usr/local/jolokia/jolokia.jar=protocol=http,host=127.0.0.1,port=8090,discoveryEnabled=false
    PROPERTIES
    it 'creates the /opt/nexus-3.12.1-01/bin/nexus.vmoptions' do
      expect(chef_run).to create_file('/opt/nexus-3.12.1-01/bin/nexus.vmoptions')
        .with_content(nexus_jvm_properties_content)
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
