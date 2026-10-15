# Read-only checks against a container that Molecule destroys after the run,
# except the last scenario, which re-applies the role and so runs last. The
# server is initialised and unsealed during verify so that plugin
# registration can be observed; no teardown is needed.
Feature: Manage the OpenBao server configuration

  Background:
    Given the openbao role has been applied with a managed configuration, raft storage with retry_join, a plain HTTP listener and an OCI plugin

  Scenario: The configuration is rendered from role variables
    Then the server configuration is owned by root, readable by the openbao group only
    And it starts with the Ansible managed header
    And it contains the listener, storage, retry_join, plugin, telemetry and extra configuration that were requested
    And OpenBao reports the configuration as valid

  Scenario: The server starts with the rendered configuration
    Then the OpenBao service is enabled and running
    And the server answers health checks over HTTP as uninitialised and sealed

  Scenario: An OCI plugin is downloaded and registered
    Then the plugin directory is owned by the openbao user
    And the plugin image has been downloaded into the plugin directory
    When the server is initialised and unsealed
    Then the plugin is registered in the catalog with the requested version

  Scenario: Applying the role again changes nothing
    When the role is applied a second time
    Then no task reports a change

  Scenario: A configuration change restarts the server
    When the role is applied with a different telemetry setting
    Then the OpenBao service has been restarted
    And the server answers health checks as initialised and sealed
