/// Testing MCP Service
/// Single MCP service for automated testing of iris-mcp-server
/// Includes math tools, test utilities, and various test scenarios
Class Sample.MCP.Service.Testing Extends %AI.MCP.Service
{

/// Specification of tools/toolsets to expose via this MCP service
/// Includes multiple tool sources for comprehensive testing:
/// - Math tools for basic arithmetic testing
/// - Test utilities for error handling, timing, validation
Parameter SPECIFICATION As STRING = "Sample.AI.Tools.Math,Sample.AI.Tools.TestUtilities";

}
