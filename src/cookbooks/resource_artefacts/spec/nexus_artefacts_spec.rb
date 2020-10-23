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
        mode: '770',
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

    it 'creates a blob store for development artefacts files' do
      expect(chef_run).to run_nexus3_api('artefacts-development-blob').with(
        content: "blobStore.createFileBlobStore('artefacts_development', '/srv/nexus/blob/artefacts/artefacts_development')"
      )
    end

    it 'creates a repository for development artefact files' do
      expect(chef_run).to run_nexus3_api('artefacts-development-write').with(
        content: "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createRawHosted('artefacts-development', 'artefacts_development', true, WritePolicy.ALLOW)"
      )
    end
  end

  context 'registers the service with consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    consul_nexus_artefact_production_read_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/rest/v1/status",
                "id": "nexus_artefacts_production_read_status",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus artefacts production repository read status",
                "timeout": "5s"
              }
            ],
            "enable_tag_override": false,
            "id": "nexus_artefacts_production_read",
            "name": "artefacts",
            "port": #{nexus_management_port},
            "tags": [
              "read-production"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-artefacts-production-read.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-artefacts-production-read.json')
        .with_content(consul_nexus_artefact_production_read_config_content)
    end

    consul_nexus_artefact_production_write_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/rest/v1/status/writable",
                "id": "nexus_artefacts_production_write_status",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus artefacts production repository write status",
                "timeout": "5s"
              }
            ],
            "enable_tag_override": false,
            "id": "nexus_artefacts_production_write",
            "name": "artefacts",
            "port": #{nexus_management_port},
            "tags": [
              "write-production"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-artefacts-production-write.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-artefacts-production-write.json')
        .with_content(consul_nexus_artefact_production_write_config_content)
    end

    consul_nexus_artefact_qa_read_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/rest/v1/status",
                "id": "nexus_artefacts_qa_read_status",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus artefacts QA repository read status",
                "timeout": "5s"
              }
            ],
            "enable_tag_override": false,
            "id": "nexus_artefacts_qa_read",
            "name": "artefacts",
            "port": #{nexus_management_port},
            "tags": [
              "read-qa"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-artefacts-qa-read.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-artefacts-qa-read.json')
        .with_content(consul_nexus_artefact_qa_read_config_content)
    end

    consul_nexus_artefact_qa_write_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/rest/v1/status/writable",
                "id": "nexus_artefacts_qa_write_status",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus artefacts QA repository write status",
                "timeout": "5s"
              }
            ],
            "enable_tag_override": false,
            "id": "nexus_artefacts_qa_write",
            "name": "artefacts",
            "port": #{nexus_management_port},
            "tags": [
              "write-qa"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-artefacts-qa-write.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-artefacts-qa-write.json')
        .with_content(consul_nexus_artefact_qa_write_config_content)
    end

    consul_nexus_artefact_development_read_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/rest/v1/status",
                "id": "nexus_artefacts_development_read_status",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus artefacts Development repository read status",
                "timeout": "5s"
              }
            ],
            "enable_tag_override": false,
            "id": "nexus_artefacts_development_read",
            "name": "artefacts",
            "port": #{nexus_management_port},
            "tags": [
              "read-development"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-artefacts-development-read.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-artefacts-development-read.json')
        .with_content(consul_nexus_artefact_development_read_config_content)
    end

    consul_nexus_artefact_development_write_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/rest/v1/status/writable",
                "id": "nexus_artefacts_development_write_status",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus artefacts Development repository write status",
                "timeout": "5s"
              }
            ],
            "enable_tag_override": false,
            "id": "nexus_artefacts_development_write",
            "name": "artefacts",
            "port": #{nexus_management_port},
            "tags": [
              "write-development"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-artefacts-development-write.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-artefacts-development-write.json')
        .with_content(consul_nexus_artefact_development_write_config_content)
    end

    consul_nexus_artefact_development_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
                "id": "nexus_artefacts_development_api_ping",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus artefacts Development repository ping",
                "timeout": "5s"
              }
            ],
            "enable_tag_override": false,
            "id": "nexus_artefacts_development_api",
            "name": "artefacts",
            "port": #{nexus_management_port},
            "tags": [
              "read-development",
              "write-development"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-artefacts-development.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-artefacts-development.json')
        .with_content(consul_nexus_artefact_development_config_content)
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
