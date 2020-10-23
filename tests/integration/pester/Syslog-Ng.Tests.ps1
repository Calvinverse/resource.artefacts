Describe 'On the system' {
    Context 'system logs' {

        # There should be test here but in order to test whether the rabbitmq target is generated
        # we need an active Vault instance that can generate RabbitMQ log-in credentials, and that
        # requires an active RabbitMQ instance. Creating a Vault instance for testing is easy,
        # initializing a Vault instance for testing is harder, creating and initializing a
        # RabbitMQ instance for testing is hard. So for now there is no easy test for this :(
        It 'with the RabbitMQ target defined in /etc/syslog-ng/conf.d/syslog-ng-rabbitmq.conf' {
            # '/etc/syslog-ng/conf.d/syslog-ng-rabbitmq.conf' | Should Exist
        }
    }
}
