# Read-only checks against a container that Molecule destroys after the run,
# so no teardown is needed. Scenarios are independent and parallel-safe.
# The server is started with the configuration shipped by the package
# (pebbledb storage, self-signed TLS on port 8200), so it reports itself as
# uninitialised and sealed.
Feature: Install the OpenBao server

  Background:
    Given the openbao role has been applied to a fresh host with the service enabled and started

  Scenario: The requested OpenBao version is installed from the upstream repository
    Then the OpenBao package repository is configured
    And the installed OpenBao version is the requested version
    And the configuration shipped by the package is left in place

  Scenario: The OpenBao server runs as a system service
    Then the OpenBao service is enabled and running
    And the OpenBao server answers health checks as uninitialised and sealed

  Scenario: Applying the role again changes nothing
    When the role is applied a second time
    Then no task reports a change
