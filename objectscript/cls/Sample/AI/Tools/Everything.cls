/// ToolSet that connects to the official MCP reference server (@modelcontextprotocol/server-everything).
///
/// Prerequisites:
///   Node.js and npx must be installed and on PATH.
///   The server package is downloaded automatically by npx on first use.
///
/// Tools provided by server-everything:
///   echo                - Echoes back the input message
///   add                 - Adds two numbers together
///   longRunningOperation - Simulates a long-running task with configurable duration/steps
///   getTinyImage        - Returns a small test image (tests multi-modal tool responses)
///   printEnv            - Prints environment variables
Class Sample.AI.Tools.Everything Extends %AI.ToolSet
{

XData Definition [ MimeType = application/xml ]
{
  <ToolSet Name="Everything">
    <Description>MCP reference server tools: echo, arithmetic, long-running operations, and more.</Description>

    <MCP Name="everything">
      <!-- npx is npx.cmd on Windows; the bridge wraps it with cmd /c automatically -->
      <!-- NOTE: npx/nodejs must be in the PATH for this to work -->
      <Stdio Executable="npx">
        <Arg>-y</Arg>
        <Arg>@modelcontextprotocol/server-everything</Arg>
      </Stdio>
    </MCP>

  </ToolSet>
}

}
