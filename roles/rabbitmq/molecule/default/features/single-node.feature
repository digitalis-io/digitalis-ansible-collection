Feature: A single-node RabbitMQ instance managed by the rabbitmq role

  Background:
    Given the rabbitmq role has been applied to one host

  Scenario: The broker is running
    Then rabbitmq-server is enabled and running
    And the AMQP port is reachable
    And the management API is reachable and returns valid data

  Scenario: Queue and dead-letter queue are created
    Then the queue test001 exists on the default vhost
    And the queue test001 has x-dead-letter-routing-key set to test001-dlq
    And the dead-letter queue test001-dlq exists on the default vhost

  Scenario: Backup job is configured safely
    Then the cron file for the backup exists and is root-only
    And the backup script exists and does not contain the admin password
    And the rabbitmqadmin credentials file is root-only
    And the backup directory exists and is root-only
