# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: nexus_restore
#
# Copyright 2019, P. van der Velde
#

restore_user = 'root'
restore_group = 'root'

#
# FLAG FILES
#

flag_restore = node['restore']['path']['flag']
file flag_restore do
  action :create
  content <<~TXT
    #{node['restore']['status']['waiting']}
  TXT
  group restore_group
  mode '0770'
  owner restore_user
end

#
#  DIRECTORIES
#

nexus_restore_path = node['nexus3']['restore_path']
directory nexus_restore_path do
  action :create
  group restore_group
  mode '770'
  owner restore_user
  recursive true
end

directory '/usr/local/restore' do
  action :create
  group restore_group
  mode '770'
  owner restore_user
  recursive true
end

#
# SYSTEMD SERVICE
#

run_restore_script = '/usr/local/restore/run_restore.sh'
file run_restore_script do
  action :create
  content <<~SH
    #!/bin/sh

    echo 'This script does nothing. It should be replaced when the machine connects to consul.'
  SH
  group restore_group
  mode '0550'
  owner restore_user
end

pid_file = '/var/run/restore.pid'
fork_restore_script = '/usr/local/restore/fork_restore_script.sh'
file fork_restore_script do
  action :create
  content <<~SCRIPT
    #!/bin/sh

    ((/bin/bash #{run_restore_script}) & echo $! > #{pid_file} &)
  SCRIPT
  group restore_group
  mode '0550'
  owner restore_user
end

restore_service_name = node['restore']['service_name']
systemd_service restore_service_name do
  action :create
  install do
    wanted_by %w[network-online.target]
  end
  service do
    exec_start "/bin/bash #{fork_restore_script}"
    pid_file pid_file
    type 'forking'
    user restore_user
  end
  unit do
    after %w[network-online.target]
    description 'Nexus restore service'
    requires %w[network-online.target]
  end
end

service restore_service_name do
  action :disable
end

# Note because it's a one-shot service that remains we don't want to wait for it
restore_start_script = '/usr/local/restore/start_restore_service.sh'
file restore_start_script do
  action :create
  content <<~SH
    #!/bin/sh

    if [ "$(cat #{flag_restore})" = "#{node['restore']['status']['waiting']}" ]; then
      if ( ! $(systemctl is-enabled --quiet #{restore_service_name}) ); then
        systemctl enable #{restore_service_name}

        while true; do
          if ( (systemctl is-enabled --quiet #{restore_service_name}) ); then
              break
          fi

          sleep 1
        done
      fi

      if ( ! (systemctl is-active --quiet #{restore_service_name}) ); then
        systemctl start --no-block #{restore_service_name}
      else
        systemctl restart --no-block #{restore_service_name}
      fi
    else
      echo 'Restore service ran previously. Will not run again'
    fi
  SH
  group restore_group
  mode '0550'
  owner restore_user
end

nexus_management_port = node['nexus3']['port']
nexus_proxy_path = node['nexus3']['proxy_path']

nexus_service_name = node['nexus3']['service_name']
nexus_start_script = '/usr/local/restore/start_nexus_service.sh'
file nexus_start_script do
  action :create
  content <<~SH
    #!/bin/sh

    if ( ! $(systemctl is-enabled --quiet #{nexus_service_name}) ); then
      systemctl enable #{nexus_service_name}

      while true; do
        if ( (systemctl is-enabled --quiet #{nexus_service_name}) ); then
            break
        fi

        sleep 1
      done
    fi

    if ( ! (systemctl is-active --quiet #{nexus_service_name}) ); then
      systemctl start #{nexus_service_name}

      while true; do
        if ( (systemctl is-active --quiet #{nexus_service_name}) ); then
            break
        fi

        sleep 1
      done

      # Wait for nexus to come online. We will loop around 100 times and wait 10 seconds each time curl fails
      for i in {1..100}; do
        curl --request GET --header "Authorization: Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo" --silent --show-error --fail http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/rest/v1/status
        if [ $? -ne 0 ]; then
          sleep 10

          continue
        fi

        break
      done
    fi
  SH
  group restore_group
  mode '0550'
  owner restore_user
end

#
# CONSUL-TEMPLATE
#

consul_template_config_path = node['consul_template']['config_path']
consul_template_template_path = node['consul_template']['template_path']

telegraf_http_listener_port = node['telegraf']['http-listener']['port']
telegraf_http_listener_path = node['telegraf']['http-listener']['path']

# On boot see if we have been booted before:
# - If so then don't do anything
# - If not then we go search for a backup to restore
#
# - Find the most recent backup for our environment
# - Download the backup
# - Untar it
# - Move the files to the correct locations
#   - Blobs go into the blob store directories
#   - Nexus database config files
#     - Delete the existing database files from $data-dir/db -> [component, config, security]
#     - Copy the backups to $data-dir/restore-from-backup
# - restart nexus
# - wait for it to finish the restore

restore_run_script_template_file = 'restore_run_script.ctmpl'
file "#{consul_template_template_path}/#{restore_run_script_template_file}" do
  content <<~TXT
    #!/bin/bash

    startTime=$( date +%s%N )

    # In bash 0 is true and any non-zero value is false
    declare -i successAsInt
    successAsInt=1

    declare -i backupFileSize
    backupFileSize=0

    restoreBaseDir='#{nexus_restore_path}'

    function cleanup {
        if [ $? -ne 0 ]; then
            echo "The last command failed with exit code $?. Starting clean-up"
        fi

        # We don't care about errors anymore. We're in the cleanup function
        set +e

        echo 'clean up'
        rm -rf $restoreBaseDir/*

        endTime=$( date +%s%N )
        echo "End time is: $endTime"

        durationInMilliseconds=$( echo "($endTime - $startTime) / 1000000" | bc )
        echo "Duration in milliseconds is: $durationInMilliseconds"

        declare -i wasRestoreSuccessfulAsInt
        wasRestoreSuccessfulAsInt=0
        wasRestoreSuccessful='false'
        if (( $successAsInt == 0)); then
            wasRestoreSuccessful='true'
            wasRestoreSuccessfulAsInt=1
        fi

        values="duration=$durationInMilliseconds,result=$wasRestoreSuccessfulAsInt,size=$backupFileSize"
        tags="success=$wasRestoreSuccessful"
        sendMetric $values $tags
    }

    function sendMetric {
        metricsValuePair=$1
        tags=$2

        metricsServerUrl='http://127.0.0.1:#{telegraf_http_listener_port}#{telegraf_http_listener_path}'
        unixTime=$( date +%s%N )
        message='restore,service=nexus'
        if [[ ! -z "$tags" ]]; then
            message="$message,$tags"
        fi

        message="$message $metricsValuePair $unixTime"

        echo "Sending metrics message with: $message to $metricsServerUrl"
        curl --request POST --silent --show-error --fail --data-binary "$message" "$metricsServerUrl"
    }

    {{ if keyExists "config/services/consul/domain" }}
    {{ if keyExists "config/services/backups/protocols/read/host" }}
    {{ if keyExists "config/services/nexus/restore/datacenter" }}
    {{ if keyExists "config/services/nexus/restore/environment" }}


    if [ "$(cat #{flag_restore})" = "#{node['restore']['status']['waiting']}" ]; then

        # Stop executing the script if any command returns a non-zero code
        set -e

        # If there is an error execute cleanup and then exit
        trap cleanup EXIT

        backupServerUrl='http://{{ key "config/services/backups/protocols/read/host" }}.service.{{ key "config/services/nexus/restore/datacenter" }}.{{ key "config/services/consul/domain" }}/{{ key "config/services/nexus/restore/environment" }}/nexus/'

        echo "Search for vailable backup files on $backupServerUrl"
        availableBackups=$(curl --request GET $backupServerUrl --silent --show-error --fail --retry 10 --retry-delay 10 --header 'Accept: application/json')
        if [ $? -ne 0 ]; then
            echo 'Failed to connect to the backup site'
            exit 1
        fi

        if [[ $availableBackups = null ]]; then
            echo 'No backups available'
            exit 0
        fi

        selectedBackupWithQuotes=$(jq 'sort_by(.ModTime) | .[-1].Name ' <<< "$availableBackups")
        selectedBackupFileName=$(sed -e 's/^"//' -e 's/"$//' <<<"$selectedBackupWithQuotes")

        backupFileUrl="$backupServerUrl$selectedBackupFileName"
        echo "Downloading backup file from $backupFileUrl ..."

        backupTarFile="$restoreBaseDir/$selectedBackupFileName"
        curl --request GET $backupFileUrl --silent --show-error --fail --output $backupTarFile
        if [ $? -ne 0 ]; then
            echo "Failed to download the backup file from $backupFileUrl"
            exit 1
        fi

        backupFileSize=$(stat -c%s "$backupTarFile")

        echo "Extracting tar ball $backupTarFile ..."
        tar --extract --overwrite --overwrite-dir --preserve-permissions --file=$backupTarFile --directory $restoreBaseDir
        if [ $? -ne 0 ]; then
            echo "Failed to extract the tar ball from $backupTarFile"
            exit 1
        fi

        # Remove the existing database files
        rm -rf #{node['nexus3']['data']}/db/component
        rm -rf #{node['nexus3']['data']}/db/config
        rm -rf #{node['nexus3']['data']}/db/security

        # Move the database files
        databaseRestorePath='#{node['nexus3']['data']}/restore-from-backup'

        echo "Moving database files from $restoreBaseDir/db to $databaseRestorePath ..."

        mkdir -p $databaseRestorePath
        find "$restoreBaseDir/db/" -name '*.bak' -exec mv '{}' $databaseRestorePath \\;

        # Move the blob files
        blobStorePath='#{node['nexus3']['blob_store_path']}'

        for d in $restoreBaseDir/blob/*/
        do
            dirName="${d%/}"     # strip trailing slash
            dirName="${dirName##*/}"   # strip path and leading slash

            blobTarget="$blobStorePath/$dirName"
            echo "Deleting existing files in $blobTarget"

            # Clear out the target directory
            rm -rf $blobTarget/*

            # Move all the files to the target directory
            echo "moving $d to $blobTarget"
            mv $d/* $blobTarget/

            chown --recursive nexus:nexus $blobTarget
        done

        # We don't care about errors here. We're about to get errors while curl fails to reach nexus
        set +e

        source #{nexus_start_script}

        # In bash 0 is true and any non-zero value is false
        successAsInt=0
    fi

    # Allow all the other work to be done by updating the restore file
    echo "#{node['restore']['status']['done']}" > #{flag_restore}

    # Have been run, disable our current service
    systemctl disable #{restore_service_name}

    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Nexus."
    {{ end }}
    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Nexus."
    {{ end }}
    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Nexus."
    {{ end }}
    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Nexus."
    {{ end }}
  TXT
  action :create
  group 'root'
  mode '0550'
  owner 'root'
end

file "#{consul_template_config_path}/restore_service_script.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{restore_run_script_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{run_restore_script}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "sh #{restore_start_script}"

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
      perms = 0550

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
  group 'root'
  mode '0550'
  owner 'root'
end
