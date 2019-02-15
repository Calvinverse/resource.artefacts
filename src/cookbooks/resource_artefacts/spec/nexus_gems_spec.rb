# frozen_string_literal: true

require 'spec_helper'

nexus_management_port = 8081
nexus_proxy_path = '/artefacts'

describe 'resource_artefacts::nexus_gems' do
  context 'creates ruby gems repositories' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates a blob store for mirrored ruby gems packages' do
      expect(chef_run).to run_nexus3_api('gems-mirror-blob').with(
        content: "blobStore.createFileBlobStore('gems_mirror', '/srv/nexus/blob/scratch/gems_mirror')"
      )
    end

    it 'creates a repository for mirror ruby gems packages' do
      expect(chef_run).to run_nexus3_api('gems-mirror').with(
        content: "repository.createRubygemsProxy('rubygems.org','https://rubygems.org', 'gems_mirror', true)"
      )
    end
  end

  context 'registers the service with consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    consul_nexus_gems_mirror_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
                "id": "nexus_gems_mirror_api_ping",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus Ruby Gems mirror repository ping",
                "timeout": "5s"
              }
            ],
            "enable_tag_override": false,
            "id": "nexus_gems_mirror_api",
            "name": "gems",
            "port": #{nexus_management_port},
            "tags": [
              "read-mirror"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-gems-mirror.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-gems-mirror.json')
        .with_content(consul_nexus_gems_mirror_config_content)
    end
  end

  context 'create roles and users' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'create a nx-builds-pull-rubygems role' do
      expect(chef_run).to run_nexus3_api('role-builds-pull-rubygems').with(
        content: "security.addRole('nx-builds-pull-rubygems', 'nx-builds-pull-rubygems'," \
        " 'User with privileges to allow pulling packages from the different rubygems repositories'," \
        " ['nx-repository-view-rubygems-*-browse', 'nx-repository-view-rubygems-*-read'], [''])"
      )
    end

    it 'create a nx-developer-rubygems role' do
      expect(chef_run).to run_nexus3_api('role-developer-rubygems').with(
        content: "security.addRole('nx-developer-rubygems', 'nx-developer-rubygems'," \
        " 'User with privileges to allow pulling packages from the ruby gems repositories'," \
        " ['nx-repository-view-rubygems-*-browse', 'nx-repository-view-rubygems-*-read'], [''])"
      )
    end
  end
end
