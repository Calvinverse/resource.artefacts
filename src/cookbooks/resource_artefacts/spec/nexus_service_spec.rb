# frozen_string_literal: true

require 'spec_helper'

nexus_management_port = 8081
nexus_proxy_path = '/artefacts'

describe 'resource_artefacts::nexus_service' do
  context 'adds the jolokia settings to the jvm properties' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    nexus_jvm_properties_content = <<~PROPERTIES
      -XX:+UseConcMarkSweepGC
      -XX:+ExplicitGCInvokesConcurrent
      -XX:+ParallelRefProcEnabled
      -XX:+UseStringDeduplication
      -XX:+CMSParallelRemarkEnabled
      -XX:+CMSIncrementalMode
      -XX:CMSInitiatingOccupancyFraction=75
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
    it 'creates the /opt/nexus/bin/nexus.vmoptions' do
      expect(chef_run).to create_file('/opt/nexus/bin/nexus.vmoptions')
        .with_content(nexus_jvm_properties_content)
    end
  end

  context 'configures the service' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'disables the nexus service' do
      expect(chef_run).to disable_service('nexus')
    end

    it 'disables the nexus3_nexus service' do
      expect(chef_run).to disable_service('nexus3_nexus')
    end

    it 'deletes the nexus3_nexus service' do
      expect(chef_run).to stop_systemd_unit('nexus3_nexus')
      expect(chef_run).to disable_systemd_unit('nexus3_nexus')
      expect(chef_run).to delete_systemd_unit('nexus3_nexus')
    end

    nexus_start_script_content = <<~SCRIPT
      #!/bin/sh

      max_memory() {
        max_mem=$(free -m | grep -oP '\\d+' | head -n 1)
        echo "${max_mem}"
      }

      java_memory() {
        java_max_memory=""

        max_mem="$(max_memory)"

        # Check for the 'real memory size' and calculate mx from a ratio given. Default is 80% so
        # that we can get the minimum requirements for the maximum memory and the maximum direct
        # memory as given here: https://help.sonatype.com/repomanager3/system-requirements#SystemRequirements-Memory
        ratio=80
        mx=$(echo "(${max_mem} * ${ratio} / 100 + 0.5)" | bc | awk '{printf("%d\\n",$1 + 0.5)}')

        # Define how much we are above 4Gb. If 4Gb or less return 0
        above_min=$(echo "n=(${max_mem} - 4096);if(n>0) n else 0" | bc | awk '{printf("%d\\n",$1 + 0.5)}')

        # Calculate how much memory we want to allocate
        max_java_mem=$(echo "(${above_min} / 8192) * 2800 + 1200" | bc -l | awk '{printf("%d\\n",$1 + 0.5)}')

        # Left over of the 80% goes to the direct memory
        max_java_direct_mem=$(echo "${mx} - ${max_java_mem}" | bc | awk '{printf("%d\\n",$1 + 0.5)}')

        echo "-Xmx${max_java_mem}m\\n-Xms${max_java_mem}m\\n-XX:MaxDirectMemorySize=${max_java_direct_mem}m"
      }

      java_mem="$(java_memory)"

      cat <<EOT > /opt/nexus/bin/nexus.vmoptions
      ${java_mem}
      -XX:+UseConcMarkSweepGC
      -XX:+ExplicitGCInvokesConcurrent
      -XX:+ParallelRefProcEnabled
      -XX:+UseStringDeduplication
      -XX:+CMSParallelRemarkEnabled
      -XX:+CMSIncrementalMode
      -XX:CMSInitiatingOccupancyFraction=75
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
    SCRIPT
    it 'updates the /opt/nexus/bin/set_jvm_properties.sh script' do
      expect(chef_run).to create_file('/opt/nexus/bin/set_jvm_properties.sh')
        .with_content(nexus_start_script_content)
    end

    it 'updates the nexus service' do
      expect(chef_run).to create_systemd_service('nexus').with(
        action: [:create],
        unit_after: %w[network.target],
        unit_description: 'nexus service',
        install_wanted_by: %w[multi-user.target],
        service_exec_start: '/bin/sh -c "/opt/nexus/bin/set_jvm_properties.sh && /opt/nexus/bin/nexus start"',
        service_exec_stop: '/opt/nexus/bin/nexus stop',
        service_limit_nofile: 65_536,
        service_restart: 'on-abort',
        service_type: 'forking',
        service_user: 'nexus'
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
      nexus.onboarding.enabled=false
    PROPERTIES
    it 'creates the /home/nexus/etc/nexus.properties' do
      expect(chef_run).to create_file('/home/nexus/etc/nexus.properties')
        .with_content(nexus_properties_content)
    end
  end
end
