# One node with TLS everywhere, an authenticated Patroni REST API, md5
# passwords, a separate WAL directory, a non-default PostgreSQL port and
# non-default HAProxy ports. The scenarios only read state, run in order
# against one container and need no clean-up; Molecule destroys the container.
Feature: An encrypted single node cluster with a custom layout

  Background:
    Given the postgres_cluster role has been applied with TLS enabled

  Scenario: Connections are encrypted
    Then a client connecting through HAProxy uses TLS
    And a client that refuses TLS is rejected

  Scenario: The Patroni API is served over HTTPS and protects changes
    Then the Patroni API answers over HTTPS
    And a configuration reload without credentials is refused
    And a configuration reload with the credentials is accepted

  Scenario: The certificate and key are protected
    Then the private key is readable only by the PostgreSQL user
    And the certificate names the host address

  Scenario: The custom layout is honoured
    Then PostgreSQL listens on the configured port
    And the write-ahead log lives in the configured directory
    And the database uses the configured locale and md5 password hashes
