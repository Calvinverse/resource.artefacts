# frozen_string_literal: true

require 'spec_helper'

describe 'resource_artefacts::nexus_restore' do
  context 'creates the file system directories' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the restore base path at /srv/backup/scratch/restore' do
      expect(chef_run).to create_directory('/srv/backup/scratch/restore').with(
        group: 'root',
        mode: '770',
        owner: 'root'
      )
    end

    it 'creates the restore base path at /usr/local/restore' do
      expect(chef_run).to create_directory('/usr/local/restore').with(
        group: 'root',
        mode: '770',
        owner: 'root'
      )
    end
  end

  context 'creates the systemd service' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    restore_run_script_content = <<~SH
      #!/bin/sh

      echo 'This script does nothing. It should be replaced when the machine connects to consul.'
    SH
    it 'creates the /usr/local/restore/run_restore.sh file' do
      expect(chef_run).to create_file('/usr/local/restore/run_restore.sh')
        .with_content(restore_run_script_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end

    fork_run_script_content = <<~SCRIPT
      #!/bin/sh

      ((/bin/bash /usr/local/restore/run_restore.sh) & echo $! > /var/run/restore.pid &)
    SCRIPT
    it 'creates the /usr/local/restore/fork_restore_script.sh file' do
      expect(chef_run).to create_file('/usr/local/restore/fork_restore_script.sh')
        .with_content(fork_run_script_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end

    it 'creates the restore systemd service' do
      expect(chef_run).to create_systemd_service('restore').with(
        action: [:create],
        unit_after: %w[network-online.target],
        unit_description: 'Nexus restore service',
        install_wanted_by: %w[network-online.target],
        service_exec_start: '/bin/bash /usr/local/restore/fork_restore_script.sh',
        service_pid_file: '/var/run/restore.pid',
        service_type: 'forking',
        service_user: 'root'
      )
    end

    it 'disables the service' do
      expect(chef_run).to disable_service('restore')
    end
  end

  context 'creates the consul-template files' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    flag_restore = '/var/log/restore.flag'
    restore_service_name = 'restore'

    service_start_script_content = <<~SH
      #!/bin/sh

      if [ "$(cat #{flag_restore})" = "Waiting" ]; then
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
    it 'creates the /usr/local/restore/start_restore_service.sh file' do
      expect(chef_run).to create_file('/usr/local/restore/start_restore_service.sh')
        .with_content(service_start_script_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end

    nexus_start_script_content = <<~SH
      #!/bin/sh

      if ( ! $(systemctl is-enabled --quiet nexus) ); then
        systemctl enable nexus

        while true; do
          if ( (systemctl is-enabled --quiet nexus) ); then
              break
          fi

          sleep 1
        done
      fi

      if ( ! (systemctl is-active --quiet nexus) ); then
        systemctl start nexus

        while true; do
          if ( (systemctl is-active --quiet nexus) ); then
              break
          fi

          sleep 1
        done

        # Wait for nexus to come online. We will loop around 100 times and wait 10 seconds each time curl fails
        for i in {1..100}; do
          curl --request GET --header "Authorization: Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo" --silent --show-error --fail http://localhost:8081/artefacts/service/rest/v1/status
          if [ $? -ne 0 ]; then
            sleep 10

            continue
          fi

          break
        done
      fi
    SH
    it 'creates the /usr/local/restore/start_nexus_service.sh file' do
      expect(chef_run).to create_file('/usr/local/restore/start_nexus_service.sh')
        .with_content(nexus_start_script_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end

    context 'adds the consul-template files for the jenkins start script' do
      let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

      restore_start_script_template_content = <<~CONF
        #!/bin/bash

        startTime=$( date +%s%N )

        # In bash 0 is true and any non-zero value is false
        declare -i successAsInt
        successAsInt=1

        declare -i backupFileSize
        backupFileSize=0

        restoreBaseDir='/srv/backup/scratch/restore'

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

            metricsServerUrl='http://127.0.0.1:9090/telegraf'
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


        if [ "$(cat #{flag_restore})" = "Waiting" ]; then

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
            rm -rf /home/nexus/db/component
            rm -rf /home/nexus/db/config
            rm -rf /home/nexus/db/security

            # Move the database files
            databaseRestorePath='/home/nexus/restore-from-backup'

            echo "Moving database files from $restoreBaseDir/db to $databaseRestorePath ..."

            mkdir -p $databaseRestorePath
            find "$restoreBaseDir/db/" -name '*.bak' -exec mv '{}' $databaseRestorePath \\;

            # Move the blob files
            blobStorePath='/srv/nexus/blob'

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

            source /usr/local/restore/start_nexus_service.sh

            # In bash 0 is true and any non-zero value is false
            successAsInt=0
        fi

        # Allow all the other work to be done by updating the restore file
        echo "Done" > #{flag_restore}

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
      CONF
      it 'creates restore start script template file in the consul-template template directory' do
        expect(chef_run).to create_file('/etc/consul-template.d/templates/restore_run_script.ctmpl')
          .with_content(restore_start_script_template_content)
          .with(
            group: 'root',
            owner: 'root',
            mode: '0550'
          )
      end

      consul_template_restore_start_script_content = <<~CONF
        # This block defines the configuration for a template. Unlike other blocks,
        # this block may be specified multiple times to configure multiple templates.
        # It is also possible to configure templates via the CLI directly.
        template {
          # This is the source file on disk to use as the input template. This is often
          # called the "Consul Template template". This option is required if not using
          # the `contents` option.
          source = "/etc/consul-template.d/templates/restore_run_script.ctmpl"

          # This is the destination path on disk where the source template will render.
          # If the parent directories do not exist, Consul Template will attempt to
          # create them, unless create_dest_dirs is false.
          destination = "/usr/local/restore/run_restore.sh"

          # This options tells Consul Template to create the parent directories of the
          # destination path if they do not exist. The default value is true.
          create_dest_dirs = false

          # This is the optional command to run when the template is rendered. The
          # command will only run if the resulting template changes. The command must
          # return within 30s (configurable), and it must have a successful exit code.
          # Consul Template is not a replacement for a process monitor or init system.
          command = "sh /usr/local/restore/start_restore_service.sh"

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
      CONF
      it 'creates restore_service_script.hcl in the consul-template template directory' do
        expect(chef_run).to create_file('/etc/consul-template.d/conf/restore_service_script.hcl')
          .with_content(consul_template_restore_start_script_content)
          .with(
            group: 'root',
            owner: 'root',
            mode: '0550'
          )
      end
    end
  end
end
