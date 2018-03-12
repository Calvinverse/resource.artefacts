# frozen_string_literal: true

require 'spec_helper'

nexus_management_port = 8081
nexus_proxy_path = '/artefacts'

describe 'resource_artefacts::nexus_npm' do
  context 'creates the file system mounts' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates and mounts the nexus_npm file system at /srv/nexus/blob/npm' do
      expect(chef_run).to create_directory('/srv/nexus/blob/npm').with(
        group: 'nexus',
        mode: '777',
        owner: 'nexus'
      )
    end
  end

  context 'creates npm repositories' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates a write blob store for production npm packages' do
      expect(chef_run).to run_nexus3_api('npm-production-write-blob').with(
        content: "blobStore.createFileBlobStore('npm_production_write', '/srv/nexus/blob/npm/npm_production_write')"
      )
    end

    it 'creates a write repository for production npm packages' do
      expect(chef_run).to run_nexus3_api('npm-production-write').with(
        content: "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createNpmHosted('npm-production-write', 'npm_production_write', true, WritePolicy.ALLOW_ONCE)"
      )
    end

    it 'creates a write blob store for qa npm packages' do
      expect(chef_run).to run_nexus3_api('npm-qa-write-blob').with(
        content: "blobStore.createFileBlobStore('npm_qa_write', '/srv/nexus/blob/npm/npm_qa_write')"
      )
    end

    it 'creates a write repository for qa npm packages' do
      expect(chef_run).to run_nexus3_api('npm-qa-write').with(
        content: "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createNpmHosted('npm-qa-write', 'npm_qa_write', true, WritePolicy.ALLOW)"
      )
    end

    it 'creates a blob store for mirrored npm packages' do
      expect(chef_run).to run_nexus3_api('npm-mirror-blob').with(
        content: "blobStore.createFileBlobStore('npm_mirror', '/srv/nexus/blob/scratch/npm_mirror')"
      )
    end

    it 'creates a repository for mirror npm packages' do
      expect(chef_run).to run_nexus3_api('npm-mirror').with(
        content: "repository.createNpmProxy('npmjs.org','https://www.npmjs.org/', 'npm_mirror', true)"
      )
    end

    it 'creates a read blob store for production npm packages' do
      expect(chef_run).to run_nexus3_api('npm-production-group-blob').with(
        content: "blobStore.createFileBlobStore('npm_production_read', '/srv/nexus/blob/scratch/npm_production_read')"
      )
    end

    it 'creates a read repository for production npm packages' do
      expect(chef_run).to run_nexus3_api('npm-production-read').with(
        content: "repository.createNpmGroup('npm-production-read', ['npm-production-write', 'npmjs.org'], 'npm_production_group')"
      )
    end

    it 'creates a read blob store for qa npm packages' do
      expect(chef_run).to run_nexus3_api('npm-qa-group-blob').with(
        content: "blobStore.createFileBlobStore('npm_qa_read', '/srv/nexus/blob/scratch/npm_qa_read')"
      )
    end

    it 'creates a read repository for qa npm packages' do
      expect(chef_run).to run_nexus3_api('npm-qa-read').with(
        content: "repository.createNpmGroup('npm-qa-read', ['npm-production-write', 'npm-qa-write', 'npmjs.org'], 'npm_qa_group')"
      )
    end

    it 'enables the npm bearer token realm' do
      expect(chef_run).to run_nexus3_api('npm-bearer-token').with(
        content: 'import org.sonatype.nexus.security.realm.RealmManager;' \
        'realmManager = container.lookup(RealmManager.class.getName());' \
        "realmManager.enableRealm('NpmToken', true);"
      )
    end
  end

  context 'registers the service with consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    consul_nexus_npm_production_read_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
                "id": "nexus_npm_production_read_api_ping",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus NPM production read repository ping",
                "timeout": "5s"
              }
            ],
            "enableTagOverride": false,
            "id": "nexus_npm_production_read_api",
            "name": "artefacts",
            "port": #{nexus_management_port},
            "tags": [
              "read-production-npm"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-npm-production-read.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-npm-production-read.json')
        .with_content(consul_nexus_npm_production_read_config_content)
    end

    consul_nexus_npm_production_write_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
                "id": "nexus_npm_production_write_api_ping",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus NPM production write repository ping",
                "timeout": "5s"
              }
            ],
            "enableTagOverride": false,
            "id": "nexus_npm_production_write_api",
            "name": "artefacts",
            "port": #{nexus_management_port},
            "tags": [
              "write-production-npm"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-npm-production-write.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-npm-production-write.json')
        .with_content(consul_nexus_npm_production_write_config_content)
    end

    consul_nexus_npm_qa_read_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
                "id": "nexus_npm_qa_read_api_ping",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus NPM QA read repository ping",
                "timeout": "5s"
              }
            ],
            "enableTagOverride": false,
            "id": "nexus_npm_qa_read_api",
            "name": "artefacts",
            "port": #{nexus_management_port},
            "tags": [
              "read-qa-npm"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-npm-qa-read.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-npm-qa-read.json')
        .with_content(consul_nexus_npm_qa_read_config_content)
    end

    consul_nexus_npm_qa_write_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
                "id": "nexus_npm_qa_write_api_ping",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus NPM QA write repository ping",
                "timeout": "5s"
              }
            ],
            "enableTagOverride": false,
            "id": "nexus_npm_qa_write_api",
            "name": "artefacts",
            "port": #{nexus_management_port},
            "tags": [
              "write-qa-npm"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-npm-qa-write.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-npm-qa-write.json')
        .with_content(consul_nexus_npm_qa_write_config_content)
    end
  end

  context 'create roles and users' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'create a nx-builds-pull-npm role' do
      expect(chef_run).to run_nexus3_api('role-builds-pull-npm').with(
        content: "security.addRole('nx-builds-pull-npm', 'nx-builds-pull-npm'," \
        " 'User with privileges to allow pulling packages from the different npm repositories'," \
        " ['nx-repository-view-npm-*-browse', 'nx-repository-view-npm-*-read'], [''])"
      )
    end

    it 'create a nx-builds-push-npm role' do
      expect(chef_run).to run_nexus3_api('role-builds-push-npm').with(
        content: "security.addRole('nx-builds-push-npm', 'nx-builds-push-npm'," \
        " 'User with privileges to allow pushing packages to the different npm repositories'," \
        " ['nx-repository-view-npm-*-browse', 'nx-repository-view-npm-*-read', 'nx-repository-view-npm-*-add', 'nx-repository-view-npm-*-edit'], [''])"
      )
    end

    it 'create a nx-developer-npm role' do
      expect(chef_run).to run_nexus3_api('role-developer-npm').with(
        content: "security.addRole('nx-developer-npm', 'nx-developer-npm'," \
        " 'User with privileges to allow pulling packages from the npm repositories'," \
        " ['nx-repository-view-npm-*-browse', 'nx-repository-view-npm-*-read'], [''])"
      )
    end
  end
end
