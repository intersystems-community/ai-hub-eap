/// Calculator MCP Service
/// Sample MCP service demonstrating math tools with audit policy
/// Shows best practices for policy enforcement in production scenarios
Class Sample.MCP.Service.Calculator Extends %AI.MCP.Service
{

/// Specification of tools/toolsets to expose via this MCP service
/// Uses the BasicMath ToolSet which includes audit policies
Parameter SPECIFICATION As STRING = "Sample.AI.ToolSet.BasicMath";

}
