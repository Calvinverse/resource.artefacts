# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: nexus_service
#
# Copyright 2018, P. van der Velde
#

#
# INSTALL THE CALCULATOR
#

apt_package 'bc' do
  action :install
end

#
# SET THE JVM PARAMETERS
#

# Set the Jolokia jar as an agent so that we can export the JMX metrics to influx
# For the settings see here: https://jolokia.org/reference/html/agents.html#agents-jvm
jolokia_jar_path = node['jolokia']['path']['jar_file']
jolokia_agent_host = node['jolokia']['agent']['host']
jolokia_agent_port = node['jolokia']['agent']['port']
nexus_metrics_args =
  "-javaagent:#{jolokia_jar_path}=" \
  'protocol=http' \
  ",host=#{jolokia_agent_host}" \
  ",port=#{jolokia_agent_port}" \
  ',discoveryEnabled=false'

# Grant the nexus user access to to write to the nexus.vmoptions file so that we can
# alter the file just before Nexus starts in order to set the correct memory sizes for the JVM
file "#{node['nexus3']['install_path']}/bin/nexus.vmoptions" do
  action :create
  content <<~SCRIPT
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
    #{nexus_metrics_args}
  SCRIPT
  group node['nexus3']['service_group']
  mode '0770'
  owner node['nexus3']['service_user']
end

#
# NEXUS START SCRIPT
#

# This was taken from the original Nexus install and adapted to be able to feed in the total memory
# of the machine so that we can set the maximum amount of memory for Nexus dynamically when the
# machine starts. Suggestions for how much memory to allocate are taken from here:
# https://help.sonatype.com/repomanager3/system-requirements#SystemRequirements-Memory
#
# General rules:
# - set minimum heap should always equal set maximum heap
# - minimum heap size 1200MB
# - maximum heap size <= 4GB
# - minimum MaxDirectMemory size 2GB
# - minimum unallocated physical memory should be no less than 1/3 of total physical RAM to allow for virtual memory swap
# - max heap + max direct memory <= host physical RAM * 2/3
#
# Suggested:
#
# small / personal
#   repositories < 20
#   total blobstore size < 20GB
#   single repository format type
# Memory: 4GB
#   -Xms1200M
#   -Xmx1200M
#   -XX:MaxDirectMemorySize=2G
#
# medium / team
#   repositories < 50
#   total blobstore size < 200GB
#    a few repository formats
# Memory: 8GB
#   -Xms2703M
#   -Xmx2703M
#   -XX:MaxDirectMemorySize=2703M
#
# 12GB
#   -Xms4G
#   -Xmx4G
#   -XX:MaxDirectMemorySize=4014M
#
# large / enterprise
#   repositories > 50
#   total blobstore size > 200GB
#   diverse set of repository formats
# Memory: 16GB
#   -Xms4G
#   -Xmx4G
#   -XX:MaxDirectMemorySize=6717M
#
#
# One issue is that the two minimums don't make 2/3 of 4Gb, so we assume that filling up the memory to 80% is acceptable.
# To calculate the memory usage if more than 4Gb of RAM is available we assume that we max out the
start_nexus_script = "#{node['nexus3']['install_path']}/bin/set_jvm_properties.sh"
file start_nexus_script do
  action :create
  content <<~SCRIPT
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

    cat <<EOT > #{node['nexus3']['install_path']}/bin/nexus.vmoptions
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
    #{nexus_metrics_args}
  SCRIPT
  group node['nexus3']['service_group']
  mode '0550'
  owner node['nexus3']['service_user']
end

#
# UPDATE THE SERVICE
#

# Make sure the nexus service doesn't start automatically. This will be changed
# after we have provisioned the box
service 'nexus' do
  action :disable
end

# The cookbook now makes a nexus3_nexus service, which we don't want, so nuke that one
service 'nexus3_nexus' do
  action :disable
end

systemd_unit 'nexus3_nexus' do
  action %i[stop disable delete]
end

# For some reason systemd_unit delete doesn't actually delete the file, so we nuke it
# the hard way
file '/etc/systemd/system/nexus3_nexus.service' do
  action :delete
end

# Update the systemd service configuration for Nexus so that we can set
# the number of file handles for the given user
# See here: https://help.sonatype.com/display/NXRM3/System+Requirements#filehandles
systemd_service 'nexus' do
  action :create
  install do
    wanted_by %w[multi-user.target]
  end
  service do
    exec_start "/bin/sh -c \"#{start_nexus_script} && /opt/nexus/bin/nexus start\""
    exec_stop '/opt/nexus/bin/nexus stop'
    limit_nofile 65_536
    restart 'on-abort'
    type 'forking'
    user node['nexus3']['service_user']
  end
  unit do
    after %w[network.target]
    description 'nexus service'
  end
end

#
# SET THE PROXY PATH
#

nexus_data_path = node['nexus3']['data']
nexus_management_port = node['nexus3']['port']
nexus_proxy_path = node['nexus3']['proxy_path']
file "#{nexus_data_path}/etc/nexus.properties" do
  action :create
  content <<~PROPERTIES
    # Jetty section
    application-port=#{nexus_management_port}
    application-host=0.0.0.0
    nexus-args=${jetty.etc}/jetty.xml,${jetty.etc}/jetty-http.xml,${jetty.etc}/jetty-requestlog.xml
    nexus-context-path=#{nexus_proxy_path}
    nexus.onboarding.enabled=false
  PROPERTIES
end
