Include %AI

/// Requires the Sample_Orders_Write IRIS resource for mutating order tools.
/// Read tools have no Access requirement and remain available to all callers
/// who can reach the MCP service.
Class Sample.AI.Policies.OrdersAccessPolicy Extends %AI.Policy.Authorization
{

Parameter WRITERESOURCE = "Sample_Orders_Write";

Method %CanExecute(toolref As %String, call As %DynamicObject, metadata As %DynamicObject) As %Status
{
    If metadata.%Get("Access", "read") '= "write" Return $$$OK

    If $SYSTEM.Security.Check(..#WRITERESOURCE, "USE") Return $$$OK

    Return $$$ERROR($$$AICoreToolAccessDenied, "Order write access is required")
}

}
