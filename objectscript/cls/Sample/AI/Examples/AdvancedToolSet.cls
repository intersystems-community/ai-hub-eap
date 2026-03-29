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

      <!-- Local MCP Server via Stdio (no auth needed) -->
      <!--
      <MCP Name="CounterServer">
        <Stdio Executable="path/to/counter_server">
           <Env Name="RUST_LOG" Value="info"/>
           <Env Name="TEST_VAR" Value="@{TEST_EXPANSION}"/>
        </Stdio>
      </MCP>
      -->

      <!-- Platform-specific Stdio: different executable per OS/arch.
           Platform is a regex matched against the runtime descriptor:
             "<os> <version> <arch>"
           Examples:
             "windows 10.0 x86_64"       (Windows, any version)
             "linux ubuntu 24.04 x86_64" (Ubuntu 24 x64)
             "macos 14.5.0 aarch64"      (macOS Apple Silicon)
           First matching entry wins; no Platform = catch-all fallback. -->
      <!--
      <MCP Name="CrossPlatformServer">
        <Stdio Platform="windows"          Executable="my-mcp-server.cmd"/>
        <Stdio Platform="macos.*aarch64"   Executable="/opt/homebrew/bin/my-mcp-server"/>
        <Stdio Platform="aarch64"          Executable="/usr/local/bin/my-mcp-server-arm64"/>
        <Stdio                             Executable="/usr/local/bin/my-mcp-server"/>
      </MCP>
      -->

      <!-- Remote MCP Server — no auth (open/internal endpoint) -->
      <!--
      <MCP Name="RemoteTools">
        <Remote URL="http://localhost:3000/mcp" />
      </MCP>
      -->

      <!-- Remote MCP Server — OAuth Bearer token
           Sends: Authorization: Bearer <token>
           Use @{env.VAR} to inject from environment at runtime. -->
      <!--
      <MCP Name="SecureRemote">
        <Remote URL="https://mcp.example.com/mcp"
                AuthType="bearer"
                Token="@{env.MCP_TOKEN}" />
      </MCP>
      -->

      <!-- Remote MCP Server — HTTP Basic auth
           Sends: Authorization: Basic base64(username:password) -->
      <!--
      <MCP Name="BasicAuthRemote">
        <Remote URL="https://mcp.example.com/mcp"
                AuthType="basic"
                Username="_SYSTEM"
                Password="@{env.MCP_PASSWORD}" />
      </MCP>
      -->

      <!-- Remote MCP Server — Arbitrary header (API key or custom scheme)
           Sends the named header with the given value verbatim. -->
      <!--
      <MCP Name="ApiKeyRemote">
        <Remote URL="https://mcp.example.com/mcp"
                AuthType="header"
                HeaderName="X-API-Key"
                HeaderValue="@{env.MCP_API_KEY}" />
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
