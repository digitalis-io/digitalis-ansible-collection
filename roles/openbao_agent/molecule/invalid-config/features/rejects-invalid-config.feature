# Each example applies the role to the same container with one invalid
# setting. The role must fail before it writes anything, so later examples see
# an untouched host and no teardown is needed; Molecule destroys the container
# afterwards. Examples run serially within one converge.
Feature: Reject invalid OpenBao Agent configuration

  Scenario Outline: Invalid configuration is rejected before the host is changed
    When the openbao_agent role is applied with <invalid input>
    Then the role fails with a message explaining the problem
    And no agent configuration or service is written to the host

    Examples:
      | invalid input                             |
      | an empty server address                   |
      | a server address without a scheme         |
      | an unsupported auth method                |
      | AppRole without a secret ID               |
      | a template without a destination          |
      | a template with a relative destination    |
      | a template with both contents and source  |
      | a template with an unknown key            |
      | two templates with the same destination   |
      | a template with non-octal permissions     |
      | an exec timeout without a command         |
      | a template rendered directly into /etc    |
      | two src files with the same name          |
      | a token sink mode that is not octal       |
      | a listener on a non-loopback address      |
