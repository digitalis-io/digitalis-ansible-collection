# A cluster that lost its database files and its ZooKeeper state is rebuilt
# by applying the role again, which finds the backup and restores the latest
# one instead of creating an empty database. converge.yml does the destruction
# and the rebuild; the scenarios check the result. They only read state, run in
# order against one container and need no clean-up.
Feature: The role rebuilds a lost cluster from its pgBackRest backup

  Background:
    Given a cluster with a backup has lost its data directory and its ZooKeeper state
    And the postgres_cluster role has been applied again

  Scenario: The data comes back
    Then the table written before the loss exists with its row
    And the database was restored rather than created empty

  Scenario: The rebuilt cluster is healthy
    Then Patroni reports a running leader
    And the pgBackRest stanza is healthy and archiving
    And the Patroni configuration still bootstraps from a backup
