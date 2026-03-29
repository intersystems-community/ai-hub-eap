/// MCP service endpoint and tool provider for the programming languages database.
///
/// This class is both the MCP service endpoint and the tool provider.
/// Extending Sample.AI.Proglang.Tools inherits all tool methods; setting
/// SPECIFICATION to this class name makes it its own tool provider.
/// DISCOVERYLIMIT ensures only methods defined in Tools (and below) are
/// exposed as tools -- MCP infrastructure methods are already excluded by
/// their [ Internal ] keyword, and DISCOVERYLIMIT provides an additional
/// safeguard for any other inherited methods.
///
/// Register as an MCP service endpoint in the IRIS management portal.
Class Sample.AI.Proglang.MCP.Service Extends (%AI.MCP.Service, Sample.AI.Proglang.Tools)
{

Parameter SPECIFICATION As STRING = "Sample.AI.Proglang.MCP.Service";

Parameter DISCOVERYLIMIT As STRING = "Sample.AI.Proglang.Tools";

}
