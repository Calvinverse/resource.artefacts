# frozen_string_literal: true

require 'spec_helper'

describe 'resource_artefacts::nexus_metrics' do
  context 'installs jolokia' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the jolokia install directory' do
      expect(chef_run).to create_directory('/usr/local/jolokia')
    end

    it 'installs the jolokia jar file' do
      expect(chef_run).to create_remote_file('/usr/local/jolokia/jolokia.jar')
        .with(
          source: 'http://search.maven.org/remotecontent?filepath=org/jolokia/jolokia-jvm/1.6.0/jolokia-jvm-1.6.0-agent.jar'
        )
    end
  end

  context 'adds the consul-template files for the telegraf jolokia input' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    telegraf_jolokia_template_content = <<~CONF
      # Telegraf Configuration

      ###############################################################################
      #                            INPUT PLUGINS                                    #
      ###############################################################################

      [[inputs.jolokia2_agent]]
      urls = ["http://127.0.0.1:8090/jolokia"]
        [inputs.jolokia2_agent.tags]
          influxdb_database = "{{ keyOrDefault "config/services/metrics/databases/services" "services" }}"
          service = "nexus"

        # JVM metrics
        # Runtime
        [[inputs.jolokia2_agent.metric]]
          name  = "jvm_runtime"
          mbean = "java.lang:type=Runtime"
          paths = ["Uptime"]

        # Memory
        [[inputs.jolokia2_agent.metric]]
          name  = "jvm_memory"
          mbean = "java.lang:type=Memory"
          paths = ["HeapMemoryUsage", "NonHeapMemoryUsage", "ObjectPendingFinalizationCount"]

        # GC
        [[inputs.jolokia2_agent.metric]]
          name  = "jvm_garbage_collector"
          mbean = "java.lang:name=*,type=GarbageCollector"
          paths = ["CollectionTime", "CollectionCount"]
          tag_keys = ["name"]

        # MemoryPool
        [[inputs.jolokia2_agent.metric]]
          name  = "jvm_memory_pool"
          mbean = "java.lang:name=*,type=MemoryPool"
          paths = ["Usage", "PeakUsage", "CollectionUsage"]
          tag_keys = ["name"]
          tag_prefix = "pool_"

        # Operating system
        [[inputs.jolokia2_agent.metric]]
          name  = "jvm_operating_system"
          mbean = "java.lang:type=OperatingSystem"
          paths = [
            "CommittedVirtualMemorySize",
            "FreePhysicalMemorySize",
            "FreeSwapSpaceSize",
            "TotalPhysicalMemorySize",
            "TotalSwapSpaceSize",
            "AvailableProcessors",
            "SystemCpuLoad",
            "ProcessCpuTime",
            "ProcessCpuLoad",
            "SystemLoadAverage",
          ]

        # Java.nio
        # BufferPool
        [[inputs.jolokia2_agent.metric]]
          name  = "jvm_buffer_pool"
          mbean = "java.nio:name=*,type=MemoryPool"
          paths = ["TotalCapacity", "MemoryUsed", "Count"]
          tag_keys = ["name"]
          tag_prefix = "buffer_"

        # Nexus
    CONF
    it 'creates telegraf jolokia template file in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/telegraf_jolokia_inputs.ctmpl')
        .with_content(telegraf_jolokia_template_content)
    end

    consul_template_telegraf_jolokia_configuration_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/telegraf_jolokia_inputs.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/etc/telegraf/telegraf.d/inputs_jolokia.conf"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "systemctl reload telegraf"

        # This is the maximum amount of time to wait for the optional command to
        # return. Default is 30s.
        command_timeout = "15s"

        # Exit with an error when accessing a struct or map field/key that does not
        # exist. The default behavior will print "<no value>" when accessing a field
        # that does not exist. It is highly recommended you set this to "true" when
        # retrieving secrets from Vault.
        error_on_missing_key = false

        # This is the permission to render the file. If this option is left
        # unspecified, Consul Template will attempt to match the permissions of the
        # file that already exists at the destination path. If no file exists at that
        # path, the permissions are 0644.
        perms = 0755

        # This option backs up the previously rendered template at the destination
        # path before writing a new one. It keeps exactly one backup. This option is
        # useful for preventing accidental changes to the data without having a
        # rollback strategy.
        backup = true

        # These are the delimiters to use in the template. The default is "{{" and
        # "}}", but for some templates, it may be easier to use a different delimiter
        # that does not conflict with the output file itself.
        left_delimiter  = "{{"
        right_delimiter = "}}"

        # This is the `minimum(:maximum)` to wait before rendering a new template to
        # disk and triggering a command, separated by a colon (`:`). If the optional
        # maximum value is omitted, it is assumed to be 4x the required minimum value.
        # This is a numeric time with a unit suffix ("5s"). There is no default value.
        # The wait value for a template takes precedence over any globally-configured
        # wait.
        wait {
          min = "2s"
          max = "10s"
        }
      }
    CONF
    it 'creates telegraf_jolokia_inputs.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/telegraf_jolokia_inputs.hcl')
        .with_content(consul_template_telegraf_jolokia_configuration_content)
    end
  end
end
