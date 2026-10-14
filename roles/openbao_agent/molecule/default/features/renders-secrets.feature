# Runs against a single container holding an in-memory OpenBao dev server
# (started by prepare) and the agent installed by the role. Molecule destroys
# the container afterwards, so the secret rotated in the last scenario needs
# no teardown. Scenarios run serially in the order written because the
# rotation scenario changes the secret the earlier scenarios read.
Feature: Render secrets to files with OpenBao Agent

  Background:
    Given an OpenBao server holding the application secret
    And the openbao_agent role has been applied with AppRole credentials and two templates

  Scenario: The agent runs as a system service
    Then the OpenBao Agent service is enabled and running
    And the AppRole credentials are readable only by the agent user

  Scenario: Secrets are rendered from inline and file templates
    Then the inline template is rendered with the secret value and the requested permissions
    And the file template, which sets no permissions, is rendered private to the agent user
    And the command attached to the file template has run

  Scenario: The agent exposes its token to local clients
    Then the auto-auth token is written to the token sink
    And the local API proxy answers secret reads without a client token

  Scenario: Applying the role again changes nothing
    When the role is applied a second time
    Then no task reports a change

  Scenario: A rotated secret is re-rendered without running Ansible
    When the application secret changes on the server
    Then the rendered files contain the new value within the render interval
