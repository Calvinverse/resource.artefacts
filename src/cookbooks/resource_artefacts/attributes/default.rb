# frozen_string_literal: true

backup_path = '/srv/backup/scratch'

#
# BACKUP
#

default['backup']['base_path'] = backup_path

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
# JOLOKIA
#

default['jolokia']['path']['jar'] = '/usr/local/jolokia'
default['jolokia']['path']['jar_file'] = "#{node['jolokia']['path']['jar']}/jolokia.jar"

default['jolokia']['agent']['context'] = 'jolokia' # Set this to default because the runtime gets angry otherwise
default['jolokia']['agent']['host'] = '127.0.0.1' # Linux prefers going to IPv6, but Jolokia hates IPv6
default['jolokia']['agent']['port'] = 8090

default['jolokia']['telegraf']['consul_template_inputs_file'] = 'telegraf_jolokia_inputs.ctmpl'

default['jolokia']['version'] = '1.6.0'
default['jolokia']['checksum'] = '40123D4728CB62BF7D4FD3C8DE7CF3A0F955F89453A645837E611BA8E6924E02'
default['jolokia']['url']['jar'] = "http://search.maven.org/remotecontent?filepath=org/jolokia/jolokia-jvm/#{node['jolokia']['version']}/jolokia-jvm-#{node['jolokia']['version']}-agent.jar"

#
# NEXUS
#

<<<<<<< Updated upstream
default['nexus3']['version'] = '3.15.2-04'
=======
default['nexus3']['version'] = '3.18.1-01'
default['nexus3']['url'] = "https://download.sonatype.com/nexus/3/nexus-#{node['nexus3']['version']}-unix.tar.gz"
>>>>>>> Stashed changes
default['nexus3']['path'] = '/opt'
default['nexus3']['data'] = '/home/nexus'
default['nexus3']['home'] = '/opt/nexus'
default['nexus3']['scripts'] = '/etc/nexus'
default['nexus3']['install_path'] = "#{node['nexus3']['path']}/nexus"
default['nexus3']['port'] = 8081
default['nexus3']['proxy_path'] = '/artefacts'
default['nexus3']['data_store_path'] = '/srv/nexus'
default['nexus3']['blob_store_path'] = "#{node['nexus3']['data_store_path']}/blob"
default['nexus3']['scratch_blob_store_path'] = "#{node['nexus3']['blob_store_path']}/scratch"
default['nexus3']['backup_path'] = "#{backup_path}/nexus"
default['nexus3']['restore_path'] = "#{backup_path}/restore"
default['nexus3']['instance_name'] = 'nexus'
default['nexus3']['service_name'] = node['nexus3']['instance_name']

# users
default['nexus3']['users']['backup']['username'] = 'nexus.backup'
default['nexus3']['users']['backup']['password'] = SecureRandom.uuid

default['nexus3']['users']['ldap_config']['username'] = 'consul.template'
default['nexus3']['users']['ldap_config']['password'] = SecureRandom.uuid

default['nexus3']['users']['telegraf']['username'] = 'telegraf.metrics'
default['nexus3']['users']['telegraf']['password'] = SecureRandom.uuid

default['nexus3']['user']['telegraf']['username'] = 'telegraf.metrics'
default['nexus3']['user']['telegraf']['password'] = SecureRandom.uuid

# repositories
default['nexus3']['repository']['docker']['port']['http']['production']['read'] = 5000
default['nexus3']['repository']['docker']['port']['https']['production']['read'] = 5001
default['nexus3']['repository']['docker']['port']['http']['production']['write'] = 5002
default['nexus3']['repository']['docker']['port']['https']['production']['write'] = 5003

default['nexus3']['repository']['docker']['port']['http']['qa']['read'] = 5010
default['nexus3']['repository']['docker']['port']['https']['qa']['read'] = 5011
default['nexus3']['repository']['docker']['port']['http']['qa']['write'] = 5012
default['nexus3']['repository']['docker']['port']['https']['qa']['write'] = 5013

default['nexus3']['repository']['docker']['port']['http']['mirror'] = 5020
default['nexus3']['repository']['docker']['port']['https']['mirror'] = 5021

default['nexus3']['service_group'] = 'nexus'
default['nexus3']['service_user'] = 'nexus'

# consul-template
default['nexus3']['consul_template_ldap_script_file'] = 'nexus_ldap_script.ctmpl'
default['nexus3']['script_ldap_file'] = '/tmp/nexus_ldap.sh'

# override defaults
default['nexus3']['api']['host'] = "http://localhost:#{node['nexus3']['port']}"
default['nexus3']['api']['endpoint'] = "#{node['nexus3']['api']['host']}/service/rest/v1/script/"
default['nexus3']['api']['sensitive'] = false

# scripts
default['nexus3']['script']['path']['nexus_utilities'] = "#{node['nexus3']['scripts']}/nexus_utilities.sh"

#
# RESTORE
#

default['restore']['service_name'] = 'restore'

default['restore']['path']['flag'] = '/var/log/restore.flag'

default['restore']['status']['done'] = 'Done'
default['restore']['status']['waiting'] = 'Waiting'

#
# TELEGRAF
#

default['telegraf']['service_user'] = 'telegraf'
default['telegraf']['service_group'] = 'telegraf'
default['telegraf']['config_directory'] = '/etc/telegraf/telegraf.d'

default['telegraf']['http-listener']['port'] = 9090
default['telegraf']['http-listener']['path'] = '/telegraf'
