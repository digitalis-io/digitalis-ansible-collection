# Three nodes on one Docker network, ZooKeeper on every node, a pgBackRest
# repository shared by the nodes and standby backups over SSH.
# Scenarios run in order against the same cluster and must not be run in
# parallel. The switchover scenario moves the leader back before it ends. The
# failover scenario stops Patroni on the leader and always starts it again, but
# the leader stays on the node that took over, so it is the last scenario.
# Rows written by the scenarios live in one table, which the first writing
# scenario creates and the last scenario drops.
Feature: A three node PostgreSQL cluster survives a node change

  Background:
    Given the postgres_cluster role has been applied to three hosts

  Scenario: The nodes form one cluster
    Then Patroni lists one leader and two running replicas without lag
    And ZooKeeper has one leader and two followers
    And the leader streams to both replicas with quorum synchronous replication

  Scenario: Data written through HAProxy reaches every node
    When a row is written through the write port of HAProxy
    Then the row is readable on every node
    And the read port of HAProxy only reaches replicas

  Scenario: Standby backups run over SSH
    When an incremental backup is requested with standby backups enabled
    Then the backup is recorded in the repository

  Scenario: A planned switchover moves the leader
    When the leadership is switched to another node
    Then the write port of HAProxy reaches the new leader
    And no committed row is lost

  Scenario: The cluster survives the loss of the leader
    When Patroni stops on the leader node
    Then another node becomes the leader within the failover window
    And the committed rows are still there
    And the stopped node rejoins as a replica when Patroni starts again
