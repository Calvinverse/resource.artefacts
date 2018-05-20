# frozen_string_literal: true

require 'spec_helper'

nexus_management_port = 8081
nexus_proxy_path = '/artefacts'

describe 'resource_artefacts::nexus' do
  context 'creates the nexus user' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }
  end

  context 'creates the file system mounts' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates and mounts the nexus_scratch file system at /srv/nexus/blob/scratch' do
      expect(chef_run).to create_directory('/srv/nexus/blob/scratch').with(
        group: 'nexus',
        mode: '777',
        owner: 'nexus'
      )
    end
  end

  context 'configures nexus' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs nexus' do
      expect(chef_run).to install_nexus3('nexus')
    end

    it 'disables anonymous access' do
      expect(chef_run).to run_nexus3_api('anonymous').with(
        content: 'security.setAnonymousAccess(false)'
      )
    end

    it 'deletes the maven-central repository' do
      expect(chef_run).to run_nexus3_api('delete_repo maven-central')
    end

    it 'deletes the maven-public repository' do
      expect(chef_run).to run_nexus3_api('delete_repo maven-public')
    end

    it 'deletes the maven-releases repository' do
      expect(chef_run).to run_nexus3_api('delete_repo maven-releases')
    end

    it 'deletes the maven-snapshots repository' do
      expect(chef_run).to run_nexus3_api('delete_repo maven-snapshots')
    end

    it 'deletes the nuget-group repository' do
      expect(chef_run).to run_nexus3_api('delete_repo nuget-group')
    end

    it 'deletes the nuget-hosted repository' do
      expect(chef_run).to run_nexus3_api('delete_repo nuget-hosted')
    end

    it 'deletes the nuget.org-proxy repository' do
      expect(chef_run).to run_nexus3_api('delete_repo nuget.org-proxy')
    end

    it 'deletes the default blob store' do
      expect(chef_run).to run_nexus3_api('delete_default_blobstore')
    end
  end

  context 'creates the LDAP realm' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'enables the ldap realm' do
      expect(chef_run).to run_nexus3_api('ldap-realm').with(
        content: 'import org.sonatype.nexus.security.realm.RealmManager;' \
        'realmManager = container.lookup(RealmManager.class.getName());' \
        "realmManager.enableRealm('LdapRealm', true);"
      )
    end
  end

  context 'configures the firewall for nexus' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'opens the Nexus HTTP port' do
      expect(chef_run).to create_firewall_rule('nexus-http').with(
        command: :allow,
        dest_port: nexus_management_port,
        direction: :in
      )
    end

    it 'forces the firewall rules to be set' do
      expect(chef_run).to restart_firewall('default')
    end
  end

  context 'registers the service with consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'create a nexus metrics role' do
      expect(chef_run).to run_nexus3_api('role-metrics').with(
        content: "security.addRole('nx-metrics', 'nx-metrics', 'User with privileges to allow read access to the Nexus metrics', ['nx-metrics-all'], ['nx-anonymous'])"
      )
    end

    it 'create a consul user' do
      expect(chef_run).to run_nexus3_api('userConsul').with(
        content: "security.addUser('consul.health', 'Consul', 'Health', 'consul.health@example.com', true, 'consul.health', ['nx-metrics'])"
      )
    end

    consul_nexus_management_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
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
            "port": #{nexus_management_port},
            "tags": [
              "edgeproxyprefix-#{nexus_proxy_path}",
              "management",
              "active-management"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-management.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-management.json')
        .with_content(consul_nexus_management_config_content)
    end
  end

  context 'create roles and users' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'create a nx-developer-search role' do
      expect(chef_run).to run_nexus3_api('role-developer-search').with(
        content: "security.addRole('nx-developer-search', 'nx-developer-search'," \
        " 'User with privileges to allow searching for packages in the different repositories'," \
        " ['nx-search-read', 'nx-selectors-read'], [''])"
      )
    end
  end

  context 'adds the consul-template files for nexus' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }
    let(:node) { chef_run.node }

    it 'create a role-consul-template-local role' do
      expect(chef_run).to run_nexus3_api('role-ldap-admin').with(
        content: "security.addRole('role-consul-template-local', 'role-consul-template-local'," \
        " 'User with privileges required for Consul-Template to configure Nexus'," \
        " ['nx-ldap-all', 'nx-script-*-*'], [''])"
      )
    end

    it 'create a consul template user' do
      ldap_config_username = node['nexus3']['user']['ldap_config']['username']
      ldap_config_password = node['nexus3']['user']['ldap_config']['password']
      expect(chef_run).to run_nexus3_api('user-consul-template').with(
        content: "security.addUser('#{ldap_config_username}', 'Consul', 'Template', 'consul.template@localhost.example.com', true, '#{ldap_config_password}', ['role-consul-template-local'])"
      )
    end

    it 'creates nexus ldap script template file in the consul-template template directory' do
      ldap_config_username = node['nexus3']['user']['ldap_config']['username']
      ldap_config_password = node['nexus3']['user']['ldap_config']['password']
      nexus_instance_name = 'nexus'

      nexus_ldap_script_template_content = <<~CONF
        #!/bin/sh

        {{ if keyExists "config/environment/directory/initialized" }}

        run_nexus_script() {
          name=$1
          file=$2
          host=$3
          username=$4
          password=$5

          content=$(tr -d '\n' < $file)
          cat <<EOT > "/tmp/$name.json"
        {
          "name": "$name",
          "type": "groovy",
          "content": "$content"
        }
        EOT
          curl -v -X POST -u "$username:$password" --header "Content-Type: application/json" "$host#{nexus_proxy_path}/service/rest/v1/script" -d @"/tmp/$name.json"
          echo "Published $file as $name"

          curl -v -X POST -u "$username:$password" --header "Content-Type: text/plain" "$host#{nexus_proxy_path}/service/rest/v1/script/$name/run"
          echo "Successfully executed $name script"

          curl -v -X DELETE -u "$username:$password" "$host#{nexus_proxy_path}/service/rest/v1/script/$name"
          echo "Deleted script $name"
        }

        echo 'Write the script to configure LDAP in Nexus'
        cat <<EOT > /tmp/nexus_ldap.groovy
        import org.sonatype.nexus.ldap.persist.*;
        import org.sonatype.nexus.ldap.persist.entity.*;

        def manager = container.lookup(LdapConfigurationManager.class.name);

        manager.addLdapServerConfiguration(
          new LdapConfiguration(
            name: '{{ key "/config/environment/directory/name" }}',
            connection: new Connection(
              host: new Connection.Host(Connection.Protocol.ldap, '{{ key "config/environment/directory/endpoints/mainhost" }}', 389),
              maxIncidentsCount: 3,
              connectionRetryDelay: 300,
              connectionTimeout: 15,
              searchBase: '{{ key "/config/environment/directory/query/lookupbase" }}',
              authScheme: 'simple',
        {{ with secret "secret/environment/directory/users/bind" }}
          {{ if .Data.password }}
              systemPassword: '{{ .Data.password }}',
          {{ end }}
        {{ end }}
              systemUsername: '{{ key "/config/environment/directory/users/bindcn" }}'
            ),
            mapping: new Mapping(
              emailAddressAttribute: 'mail',
              ldapFilter: '{{ key "/config/environment/directory/filter/users/getuser" }}',
              ldapGroupsAsRoles: true,
              userBaseDn: '',
              userIdAttribute: 'sAMAccountName',
              userMemberOfAttribute: 'memberOf',
              userObjectClass: 'user',
              userPasswordAttribute: 'userPassword',
              userRealNameAttribute: 'cn',
              userSubtree: true
          )
        )
        );
        EOT

        if ( ! $(systemctl is-enabled --quiet #{nexus_instance_name}) ); then
          systemctl enable #{nexus_instance_name}

          while true; do
            if ( $(systemctl is-enabled --quiet #{nexus_instance_name}) ); then
                break
            fi

            sleep 1
          done
        fi

        if ( ! $(systemctl is-active --quiet #{nexus_instance_name}) ); then
          systemctl start #{nexus_instance_name}

          while true; do
            if ( $(systemctl is-active --quiet #{nexus_instance_name}) ); then
                break
            fi

            sleep 1
          done
        fi

        run_nexus_script setLdap /tmp/nexus_ldap.groovy 'http://localhost:#{nexus_management_port}' '#{ldap_config_username}' '#{ldap_config_password}'

        {{ else }}
        echo 'The LDAP information is not available in the Consul K-V. Will not update Nexus.'
        {{ end }}
      CONF
      expect(chef_run).to create_file('/etc/consul-template.d/templates/nexus_ldap_script.ctmpl')
        .with_content(nexus_ldap_script_template_content)
    end

    consul_template_nexus_ldap_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/nexus_ldap_script.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/tmp/nexus_ldap.sh"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "sh /tmp/nexus_ldap.sh"

        # This is the maximum amount of time to wait for the optional command to
        # return. Default is 30s.
        command_timeout = "60s"

        # Exit with an error when accessing a struct or map field/key that does not
        # exist. The default behavior will print "<no value>" when accessing a field
        # that does not exist. It is highly recommended you set this to "true" when
        # retrieving secrets from Vault.
        error_on_missing_key = false

        # This is the permission to render the file. If this option is left
        # unspecified, Consul Template will attempt to match the permissions of the
        # file that already exists at the destination path. If no file exists at that
        # path, the permissions are 0644.
        perms = 0755

        # This option backs up the previously rendered template at the destination
        # path before writing a new one. It keeps exactly one backup. This option is
        # useful for preventing accidental changes to the data without having a
        # rollback strategy.
        backup = true

        # These are the delimiters to use in the template. The default is "{{" and
        # "}}", but for some templates, it may be easier to use a different delimiter
        # that does not conflict with the output file itself.
        left_delimiter  = "{{"
        right_delimiter = "}}"

        # This is the `minimum(:maximum)` to wait before rendering a new template to
        # disk and triggering a command, separated by a colon (`:`). If the optional
        # maximum value is omitted, it is assumed to be 4x the required minimum value.
        # This is a numeric time with a unit suffix ("5s"). There is no default value.
        # The wait value for a template takes precedence over any globally-configured
        # wait.
        wait {
          min = "2s"
          max = "10s"
        }
      }
    CONF
    it 'creates nexus_ldap.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/nexus_ldap.hcl')
        .with_content(consul_template_nexus_ldap_content)
    end
  end
end
