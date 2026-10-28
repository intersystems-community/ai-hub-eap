Include %occStatus

/// MCP-safe audit policy. It stores only execution metadata, never tool
/// arguments, results, prompts, credentials, or exception text.
Class Sample.AI.Policies.OrdersAuditPolicy Extends %AI.Policy.Audit
    [ DependsOn = Sample.AI.Orders.AuditLog ]
{

Method %LogExecution(
    call As %DynamicObject,
    metadata As %DynamicObject,
    result As %DynamicObject,
    duration As %Integer,
    status As %Status) As %Status
{
    Set log = ##class(Sample.AI.Orders.AuditLog).%New()
    Set log.EventTime = $ZDATETIME($HOROLOG, 3, 1)
    Set log.UserName = $USERNAME
    Set log.ToolName = call.name
    Set log.Outcome = $SELECT($$$ISOK(status): "success", 1: "error")
    Set log.DurationMs = duration
    Return log.%Save()
}

}
