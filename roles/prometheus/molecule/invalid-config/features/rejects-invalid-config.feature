# Each example applies the role to the same container with one invalid
# setting. The role's argument_specs reject it on entry, before any task runs,
# so no package is installed and /etc/prometheus is never created. The valid
# example passes validation and stops at the listen address check instead.
# No option in the spec has a finite set of allowed values, so there are no
# invalid-choice examples. Molecule destroys the container afterwards.
Feature: Reject invalid Prometheus role variables

  Scenario Outline: Variables of the wrong type are rejected
    When the prometheus role is applied with <invalid input>
    Then the role fails at argument validation with a message naming the variable
    And the Prometheus configuration directory does not exist once every example has run

    Examples:
      | invalid input                              |
      | a non-boolean agent mode                   |
      | a non-boolean service switch               |
      | a non-boolean local download switch        |
      | a read-only directory list given as a dict |
      | an alert rules file list given as a dict   |
      | extra flags given as a list                |
      | a global section given as a number         |
      | a web config given as a plain string       |
      | targets given as a list                    |
      | external labels given as a list            |
      | an alert rule that is not a dict           |
      | an alertmanager entry that is not a dict   |
      | a scrape config that is not a dict         |
      | a remote write entry that is not a dict    |

  Scenario: Valid variables pass argument validation
    When the prometheus role is applied with valid values and a listen address without a port
    Then argument validation succeeds
    And the role fails later at the listen address check
