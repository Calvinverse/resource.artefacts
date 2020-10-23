# frozen_string_literal: true

require 'spec_helper'

describe 'resource_artefacts::nexus_api_scripts' do
  context 'creates the file system directories' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the nexus script path at /etc/nexus' do
      expect(chef_run).to create_directory('/etc/nexus').with(
        group: 'root',
        mode: '555',
        owner: 'root'
      )
    end
  end

  context 'creates the script files' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates nexus_utilities.sh in the Nexus etc directory' do
      expect(chef_run).to create_cookbook_file('/etc/nexus/nexus_utilities.sh')
        .with(
          group: 'root',
          owner: 'root',
          mode: '0555',
          source: 'nexus_utilities.sh'
        )
    end

    create_task_content = <<~GROOVY
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
    it 'uploads the create_task script to Nexus' do
      expect(chef_run).to create_nexus3_api('create_task').with(
        content: create_task_content
      )
    end
  end
end
