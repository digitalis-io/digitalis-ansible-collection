# One node, local pgBackRest repository, HAProxy, pgAudit and two roles.
# The scenarios run in order against one container, because they read the
# state that the converge step created; none of them changes it, so there is
# nothing to clean up (Molecule destroys the container afterwards).
# Applying the role a second time is Molecule's idempotence step, which fails
# the run when any task reports a change.
Feature: A single node PostgreSQL cluster managed by Patroni

  Background:
    Given the postgres_cluster role has been applied to one host

  Scenario: The cluster components run as services
    Then Patroni, ZooKeeper and HAProxy are enabled and running
    And the packaged PostgreSQL service is not enabled

  Scenario: The node leads the cluster
    Then the Patroni API reports the node as the primary
    And patronictl lists exactly one leader running the requested PostgreSQL version
    And the requested PostgreSQL setting is active

  Scenario: ZooKeeper holds the cluster state
    Then ZooKeeper answers a health check
    And the cluster is registered in ZooKeeper

  Scenario: Roles and databases are created
    Then the database owned by the application role exists
    And the application role can log in through the write port of HAProxy
    And the read-only role can read but not write
    And the removed role does not exist

  Scenario: Credentials are not exposed
    Then the Patroni configuration is readable only by the PostgreSQL user
    And a role without the right password cannot log in

  Scenario: Backups and WAL archiving work
    Then pgBackRest reports a full backup for the stanza
    And the WAL archive check succeeds

  Scenario: Auditing is active
    Then pgAudit is preloaded and its extension exists
    And HAProxy serves Prometheus metrics

  Scenario: The job scheduler runs where the distribution supports it
    Then on the Red Hat family pgAgent runs and its extension exists
    And on Debian and Ubuntu the role installs no pgAgent
