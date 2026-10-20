# Each example applies the role to the same container with one invalid
# setting. Variable checks fail before the package is installed, so later
# examples see an untouched host. The validation examples run after the
# package is installed and must leave the packaged configuration in place.
# Molecule destroys the container afterwards, so no teardown is needed.
Feature: Reject an invalid OpenBao server configuration

  Scenario Outline: Invalid variables are rejected before the host is changed
    When the openbao role is applied with <invalid input>
    Then the role fails with a message explaining the problem
    And the OpenBao package is not installed once every example has run

    Examples:
      | invalid input                                   |
      | an empty listener list                          |
      | a listener without an address                   |
      | a listener with an empty address                |
      | a listener of an unknown type                   |
      | an empty storage type                           |
      | a plugin without a version                      |
      | a plugin with both image and command            |
      | a plugin of an unknown type                     |
      | an unpinned plugin image without a checksum     |
      | a plugin checksum that is not 64 hex characters |
      | a plugin with an unknown key                    |
      | two plugins with the same type and name         |
      | plugins without a managed configuration         |
      | an unknown plugin download behaviour            |
      | a listener list given as a mapping              |
      | plugins given as a mapping                      |
      | storage options given as a list                 |
      | telemetry options given as a string             |
      | extra configuration given as a list             |
      | a non-boolean config_manage                     |
      | a non-boolean ui setting                        |
      | a non-boolean service_manage                    |
      | a non-integer number of init shares             |
      | an unknown service state                        |
      | an init threshold above the number of shares    |
      | init without a managed service                  |

  Scenario Outline: A configuration OpenBao rejects is never installed
    Given the OpenBao package is installed with its packaged configuration
    When the openbao role is applied with <invalid input>
    Then the role fails because the configuration did not validate
    And the packaged configuration is unchanged

    Examples:
      | invalid input                                   |
      | extra configuration that is not valid HCL       |
      | extra configuration with an unknown option      |
