# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: nexus_backup
#
# Copyright 2019, P. van der Velde
#

#
# DIRECTORIES
#

backup_base_path = node['backup']['base_path']
directory backup_base_path do
  action :create
  group 'root'
  mode '775'
  owner 'root'
  recursive true
end

# For some reason both these directories need to be able to be at least
# read by everybody, otherwise nexus complains that it can't create directories
# in this directory.
nexus_backup_path = node['nexus3']['backup_path']
directory nexus_backup_path do
  action :create
  group node['nexus3']['service_group']
  mode '775'
  owner node['nexus3']['service_user']
  recursive true
end

#
# NEXUS TASK
#

nexus3_api 'role-backup-local' do
  content "security.addRole('role-backup-local', 'role-backup-local'," \
    " 'User with privileges required to run backups on the local machine'," \
    " ['nx-tasks-all', 'nx-script-*-*'], [''])"
  action %i[create run delete]
end

nexus_backup_username = node['nexus3']['users']['backup']['username']
nexus_backup_password = node['nexus3']['users']['backup']['password']
nexus3_api 'user-backup' do
  action %i[create run delete]
  content "security.addUser('#{nexus_backup_username}', 'Nexus', 'Backup', 'nexus.backup@calvinverse.net', true, '#{nexus_backup_password}', ['role-backup-local'])"
end

#
# BACKUP SCRIPT
#

consul_template_config_path = node['consul_template']['config_path']
consul_template_template_path = node['consul_template']['template_path']

flag_restore = node['restore']['path']['flag']

nexus_service_name = node['nexus3']['service_name']
nexus_management_port = node['nexus3']['port']
nexus_proxy_path = node['nexus3']['proxy_path']

store_path = node['nexus3']['data_store_path']
blob_store_path = node['nexus3']['blob_store_path']

telegraf_http_listener_port = node['telegraf']['http-listener']['port']
telegraf_http_listener_path = node['telegraf']['http-listener']['path']

backup_template_script_file = 'nexus_backup.ctmpl'
file "#{consul_template_template_path}/#{backup_template_script_file}" do
  action :create
  content <<~CONF
    #!/bin/bash

    # The restore service is: {{ file "#{flag_restore}" }}
    {{ if keyExists "config/services/consul/domain" }}
    {{ if keyExists "config/services/consul/datacenter" }}
    {{ if keyExists "config/services/backups/protocols/write/host" }}

    if [ "$(cat #{flag_restore})" = "#{node['restore']['status']['done']}" ]; then

        echo 'Write the script to configure backup in Nexus'
        cat <<EOT > /tmp/nexus_backup.groovy
    import groovy.time.TimeCategory;
    import java.nio.file.attribute.BasicFileAttributes;
    import java.nio.file.Files;
    import java.nio.file.FileSystems;
    import java.nio.file.FileVisitResult;
    import java.nio.file.Path;
    import java.nio.file.PathMatcher;
    import java.nio.file.Paths;
    import java.nio.file.SimpleFileVisitor;
    import java.time.format.DateTimeFormatter;
    import java.time.LocalDateTime;
    import java.util.concurrent.TimeUnit;
    import java.util.zip.ZipEntry;
    import java.util.zip.ZipOutputStream;
    import org.apache.commons.io.FileUtils;
    import org.sonatype.nexus.orient.freeze.DatabaseFreezeService;
    import org.sonatype.nexus.orient.freeze.DatabaseFrozenStateManager;
    import org.sonatype.nexus.orient.freeze.FreezeRequest;
    import org.sonatype.nexus.orient.freeze.FreezeRequest.InitiatorType;
    import org.sonatype.nexus.scheduling.schedule.Schedule;
    import org.sonatype.nexus.scheduling.TaskConfiguration;
    import org.sonatype.nexus.scheduling.TaskInfo;
    import org.sonatype.nexus.scheduling.TaskScheduler;

    initiator_id = 'Backup script database freeze';

    class BackupFailureException extends Exception {
        String message;

        BackupFailureException(String message) {
            this.message = message;
        };

        String toString() {
            this.message;
        };
    };

    def createDirectory(File directory) {
        if (!directory.exists()) {
            def dirParent = directory.getParentFile();
            if (!dirParent.canWrite()) {
                log.error('Not allowed to write to ' + dirParent.getAbsolutePath());
                return false;
            };

            log.info('Creating: ' + directory.getAbsolutePath());
            boolean createWasSuccessful = directory.mkdir();
            if (!createWasSuccessful) {
                log.error('Failed to create directory: ' + directory.getAbsolutePath());
                return false;
            };
        };

        return true;
    };

    def freeze() {
        freezer = container.lookup(DatabaseFreezeService.class.name);
        freezerManager = container.lookup(DatabaseFrozenStateManager.class.name);

        FreezeRequest frozenState = freezerManager.state.find {
            it.initiatorType == InitiatorType.SYSTEM && it.initiatorId == initiator_id
        };

        if (!frozenState) {
            freezer.requestFreeze(InitiatorType.SYSTEM, initiator_id);
        };
    };

    def runNexusDbBackup(File dirDatabaseBackup) {
        log.info('Create a temporary task to backup nexus db in ' + dirDatabaseBackup.getAbsolutePath());

        TaskScheduler taskScheduler = container.lookup(TaskScheduler.class.getName());
        TaskConfiguration tempBackupTaskConfiguration = taskScheduler.createTaskConfigurationInstance('db.backup');
        tempBackupTaskConfiguration.setName('Temporary db.backup task');
        tempBackupTaskConfiguration.setString('location', dirDatabaseBackup.getAbsolutePath());
        Schedule schedule = taskScheduler.scheduleFactory.manual();
        TaskInfo tempBackupTask = taskScheduler.scheduleTask(tempBackupTaskConfiguration, schedule);

        try {
            log.info('Run the temporary db backup task');
            tempBackupTask.runNow();

            log.info('Wait for temporary db backup task to finish');
            while (tempBackupTask.currentState.state != TaskInfo.State.WAITING) {
                TimeUnit.SECONDS.sleep(1);
            };

            return true;
        } catch (Exception e) {
            log.error('error running task with id ' + tempBackupTaskConfiguration.getId(), e);
            return false;
        } finally {
            log.info('Remove temporary task');
            tempBackupTask.remove();
        };
    };

    def runExternalProcess(List<String> commands) {

        def sout = new StringBuilder();
        def serr = new StringBuilder();
        def process = commands.execute();
        process.consumeProcessOutput(sout, serr);
        process.waitForProcessOutput();

        log.info(sout.toString());
        if (process.exitValue() != 0) {
            log.error(serr.toString());
            log.error('Process failed with exitcode: ' + process.exitValue());
            return false;
        };

        return true;
    };

    def sendMetric(String metricsValuePair, String tags) {
        def metricsServerUrl = 'http://127.0.0.1:#{telegraf_http_listener_port}#{telegraf_http_listener_path}';
        long unixTime = new Date().getTime() * 1000000L;
        String message = 'backup,service=nexus';
        if (tags?.trim()) {
            message = message + ',' + tags;
        };

        message = message + ' ' + metricsValuePair + ' ' + unixTime;

        log.info('Sending metrics message with: ' + message);
        if (!runExternalProcess(['curl', '--request', 'POST', '--silent', '--show-error', '--fail', '--retry', '10', '--retry-delay', '10', '--data-binary', message, metricsServerUrl])) {
            log.error('failed to send metrics to ' + metricsServerUrl + ' with message ' + message);
        };
    };

    def unfreeze() {
        freezer = container.lookup(DatabaseFreezeService.class.name);
        freezerManager = container.lookup(DatabaseFrozenStateManager.class.name);

        if (freezer.isFrozen()) {
            freezerManager.state.findAll {
                it.initiatorType == InitiatorType.SYSTEM && it.initiatorId == initiator_id
            }.each { FreezeRequest frozenState ->
                freezer.releaseRequest(frozenState);
            };
        };
    };

    def zip(File zipFileName, File databaseDirectory, File blobBaseDirectory, List<File> blobDirectories) {
        log.info('Run tar on the ' + databaseDirectory.getAbsolutePath() + ' directory');
        if (!runExternalProcess(['tar', '--create', '--file=' + zipFileName.getAbsolutePath(), '--directory', databaseDirectory.getAbsolutePath(), '.'])) {
            return false;
        };

        def result = true;
        blobDirectories.each {
            def relativeBlobPath = './' + blobBaseDirectory.toPath().relativize( it.toPath() ).toFile();
            result = result && runExternalProcess(['tar', '--exclude=lost+found', '--append', '--file=' + zipFileName.getAbsolutePath(), '--directory', blobBaseDirectory.getAbsolutePath(), relativeBlobPath]);
        };

        return result;
    };

    def startTime = new Date();

    def dirNexusData = new File('#{store_path}');
    def dirNexusBlobData = new File('#{blob_store_path}');
    def dirNexusBackup = new File('#{nexus_backup_path}');

    backupDateString = LocalDateTime.now().format(DateTimeFormatter.ofPattern('YYYY-MM-dd-HH-mm-ss'));
    def dirBackupBase = new File(dirNexusBackup, '/backup-' + backupDateString);

    def wasBackupSuccessful = false;
    def backupFileSize = 0L;
    try {
        try {
            log.info('Backup directory is ' + dirBackupBase.getAbsolutePath());
            if (!createDirectory(dirBackupBase)) {
                return;
            };

            try {
                def dirDatabaseBackup = new File(dirBackupBase, 'db');
                if (!createDirectory(dirDatabaseBackup)) {
                    return;
                };

                if (!runNexusDbBackup(dirDatabaseBackup)){
                    return;
                };

                freeze();

                def backupTarPath = new File(dirNexusBackup, '/nexus-' + backupDateString + '.tar');
                def backupTarGzPath = new File(backupTarPath.getAbsolutePath());
                try {
                    log.info('Tar gz the backup files to ' + backupTarPath.getAbsolutePath());

                    def blobDirectories = [
                        new File(dirNexusBlobData, 'artefacts'),
                        new File(dirNexusBlobData, 'docker'),
                        new File(dirNexusBlobData, 'npm'),
                        new File(dirNexusBlobData, 'nuget'),
                    ];
                    if (!zip(backupTarPath, dirBackupBase, dirNexusData, blobDirectories)) {
                        return;
                    };

                    backupServerUrl = 'http://{{ keyOrDefault "config/services/backups/protocols/write/host" "unknown" }}.service.{{ keyOrDefault "config/services/consul/domain" "unknown" }}/uploads/{{ keyOrDefault "config/services/consul/datacenter" "unknown" }}/nexus/';
                    log.info('Send backup file ' + backupTarGzPath.getAbsolutePath() + ' to ' + backupServerUrl);
                    if (!runExternalProcess(['curl', '--request', 'PUT', '--silent', '--show-error', '--fail', '--retry', '10', '--retry-delay', '10', '--upload-file', backupTarGzPath.getAbsolutePath(), backupServerUrl + backupTarGzPath.getName()])) {
                        return;
                    };

                    backupFileSize = backupTarGzPath.length();
                    wasBackupSuccessful = true;
                } finally {
                    unfreeze();

                    if (backupTarPath.exists()) {
                        def deleteWasSuccessful = backupTarPath.delete();
                        if (!deleteWasSuccessful) {
                            log.warn('Failed to delete the backup tar file: ' + backupTarPath.getAbsolutePath());
                        };
                    };

                    if (backupTarGzPath.exists()) {
                        def deleteWasSuccessful = backupTarGzPath.delete();
                        if (!deleteWasSuccessful) {
                            log.warn('Failed to delete the backup tar.gz file: ' + backupTarGzPath.getAbsolutePath());
                        };
                    };
                };
            } finally {
                if (dirBackupBase.exists()) {
                    def deleteWasSuccessful = dirBackupBase.deleteDir();
                    if (!deleteWasSuccessful) {
                        log.warn('Failed to delete the backup directory: ' + dirBackupBase.getAbsolutePath());
                    };
                };
            };
        } catch (Exception e) {
            log.error(e.toString());
            wasBackupSuccessful = false;
        };
    } finally {
        int successAsInt = (wasBackupSuccessful) ? 1 : 0;

        def endTime = new Date();
        def duration = TimeCategory.minus(endTime, startTime);

        log.info('Send duration metrics');
        sendMetric('duration=' + duration.toMilliseconds() + ',result=' + successAsInt + ',size=' + backupFileSize, 'success=' + wasBackupSuccessful);
        log.info('Making backup took: ' + duration.toMilliseconds() + ' ms');
    };

    if (!wasBackupSuccessful) {
        throw new BackupFailureException('Backup task failed to complete.');
    };
    EOT

        if ( ! $(systemctl is-enabled --quiet #{nexus_service_name}) ); then
            systemctl enable #{nexus_service_name}

            while true; do
                if ( $(systemctl is-enabled --quiet #{nexus_service_name}) ); then
                    break
                fi

                sleep 1
            done
        fi

        if ( ! $(systemctl is-active --quiet #{nexus_service_name}) ); then
            systemctl start #{nexus_service_name}

            while true; do
                if ( $(systemctl is-active --quiet #{nexus_service_name}) ); then
                    break
                fi

                sleep 1
            done
        fi

        source #{node['nexus3']['script']['path']['nexus_utilities']}
        create_nexus_task backup /tmp/nexus_backup.groovy 'http://localhost:#{nexus_management_port}' '#{nexus_proxy_path}' '#{nexus_backup_username}' '#{nexus_backup_password}' '0 0 13 * * ?'
    fi

    {{ else }}
    echo 'The backup information is not available in the Consul K-V. Will not update Nexus.'
    {{ end }}
    {{ else }}
    echo 'The backup information is not available in the Consul K-V. Will not update Nexus.'
    {{ end }}
    {{ else }}
    echo 'The backup information is not available in the Consul K-V. Will not update Nexus.'
    {{ end }}
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

backup_script_file = '/tmp/backup.sh'
file "#{consul_template_config_path}/cron_backup.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{backup_template_script_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{backup_script_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "bash #{backup_script_file}"

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
