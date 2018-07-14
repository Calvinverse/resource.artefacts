# frozen_string_literal: true

require 'spec_helper'

nexus_management_port = 8081
nexus_proxy_path = '/artefacts'

describe 'resource_artefacts::nexus_nuget' do
  context 'creates the file system mounts' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates and mounts the nexus_nuget file system at /srv/nexus/blob/nuget' do
      expect(chef_run).to create_directory('/srv/nexus/blob/nuget').with(
        group: 'nexus',
        mode: '777',
        owner: 'nexus'
      )
    end
  end

  context 'creates nuget repositories' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates a write blob store for production nuget packages' do
      expect(chef_run).to run_nexus3_api('nuget-production-write-blob').with(
        content: "blobStore.createFileBlobStore('nuget_production_write', '/srv/nexus/blob/nuget/nuget_production_write')"
      )
    end

    it 'creates a write repository for production nuget packages' do
      expect(chef_run).to run_nexus3_api('nuget-production-write').with(
        content: "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createNugetHosted('nuget-production-write', 'nuget_production_write', true, WritePolicy.ALLOW_ONCE)"
      )
    end

    it 'creates a blob store for mirrored nuget packages' do
      expect(chef_run).to run_nexus3_api('nuget-mirror-blob').with(
        content: "blobStore.createFileBlobStore('nuget_mirror', '/srv/nexus/blob/scratch/nuget_mirror')"
      )
    end

    it 'creates a repository for mirror nuget packages' do
      expect(chef_run).to run_nexus3_api('nuget-mirror').with(
        content: "repository.createNugetProxy('nuget-proxy','https://www.nuget.org/api/v2/', 'nuget_mirror', true)"
      )
    end

    it 'creates a read blob store for production nuget packages' do
      expect(chef_run).to run_nexus3_api('nuget-production-group-blob').with(
        content: "blobStore.createFileBlobStore('nuget_production_group', '/srv/nexus/blob/scratch/nuget_production_group')"
      )
    end

    it 'creates a read repository for production nuget packages' do
      expect(chef_run).to run_nexus3_api('nuget-production-read').with(
        content: "repository.createNugetGroup('nuget-production-read', ['nuget-production-write', 'nuget-proxy'], 'nuget_production_group')"
      )
    end

    it 'enables the nuget api key realm' do
      expect(chef_run).to run_nexus3_api('nuget-api-key').with(
        content: 'import org.sonatype.nexus.security.realm.RealmManager;' \
        'realmManager = container.lookup(RealmManager.class.getName());' \
        "realmManager.enableRealm('NuGetApiKey', true);"
      )
    end
  end

  context 'registers the service with consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    consul_nexus_nuget_production_read_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
                "id": "nexus_nuget_production_read_api_ping",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus NuGet Production read repository ping",
                "timeout": "5s"
              }
            ],
            "enable_tag_override": false,
            "id": "nexus_nuget_production_read_api",
            "name": "artefacts",
            "port": #{nexus_management_port},
            "tags": [
              "read-production-nuget"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-nuget-production-read.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-nuget-production-read.json')
        .with_content(consul_nexus_nuget_production_read_config_content)
    end

    consul_nexus_nuget_production_write_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
                "id": "nexus_nuget_production_write_api_ping",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus NuGet Production write repository ping",
                "timeout": "5s"
              }
            ],
            "enable_tag_override": false,
            "id": "nexus_nuget_production_write_api",
            "name": "artefacts",
            "port": #{nexus_management_port},
            "tags": [
              "write-production-nuget"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-nuget-production-write.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-nuget-production-write.json')
        .with_content(consul_nexus_nuget_production_write_config_content)
    end
  end

  context 'create roles and users' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'create a nx-builds-pull-nuget role' do
      expect(chef_run).to run_nexus3_api('role-builds-pull-nuget').with(
        content: "security.addRole('nx-builds-pull-nuget', 'nx-builds-pull-nuget'," \
        " 'User with privileges to allow pulling packages from the different nuget repositories'," \
        " ['nx-repository-view-nuget-*-browse', 'nx-repository-view-nuget-*-read'], [''])"
      )
    end

    it 'create a nx-builds-push-nuget role' do
      expect(chef_run).to run_nexus3_api('role-builds-push-nuget').with(
        content: "security.addRole('nx-builds-push-nuget', 'nx-builds-push-nuget'," \
        " 'User with privileges to allow pushing packages to the different nuget repositories'," \
        " ['nx-repository-view-nuget-*-browse', 'nx-repository-view-nuget-*-read', 'nx-repository-view-nuget-*-add', 'nx-repository-view-nuget-*-edit'], [''])"
      )
    end

    it 'create a nx-developer-nuget role' do
      expect(chef_run).to run_nexus3_api('role-developer-nuget').with(
        content: "security.addRole('nx-developer-nuget', 'nx-developer-nuget'," \
        " 'User with privileges to allow pulling packages from the nuget repositories'," \
        " ['nx-repository-view-nuget-*-browse', 'nx-repository-view-nuget-*-read'], [''])"
      )
    end
  end
end
