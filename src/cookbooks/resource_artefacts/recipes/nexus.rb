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
# CONFIGURE THE FILE SYSTEM
#

store_path = '/srv/nexus/blob'
directory store_path do
  action :create
  recursive true
end

scratch_blob_store_path = "#{store_path}/scratch"
# filesystem 'nexus_scratch' do
#   action %i[create enable mount]
#   device '/dev/sdd'
#   fstype 'ext4'
#   mount scratch_blob_store_path
# end

directory scratch_blob_store_path do
  action :create
  group node['nexus']['service_group']
  mode '777'
  owner node['nexus']['service_user']
end

docker_blob_store_path = "#{store_path}/docker"
# filesystem 'nexus_docker' do
#   action %i[create enable mount]
#   device '/dev/sdc'
#   fstype 'ext4'
#   mount docker_blob_store_path
# end

directory docker_blob_store_path do
  action :create
  group node['nexus']['service_group']
  mode '777'
  owner node['nexus']['service_user']
end

nuget_blob_store_path = "#{store_path}/nuget"
# filesystem 'nexus_nuget' do
#   action %i[create enable mount]
#   device '/dev/sdb'
#   fstype 'ext4'
#   mount nuget_blob_store_path
# end

directory nuget_blob_store_path do
  action :create
  group node['nexus']['service_group']
  mode '777'
  owner node['nexus']['service_user']
end

#
# INSTALL NEXUS
#

nexus3 'nexus' do
  action :install
  group node['nexus']['service_group']
  user node['nexus']['service_user']
end

#
# DELETE THE DEFAULT REPOSITORIES
#

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
  content "blobStore.createFileBlobStore('#{blob_name_docker_hosted}', '#{docker_blob_store_path}/#{blob_name_docker_hosted}')"
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
  content "blobStore.createFileBlobStore('#{blob_name_docker_mirror}', '#{scratch_blob_store_path}/#{blob_name_docker_mirror}')"
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
  content "blobStore.createFileBlobStore('#{blob_name_nuget_hosted}', '#{nuget_blob_store_path}/#{blob_name_nuget_hosted}')"
  action %i[create run delete]
end

# create and run rubygems hosted, proxy and group repositories
nexus3_api 'nuget-hosted' do
  content "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createNugetHosted('nuget', '#{blob_name_nuget_hosted}', true, WritePolicy.ALLOW_ONCE)"
  action %i[create run delete]
end

blob_name_nuget_mirror = 'nuget_mirror'
nexus3_api 'nuget-mirror-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_nuget_mirror}', '#{scratch_blob_store_path}/#{blob_name_nuget_mirror}')"
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
          "id": "nexus_management",
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
          "id": "nexus_docker_hosted_api",
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
          "id": "nexus_docker_mirror_api",
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
          "id": "nexus_nuget_hosted_api",
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
          "id": "nexus_nuget_mirror_api",
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

#
# CREATE ADDITIONAL ROLES AND USERS
#

# Create the role which is used by the infrastructure for pulling docker containers
nexus3_api 'role-docker-pull' do
  content "security.addRole('nx-infrastructure-container-pull', 'nx-infrastructure-container-pull'," \
    " 'User with privileges to allow pulling containers from the different container repositories'," \
    " ['nx-repository-view-docker-*-browse', 'nx-repository-view-docker-*-read'], [''])"
  action :run
end

nexus3_api 'userNomad' do
  action :run
  content "security.addUser('nomad.container.pull', 'Nomad', 'Container.Pull', 'nomad.container.pull@example.com', true, 'nomad.container.pull', ['nx-infrastructure-container-pull'])"
end

# Create the role which is used by the build system for pulling docker containers
nexus3_api 'role-builds-pull-containers' do
  content "security.addRole('nx-builds-pull-containers', 'nx-builds-pull-containers'," \
    " 'User with privileges to allow pulling containers from the different container repositories'," \
    " ['nx-repository-view-docker-docker-browse', 'nx-repository-view-docker-docker-read'], [''])"
  action :run
end

# Create the role which is used by the build system for pushing docker containers
nexus3_api 'role-builds-push-containers' do
  content "security.addRole('nx-builds-push-containers', 'nx-builds-push-containers'," \
    " 'User with privileges to allow pushing containers to the different container repositories'," \
    " ['nx-repository-view-docker-docker-browse', 'nx-repository-view-docker-docker-read', 'nx-repository-view-docker-docker-add', 'nx-repository-view-docker-docker-edit'], [''])"
  action :run
end

# Create the role which is used by the build system for pulling nuget packages
nexus3_api 'role-builds-pull-nuget' do
  content "security.addRole('nx-builds-pull-nuget', 'nx-builds-pull-nuget'," \
    " 'User with privileges to allow pulling packages from the different nuget repositories'," \
    " ['nx-repository-view-nuget-nuget-browse', 'nx-repository-view-nuget-nuget-read'], [''])"
  action :run
end

# Create the role which is used by the build system for pushing nuget packages
nexus3_api 'role-builds-push-nuget' do
  content "security.addRole('nx-builds-push-nuget', 'nx-builds-push-nuget'," \
    " 'User with privileges to allow pushing packages to the different nuget repositories'," \
    " ['nx-repository-view-nuget-nuget-browse', 'nx-repository-view-nuget-nuget-read', 'nx-repository-view-nuget-nuget-add', 'nx-repository-view-nuget-nuget-edit'], [''])"
  action :run
end

# Create the role which is used by the developers to read docker repositories
nexus3_api 'role-developer-docker' do
  content "security.addRole('nx-developer-docker', 'nx-developer-docker'," \
    " 'User with privileges to allow pulling docker containers from the docker repositories'," \
    " ['nx-repository-view-docker-*-browse', 'nx-repository-view-docker-*-read'], [''])"
  action :run
end

# Create the role which is used by the developers to read docker repositories
nexus3_api 'role-developer-nuget' do
  content "security.addRole('nx-developer-nuget', 'nx-developer-nuget'," \
    " 'User with privileges to allow pulling nuget packages from the nuget repositories'," \
    " ['nx-repository-view-nuget-*-browse', 'nx-repository-view-nuget-*-read'], [''])"
  action :run
end

# Create the role which is used by the developers to search repositories
nexus3_api 'role-developer-search' do
  content "security.addRole('nx-developer-search', 'nx-developer-search'," \
    " 'User with privileges to allow searching for packages in the different repositories'," \
    " ['nx-search-read', 'nx-selectors-read'], [''])"
  action :run
end

#
# DISABLE ANONYMOUS ACCESS
#

nexus3_api 'anonymous' do
  action :run
  content 'security.setAnonymousAccess(false)'
  not_if { ::File.exist?("#{node['nexus3']['data']}/tmp") }
end

#
# UPDATE THE SERVICE
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
