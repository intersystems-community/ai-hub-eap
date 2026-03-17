/// Advanced ToolSet Example
/// Demonstrates local tools, included policies, MCP servers, and policy composition
Class Sample.AI.Examples.AdvancedToolSet Extends %AI.ToolSet
{
  XData Definition [ MimeType = application/xml ]
  {
    <ToolSet Name="AdvancedExample">
      <Description>Demonstrates local tools, included policies, MCP servers, and policy composition.</Description>

      <!-- Policy Definitions -->
      <Policies>
        <Authorization Class="Sample.AI.Policies.PathSanitizerPolicy">
          <AllowedPath>/tmp</AllowedPath>
          <AllowedPath>/data</AllowedPath>
          <Strict>true</Strict>
        </Authorization>

        <Audit Class="%AI.Policy.ConsoleAudit" />
      </Policies>

      <!-- Inline Tool -->
      <Tool Name="Echo" Method="Echo">
        <Description>Echoes the input back to the user.</Description>
      </Tool>

      <!-- Included Tool with Policy Requirements -->
      <Include Class="%AI.Tools.SQL">
        <Requirement Name="Role" Value="%All"/>
        <Requirement Name="ReadOnly" Value="1"/>
      </Include>

      <!-- MCP Server Examples -->

      <!-- Local MCP Server via Stdio (Uncomment and configure as needed) -->
      <!--
      <MCP Name="CounterServer">
        <Stdio Executable="path/to/counter_server">
           <Env Name="RUST_LOG" Value="info"/>
           <Env Name="TEST_VAR" Value="@{TEST_EXPANSION}"/>
        </Stdio>
      </MCP>
      -->

      <!-- Remote MCP Server via HTTP (Uncomment and configure as needed) -->
      <!--
      <MCP Name="RemoteTools">
        <Remote URL="http://localhost:3000/mcp" />
      </MCP>
      -->

    </ToolSet>
  }

  /// Simple Echo tool implementation
  Method Echo(input As %String) As %String
  {
      Return "Echo: " _ input
  }
}
