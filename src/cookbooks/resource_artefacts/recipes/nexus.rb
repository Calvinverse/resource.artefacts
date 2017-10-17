# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: nexus
#
# Copyright 2017, P. van der Velde
#

# Configure the service user under which consul will be run
poise_service_user node['nexus']['service_user'] do
  group node['nexus']['service_group']
end

#
# INSTALL NEXUS
#

nexus3 'nexus' do
  action :install
  group node['nexus']['service_group']
  user node['nexus']['service_user']
end

blob_store_path = '/srv/nexus/blob'
directory blob_store_path do
  action :create
  group node['nexus']['service_group']
  owner node['nexus']['service_user']
  recursive true
end

# Delete the default repositories
%w[maven-central maven-public maven-releases maven-snapshots nuget-group nuget-hosted nuget.org-proxy].each do |repo|
  nexus3_api "delete_repo #{repo}" do
    action %i[create run delete]
    script_name "delete_repo_#{repo}"
    content "repository.repositoryManager.delete('#{repo}')"
  end
end

nexus3_api 'delete_default_blobstore' do
  action %i[create run delete]
  script_name 'delete_default_blobstore'
  content "blobStore.blobStoreManager.delete('default')"
end

#
# ADD THE DOCKER REPOSITORIES
#
# See: https://github.com/sonatype/nexus-public/blob/master/plugins/nexus-script-plugin/src/main/java/org/sonatype/nexus/script/plugin/RepositoryApi.java

blob_name_docker_hosted = 'docker_hosted'
nexus3_api 'docker-hosted-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_docker_hosted}', '#{blob_store_path}/#{blob_name_docker_hosted}')"
  action %i[create run delete]
end

port_http_docker_hosted = node['nexus3']['repository']['docker']['port']['http']['hosted']
port_https_docker_hosted = node['nexus3']['repository']['docker']['port']['https']['hosted']
nexus3_api 'docker-hosted' do
  content "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createDockerHosted('docker', #{port_http_docker_hosted}, #{port_https_docker_hosted}, '#{blob_name_docker_hosted}', true, true, WritePolicy.ALLOW)"
  action %i[create run delete]
end

blob_name_docker_mirror = 'docker_mirror'
nexus3_api 'docker-mirror-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_docker_mirror}', '#{blob_store_path}/#{blob_name_docker_mirror}')"
  action %i[create run delete]
end

port_http_docker_mirror = node['nexus3']['repository']['docker']['port']['http']['mirror']
port_https_docker_mirror = node['nexus3']['repository']['docker']['port']['https']['mirror']
nexus3_api 'docker-mirror' do
  content "repository.createDockerProxy('hub.docker.io','https://registry-1.docker.io', 'HUB', '', #{port_http_docker_mirror}, #{port_https_docker_mirror}, '#{blob_name_docker_mirror}', true, true)"
  action %i[create run delete]
end

#
# ADD THE NUGET REPOSITORIES
#
# See: https://github.com/sonatype/nexus-public/blob/master/plugins/nexus-script-plugin/src/main/java/org/sonatype/nexus/script/plugin/RepositoryApi.java

blob_name_nuget_hosted = 'nuget_hosted'
nexus3_api 'nuget-hosted-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_nuget_hosted}', '#{blob_store_path}/#{blob_name_nuget_hosted}')"
  action %i[create run delete]
end

# create and run rubygems hosted, proxy and group repositories
nexus3_api 'nuget-hosted' do
  content "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createNugetHosted('nuget', '#{blob_name_nuget_hosted}', true, WritePolicy.ALLOW_ONCE)"
  action %i[create run delete]
end

blob_name_nuget_mirror = 'nuget_mirror'
nexus3_api 'nuget-mirror-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_nuget_mirror}', '#{blob_store_path}/#{blob_name_nuget_mirror}')"
  action %i[create run delete]
end

nexus3_api 'nuget-mirror' do
  content "repository.createNugetProxy('nuget.org','https://www.nuget.org/api/v2/', '#{blob_name_nuget_mirror}', true)"
  action %i[create run delete]
end

#
# ALLOW NEXUS THROUGH THE FIREWALL
#

firewall_rule 'nexus-http' do
  command :allow
  description 'Allow Nexus HTTP traffic'
  dest_port 8081
  direction :in
end

firewall_rule 'nexus-docker-hosted-http' do
  command :allow
  description 'Allow Docker HTTP traffic'
  dest_port port_http_docker_hosted
  direction :in
end

firewall_rule 'nexus-docker-hosted-https' do
  command :allow
  description 'Allow Docker HTTPs traffic'
  dest_port port_https_docker_hosted
  direction :in
end

firewall_rule 'nexus-docker-mirror-http' do
  command :allow
  description 'Allow Docker HTTP traffic'
  dest_port port_http_docker_mirror
  direction :in
end

firewall_rule 'nexus-docker-mirror-https' do
  command :allow
  description 'Allow Docker HTTPs traffic'
  dest_port port_https_docker_mirror
  direction :in
end

#
# CONNECT TO CONSUL
#

# Create the user which is used by consul for the health check
nexus3_api 'role-metrics' do
  content "security.addRole('nx-metrics', 'nx-metrics'," \
    " 'User with privileges to allow read access to the Nexus metrics'," \
    " ['nx-metrics-all'], ['nx-anonymous'])"
  action :run
end

nexus3_api 'userConsul' do
  action :run
  content "security.addUser('consul.health', 'Consul', 'Health', 'consul.health@example.com', true, 'consul.health', ['nx-metrics'])"
end

file '/etc/consul/conf.d/nexus-management.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:8081/service/metrics/ping",
              "id": "nexus_management_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus management ping",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": true,
          "id": "nexus_api",
          "name": "artefacts",
          "port": 8081,
          "tags": [
            "edgeproxyprefix-/artefacts",
            "management",
            "active-management"
          ]
        }
      ]
    }
  JSON
end

file '/etc/consul/conf.d/nexus-docker-hosted.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:8081/service/metrics/ping",
              "id": "nexus_docker_hosted_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus Docker hosted repository ping",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": true,
          "id": "nexus_api",
          "name": "artefacts",
          "port": #{port_http_docker_hosted},
          "tags": [
            "read-hosted-docker",
            "write-hosted-docker"
          ]
        }
      ]
    }
  JSON
end

file '/etc/consul/conf.d/nexus-docker-mirror.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:8081/service/metrics/ping",
              "id": "nexus_docker_mirror_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus Docker mirror repository ping",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": true,
          "id": "nexus_api",
          "name": "artefacts",
          "port": #{port_http_docker_mirror},
          "tags": [
            "read-mirror-docker"
          ]
        }
      ]
    }
  JSON
end

file '/etc/consul/conf.d/nexus-nuget-hosted.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:8081/service/metrics/ping",
              "id": "nexus_nuget_hosted_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus NuGet hosted repository ping",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": true,
          "id": "nexus_api",
          "name": "artefacts",
          "port": 8081,
          "tags": [
            "read-hosted-nuget",
            "write-hosted-nuget"
          ]
        }
      ]
    }
  JSON
end

file '/etc/consul/conf.d/nexus-nuget-mirror.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:8081/service/metrics/ping",
              "id": "nexus_nuget_mirror_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus NuGet hosted repository ping",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": true,
          "id": "nexus_api",
          "name": "artefacts",
          "port": 8081,
          "tags": [
            "read-mirror-nuget"
          ]
        }
      ]
    }
  JSON
end

# Disable anonymous access
nexus3_api 'anonymous' do
  action :run
  content 'security.setAnonymousAccess(false)'
  not_if { ::File.exist?("#{node['nexus3']['data']}/tmp") }
end

#
# DISABLE THE SERVICE
#

# Make sure the nexus service doesn't start automatically. This will be changed
# after we have provisioned the box
service 'nexus' do
  action :disable
end

# Update the systemd service configuration for Nexus so that we can set
# the number of file handles for the given user
# See here: https://help.sonatype.com/display/NXRM3/System+Requirements#filehandles
systemd_service 'nexus' do
  action :create
  after %w[network.target]
  description 'nexus service'
  install do
    wanted_by %w[multi-user.target]
  end
  service do
    exec_start '/opt/nexus/bin/nexus start'
    exec_stop '/opt/nexus/bin/nexus stop'
    limit_nofile 65_536
    restart 'on-abort'
    type 'forking'
    user node['nexus']['service_user']
  end
end
