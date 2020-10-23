# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: nexus_api_scripts
#
# Copyright 2019, P. van der Velde
#

#
# DIRECTORIES
#

script_path = node['nexus3']['scripts']
directory script_path do
  action :create
  group 'root'
  mode '555'
  owner 'root'
end

#
# SCRIPTS
#

cookbook_file node['nexus3']['script']['path']['nexus_utilities'] do
  action :create
  group 'root'
  mode '0555'
  owner 'root'
  source 'nexus_utilities.sh'
end

#
# NEXUS SCRIPTS
#

# Note: We only want to create this script so that we can call it later
nexus3_api 'create_task' do
  action %i[create]
  content <<~GROOVY
    // Freely adapted from
    // https://github.com/savoirfairelinux/ansible-nexus3-oss/blob/master/files/groovy/create_task.groovy
    import org.sonatype.nexus.scheduling.TaskConfiguration;
    import org.sonatype.nexus.scheduling.TaskInfo;
    import org.sonatype.nexus.scheduling.TaskScheduler;
    import org.sonatype.nexus.scheduling.schedule.Schedule;

    import groovy.json.JsonSlurper;

    def params = new JsonSlurper().parseText(args);

    TaskScheduler taskScheduler = container.lookup(TaskScheduler.class.getName());
    TaskInfo existingTask = taskScheduler.listsTasks().find { TaskInfo taskInfo ->
        taskInfo.getName() == params.name;
    }
    if (existingTask && !existingTask.remove()) {
        throw new RuntimeException("Could not remove currently running task: " + params.name);
    }

    TaskConfiguration taskConfiguration = taskScheduler.createTaskConfigurationInstance('script');
    taskConfiguration.setName(params.name);
    taskConfiguration.setString('source', params.source);
    taskConfiguration.setString('language', 'groovy');
    Schedule schedule = taskScheduler.scheduleFactory.cron(new Date(), params.crontab);

    taskScheduler.scheduleTask(taskConfiguration, schedule);
  GROOVY
end
