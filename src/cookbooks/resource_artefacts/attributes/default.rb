# frozen_string_literal: true

#
# CONSUL
#

default['consul']['version'] = '0.9.2'
default['consul']['config']['domain'] = 'consulverse'

# This is not a consul server node
default['consul']['config']['server'] = false

# For the time being don't verify incoming and outgoing TLS signatures
default['consul']['config']['verify_incoming'] = false
default['consul']['config']['verify_outgoing'] = false

# Bind the client address to the local host. The advertise and bind addresses
# will be set in a separate configuration file
default['consul']['config']['client_addr'] = '127.0.0.1'

# Do not allow consul to use the host information for the node id
default['consul']['config']['disable_host_node_id'] = true

# Disable remote exec
default['consul']['config']['disable_remote_exec'] = true

# Disable the update check
default['consul']['config']['disable_update_check'] = true

# Set the DNS configuration
default['consul']['config']['dns_config'] = {
  allow_stale: true,
  max_stale: '87600h',
  node_ttl: '10s',
  service_ttl: {
    '*': '10s'
  }
}

# Always leave the cluster if we are terminated
default['consul']['config']['leave_on_terminate'] = true

# Send all logs to syslog
default['consul']['config']['log_level'] = 'INFO'
default['consul']['config']['enable_syslog'] = true

default['consul']['config']['owner'] = 'root'

#
# FIREWALL
#

# Allow communication on the loopback address (127.0.0.1 and ::1)
default['firewall']['allow_loopback'] = true

# Do not allow MOSH connections
default['firewall']['allow_mosh'] = false

# Do not allow WinRM (which wouldn't work on Linux anyway, but close the ports just to be sure)
default['firewall']['allow_winrm'] = false

# No communication via IPv6 at all
default['firewall']['ipv6_enabled'] = false

#
# JAVA
#

default['java']['jdk_version'] = '9'
default['java']['install_flavor'] = 'openjdk'
default['java']['accept_license_agreement'] = true

#
# NEXUS
#

default['nexus3']['url'] = 'https://sonatype-download.global.ssl.fastly.net/nexus/3/nexus-3.6.0-02-unix.tar.gz'
default['nexus3']['checksum'] = '40B95B097B43CC8941A9700D24BAF25EF94867286E43EAFFA37CF188726BB2A7'
default['nexus3']['path'] = '/opt'
default['nexus3']['data'] = '/home/nexus'
default['nexus3']['home'] = '/opt/nexus'
default['nexus3']['port'] = 8081
default['nexus3']['proxy_path'] = '/artefacts'

default['nexus3']['repository']['docker']['port']['http']['production'] = 5000
default['nexus3']['repository']['docker']['port']['https']['production'] = 5001
default['nexus3']['repository']['docker']['port']['http']['qa'] = 5010
default['nexus3']['repository']['docker']['port']['https']['qa'] = 5011
default['nexus3']['repository']['docker']['port']['http']['mirror'] = 5020
default['nexus3']['repository']['docker']['port']['https']['mirror'] = 5021

default['nexus']['service_group'] = 'nexus'
default['nexus']['service_user'] = 'nexus'

#
# PROVISIONING
#

#
# UNBOUND
#

default['unbound']['service_user'] = 'unbound'
default['unbound']['service_group'] = 'unbound'

default['paths']['unbound_config'] = '/etc/unbound.d'

default['file_name']['unbound_config_file'] = 'unbound.conf'
