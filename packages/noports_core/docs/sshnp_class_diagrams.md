# SSHNP Class Diagrams

## SSHNPImpl Family

```mermaid
classDiagram
  SSHNP <|.. SSHNPImpl

  SSHNPImpl <|.. SSHNPForwardDirection
  SSHNPImpl <|.. SSHNPReverseDirection

  SSHNPForwardDirection <|.. SSHNPForwardDartImpl
  SSHNPForwardDirection <|.. SSHNPForwardExecImpl

  SSHNPReverseDirection <|.. SSHNPReverseImpl
  SSHNPReverseDirection <|.. SSHNPLegacyImpl

  SSHNPLocalFileMixin --* SSHNPReverseDirection
  SSHNPLocalFileMixin --* SSHNPForwardExecImpl

  class SSHNP{
    <<abstract interface>>
  }
  class SSHNPImpl{
    <<abstract>>
  }
  class SSHNPForwardDirection{
    <<abstract>>
  }
  class SSHNPReverseDirection{
    <<abstract>>
  }
  class SSHNPLocalFileMixin{
    <<mixin>>
  }
```

## SSHNPResult Family

```mermaid
classDiagram
    SSHNPResult <|.. SSHNPSuccess
    SSHNPResult <|.. SSHNPFailure

    SSHNPFailure <|.. SSHNPError
    Exception <|.. SSHNPError

    SSHNPSuccess <|.. SSHNPNoOpSuccess
    SSHNPSuccess <|.. SSHNPCommand

    SSHNPCommand *-- SSHNPConnectionBean
    class SSHNPResult {
      <<abstract>>
    }
    class SSHNPConnectionBean {
        <<mixin>>
    }
    class SSHNPNoOpSuccess {
      Needed for pure dart since it doesn't output a command
    }
```