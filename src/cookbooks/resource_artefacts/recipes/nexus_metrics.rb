# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: nexus_metrics
#
# Copyright 2018, P. van der Velde
#

#
# INSTALL JOLOKIA AGENT
#

jolokia_install_path = node['jolokia']['path']['jar']
directory jolokia_install_path do
  action :create
  group node['jolokia']['service_group']
  mode '0775'
  owner node['jolokia']['service_user']
end

jolokia_jar_path = node['jolokia']['path']['jar_file']
remote_file jolokia_jar_path do
  action :create
  checksum node['jolokia']['checksum']
  group node['jolokia']['service_group']
  mode '0755'
  owner node['jolokia']['service_user']
  source node['jolokia']['url']['jar']
end

#
# CONSUL-TEMPLATE FILES FOR TELEGRAF
#

telegraf_metrics_username = node['nexus3']['user']['telegraf']['username']
telegraf_metrics_password = node['nexus3']['user']['telegraf']['password']
nexus3_api 'user-telegraf' do
  action :run
  content "security.addUser('#{telegraf_metrics_username}', 'Telegraf', 'Metrics', 'telegraf.metrics@vista.co', true, '#{telegraf_metrics_password}', ['nx-metrics'])"
end

consul_template_config_path = node['consul_template']['config_path']
consul_template_template_path = node['consul_template']['template_path']

jolokia_agent_context = node['jolokia']['agent']['context']
jolokia_agent_host = node['jolokia']['agent']['host']
jolokia_agent_port = node['jolokia']['agent']['port']

nexus_management_port = node['nexus3']['port']
nexus_proxy_path = node['nexus3']['proxy_path']

telegraf_service = 'telegraf'
telegraf_config_directory = node['telegraf']['config_directory']
telegraf_jolokia_inputs_template_file = node['jolokia']['telegraf']['consul_template_inputs_file']
file "#{consul_template_template_path}/#{telegraf_jolokia_inputs_template_file}" do
  action :create
  content <<~CONF
    # Telegraf Configuration

    ###############################################################################
    #                            INPUT PLUGINS                                    #
    ###############################################################################

    [[inputs.jolokia2_agent]]
    urls = ["http://#{jolokia_agent_host}:#{jolokia_agent_port}/#{jolokia_agent_context}"]
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

    [[inputs.http]]
      ## One or more URLs from which to read formatted metrics
      urls = [
        "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/data"
      ]

      ## HTTP method
      # method = "GET"

      ## Optional HTTP headers
      # headers = {"X-Special-Header" = "Special-Value"}

      ## HTTP entity-body to send with POST/PUT requests.
      # body = ""

      ## HTTP Content-Encoding for write request body, can be set to "gzip" to
      ## compress body or "identity" to apply no encoding.
      # content_encoding = "identity"

      ## Optional HTTP Basic Auth Credentials
      username = "#{telegraf_metrics_username}"
      password = "#{telegraf_metrics_password}"

      ## Optional TLS Config
      # tls_ca = "/etc/telegraf/ca.pem"
      # tls_cert = "/etc/telegraf/cert.pem"
      # tls_key = "/etc/telegraf/key.pem"
      ## Use TLS but skip chain & host verification
      # insecure_skip_verify = false

      ## Amount of time allowed to complete the HTTP request
      # timeout = "5s"

      ## Data format to consume.
      ## Each data format has its own unique set of configuration options, read
      ## more about them here:
      ## https://github.com/influxdata/telegraf/blob/master/docs/DATA_FORMATS_INPUT.md
      data_format = "json"

      [inputs.http.tags]
        influxdb_database = "{{ keyOrDefault "config/services/metrics/databases/services" "services" }}"
        service = "nexus"
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

file "#{consul_template_config_path}/telegraf_jolokia_inputs.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{telegraf_jolokia_inputs_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{telegraf_config_directory}/inputs_jolokia.conf"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "/bin/bash -c 'chown #{node['telegraf']['service_user']}:#{node['telegraf']['service_group']} #{telegraf_config_directory}/inputs_jolokia.conf && systemctl restart #{telegraf_service}'"

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
      perms = 0550

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
  HCL
  group 'root'
  mode '0550'
  owner 'root'
end
