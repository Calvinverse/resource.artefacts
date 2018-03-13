# frozen_string_literal: true

require 'spec_helper'

nexus_management_port = 8081
nexus_proxy_path = '/artefacts'

describe 'resource_artefacts::nexus_artefacts' do
  context 'creates the file system mounts' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates and mounts the nexus_artefacts file system at /srv/nexus/blob/artefacts' do
      expect(chef_run).to create_directory('/srv/nexus/blob/artefacts').with(
        group: 'nexus',
        mode: '777',
        owner: 'nexus'
      )
    end
  end

  context 'creates artefacts repositories' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates a blob store for production artefacts files' do
      expect(chef_run).to run_nexus3_api('artefacts-production-blob').with(
        content: "blobStore.createFileBlobStore('artefacts_production', '/srv/nexus/blob/artefacts/artefacts_production')"
      )
    end

    it 'creates a repository for production artefact files' do
      expect(chef_run).to run_nexus3_api('artefacts-production-write').with(
        content: "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createRawHosted('artefacts-production', 'artefacts_production', true, WritePolicy.ALLOW_ONCE)"
      )
    end

    it 'creates a blob store for qa artefacts files' do
      expect(chef_run).to run_nexus3_api('artefacts-qa-blob').with(
        content: "blobStore.createFileBlobStore('artefacts_qa', '/srv/nexus/blob/artefacts/artefacts_qa')"
      )
    end

    it 'creates a repository for qa artefact files' do
      expect(chef_run).to run_nexus3_api('artefacts-qa-write').with(
        content: "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createRawHosted('artefacts-qa', 'artefacts_qa', true, WritePolicy.ALLOW)"
      )
    end
  end

  context 'registers the service with consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    consul_nexus_artefact_production_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
                "id": "nexus_artefacts_production_api_ping",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus artefacts production repository ping",
                "timeout": "5s"
              }
            ],
            "enableTagOverride": false,
            "id": "nexus_artefacts_production_api",
            "name": "artefacts",
            "port": #{nexus_management_port},
            "tags": [
              "read-production",
              "write-production"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-artefacts-production.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-artefacts-production.json')
        .with_content(consul_nexus_artefact_production_config_content)
    end

    consul_nexus_artefact_qa_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
                "id": "nexus_artefacts_qa_api_ping",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus artefacts QA repository ping",
                "timeout": "5s"
              }
            ],
            "enableTagOverride": false,
            "id": "nexus_artefacts_qa_api",
            "name": "artefacts",
            "port": #{nexus_management_port},
            "tags": [
              "read-qa",
              "write-qa"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-artefacts-qa.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-artefacts-qa.json')
        .with_content(consul_nexus_artefact_qa_config_content)
    end
  end

  context 'create roles and users' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'create a nx-builds-pull-artefacts role' do
      expect(chef_run).to run_nexus3_api('role-builds-pull-artefacts').with(
        content: "security.addRole('nx-builds-pull-artefacts', 'nx-builds-pull-artefacts'," \
        " 'User with privileges to allow pulling artefacts from the different repositories'," \
        " ['nx-repository-view-raw-*-browse', 'nx-repository-view-raw-*-read'], [''])"
      )
    end

    it 'create a nx-builds-push-artefacts role' do
      expect(chef_run).to run_nexus3_api('role-builds-push-artefacts').with(
        content: "security.addRole('nx-builds-push-artefacts', 'nx-builds-push-artefacts'," \
        " 'User with privileges to allow pushing artefacts to the different repositories'," \
        " ['nx-repository-view-raw-*-browse', 'nx-repository-view-raw-*-read', 'nx-repository-view-raw-*-add', 'nx-repository-view-raw-*-edit'], [''])"
      )
    end

    it 'create a nx-developer-artefacts role' do
      expect(chef_run).to run_nexus3_api('role-developer-artefacts').with(
        content: "security.addRole('nx-developer-artefacts', 'nx-developer-artefacts'," \
        " 'User with privileges to allow pulling artefacts'," \
        " ['nx-repository-view-raw-*-browse', 'nx-repository-view-raw-*-read'], [''])"
      )
    end
  end
end
