# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: nexus
#
# Copyright 2017, P. van der Velde
#

# Configure the service user under which consul will be run
poise_service_user node['nexus3']['service_user'] do
  group node['nexus3']['service_group']
end

#
# CONFIGURE THE FILE SYSTEM
#

store_path = node['nexus3']['blob_store_path']
directory store_path do
  action :create
  recursive true
end

scratch_blob_store_path = node['nexus3']['scratch_blob_store_path']
directory scratch_blob_store_path do
  action :create
  group node['nexus3']['service_group']
  mode '777'
  owner node['nexus3']['service_user']
end

#
# ALLOW NEXUS THROUGH THE FIREWALL
#

# do this before installing nexus because all the api commands in this cookbook hit the nexus3 HTTP endpoint
# and if the firewall is blocking the port ...
nexus_management_port = node['nexus3']['port']
firewall_rule 'nexus-http' do
  command :allow
  description 'Allow Nexus HTTP traffic'
  dest_port nexus_management_port
  direction :in
end

# Force the firewall settings so that we can actually communicate with nexus
firewall 'default' do
  action :restart
end

#
# INSTALL NEXUS
#

nexus_instance_name = node['nexus3']['instance_name']
nexus3 nexus_instance_name do
  action :install
  group node['nexus3']['service_group']
  user node['nexus3']['service_user']
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
# ENABLE LDAP TOKEN REALM
#

nexus3_api 'ldap-realm' do
  content 'import org.sonatype.nexus.security.realm.RealmManager;' \
  'realmManager = container.lookup(RealmManager.class.getName());' \
  "realmManager.enableRealm('LdapRealm', true);"
  action %i[create run delete]
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

nexus_proxy_path = node['nexus3']['proxy_path']
file '/etc/consul/conf.d/nexus-management.json' do
  action :create
  content <<~JSON
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
          "enable_tag_override": false,
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
end

#
# CREATE ADDITIONAL ROLES AND USERS
#

# Create the role which is used by the developers to search repositories
nexus3_api 'role-developer-search' do
  content "security.addRole('nx-developer-search', 'nx-developer-search'," \
    " 'User with privileges to allow searching for packages in the different repositories'," \
    " ['nx-search-read', 'nx-selectors-read'], [''])"
  action :run
end

nexus3_api 'role-consul-template-local' do
  content "security.addRole('role-consul-template-local', 'role-consul-template-local'," \
    " 'User with privileges required for Consul-Template to configure Nexus'," \
    " ['nx-ldap-all', 'nx-script-*-*'], [''])"
  action :run
end

ldap_config_username = node['nexus3']['user']['ldap_config']['username']
ldap_config_password = node['nexus3']['user']['ldap_config']['password']
nexus3_api 'user-consul-template' do
  action :run
  content "security.addUser('#{ldap_config_username}', 'Consul', 'Template', 'consul.template@localhost.example.com', true, '#{ldap_config_password}', ['role-consul-template-local'])"
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
# CONSUL-TEMPLATE
#

consul_template_config_path = node['consul_template']['config_path']
consul_template_template_path = node['consul_template']['template_path']

nexus_ldap_script_template_file = node['nexus3']['consul_template_ldap_script_file']
file "#{consul_template_template_path}/#{nexus_ldap_script_template_file}" do
  action :create
  content <<~CONF
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
    import org.sonatype.nexus.security.SecuritySystem;

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
          userPasswordAttribute: '',
          userRealNameAttribute: 'cn',
          userSubtree: true
        )
      )
    );

    def role = security.addRole(
      '{{ key "config/environment/directory/query/groups/artefacts/administrators" }}',
      'ldap-administrators',
      'Mapping {{ key "config/environment/directory/query/groups/artefacts/administrators" }} to nx-admin for {{ key "/config/environment/directory/name" }}',
      [],
      ['nx-admin']);

    security.securitySystem.deleteUser('admin', 'default');
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
  mode '755'
end

nexus_ldap_script_file = node['nexus3']['script_ldap_file']
file "#{consul_template_config_path}/nexus_ldap.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{nexus_ldap_script_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{nexus_ldap_script_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "sh #{nexus_ldap_script_file}"

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
  HCL
  mode '755'
end
