# frozen_string_literal: true

#
# CONSULTEMPLATE
#

default['consul_template']['config_path'] = '/etc/consul-template.d/conf'
default['consul_template']['template_path'] = '/etc/consul-template.d/templates'

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
# TELEGRAF
#

default['telegraf']['config_directory'] = '/etc/telegraf/telegraf.d'
