# Read-only checks against a container that Molecule destroys after the run.
Feature: Initialise the OpenBao cluster

  Background:
    Given the openbao role has been applied with openbao_init enabled, one key share and a plain HTTP listener

  Scenario: The cluster is initialised
    Then the server reports itself as initialised and sealed

  Scenario: The init output is stored for root only
    Then the init file is owned by root with mode 0600
    And it contains one unseal key and a root token

  Scenario: Applying the role again does not re-initialise
    When the role is applied a second time
    Then nothing changes
