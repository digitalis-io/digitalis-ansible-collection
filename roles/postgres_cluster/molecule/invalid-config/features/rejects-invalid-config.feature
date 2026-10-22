# Each scenario applies the role with one invalid setting on top of a valid
# configuration and expects it to stop with a message that names the setting,
# before it changes the host. The cases are the rows of the Examples table
# implemented in converge.yml; the container is only needed to gather facts,
# and nothing is installed, so there is nothing to clean up.
Feature: The role rejects invalid configuration before touching the host

  Scenario Outline: Invalid input is refused with an explanation
    Given a valid postgres_cluster configuration
    When the role is applied with <problem>
    Then it fails with a message naming <setting>

    Examples: Required secrets
      | problem                         | setting                                |
      | a missing superuser password    | postgres_cluster_superuser_password    |
      | a placeholder replication secret | postgres_cluster_replication_password |
      | a rewind password that is short | postgres_cluster_rewind_password       |

    Examples: Cluster layout
      | problem                                   | setting                          |
      | an unsupported PostgreSQL version         | postgres_cluster_version         |
      | an empty node list                        | postgres_cluster_nodes           |
      | a host missing from the node list         | postgres_cluster_nodes           |
      | a WAL directory inside the data directory | postgres_cluster_wal_directory   |
      | a relative WAL directory                  | postgres_cluster_wal_directory   |
      | an unsupported authentication method      | postgres_cluster_auth_method     |
      | a non-numeric port                        | postgres_cluster_port            |

    Examples: Backups
      | problem                                     | setting                                  |
      | an unsupported backup repository type       | postgres_cluster_pgbackrest_repo_type    |
      | an S3 repository without a bucket           | postgres_cluster_pgbackrest_s3_bucket    |
      | an S3 access key without its secret         | postgres_cluster_pgbackrest_s3_key       |
      | an Azure repository without a container    | postgres_cluster_pgbackrest_azure_*      |
      | a CIFS repository without a share           | postgres_cluster_pgbackrest_cifs_*       |
      | standby backups on a single node           | postgres_cluster_pgbackrest_backup_standby |

    Examples: ZooKeeper, TLS and APIs
      | problem                                  | setting                                 |
      | ZooKeeper nodes outside the node list    | postgres_cluster_zookeeper_nodes        |
      | an external ZooKeeper without addresses  | postgres_cluster_zookeeper_connect      |
      | a self-signed certificate without TLS    | postgres_cluster_ssl_self_signed        |
      | TLS without a certificate path           | postgres_cluster_ssl_cert               |
      | a REST user without a password           | postgres_cluster_patroni_rest_user      |
      | pgAgent without a password               | postgres_cluster_pgagent_password       |

    Examples: Databases and roles
      | problem                                 | setting                   |
      | a user item without a name              | postgres_cluster_users    |
      | a database item with an unknown key     | postgres_cluster_databases |
