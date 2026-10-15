# The role must refuse a version string that the package managers cannot
# resolve before it touches the host. Molecule destroys the container after
# converge, so no teardown is needed. Examples run serially in one converge.
Feature: Reject an invalid OpenBao version

  Scenario Outline: Invalid versions are rejected
    When the openbao role is applied with version "<version>"
    Then the role fails with a clear version validation message
    And the OpenBao package is not installed

    Examples:
      | version |
      |         |
      | latest  |
      | 2.7     |
