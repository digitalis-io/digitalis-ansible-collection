Feature: The rabbitmq role rejects invalid configuration before touching the host

  Scenario Outline: Invalid input is refused with an explanation
    Given the rabbitmq role is applied with <problem>
    Then it fails with a message naming <setting>

    Examples: Required secrets
      | problem                        | setting                   |
      | an empty admin password        | rabbitmq_admin_password   |

    Examples: Plugin configuration
      | problem                              | setting                   |
      | plugins given as a string            | rabbitmq_plugins          |
      | plugins list missing management      | rabbitmq_management       |

    Examples: Clustering
      | problem                              | setting                   |
      | a cluster without an Erlang cookie   | rabbitmq_erlang_cookie    |

    Examples: OAuth2
      | problem                                     | setting                       |
      | OAuth2 issuer without client credentials    | rabbitmq_oauth2_client_id     |

    Examples: Longname
      | problem                                  | setting                 |
      | longname enabled without a domain name   | rabbitmq_domain         |
