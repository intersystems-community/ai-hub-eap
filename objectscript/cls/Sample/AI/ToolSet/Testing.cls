/// Testing ToolSet
/// Combines test utilities with math tools for comprehensive testing
/// General-purpose toolset for validating tool integrations
Class Sample.AI.ToolSet.Testing Extends %AI.ToolSet [ DependsOn = (Sample.AI.Tools.TestUtilities, Sample.AI.Tools.Math) ]
{
  XData Definition [ MimeType = application/xml ]
  {
    <ToolSet Name="Testing">
      <Description>Test utilities and math tools for integration testing</Description>

      <!-- Policies -->
      <Policies>
        <Audit Class="%AI.Policy.ConsoleAudit" />
      </Policies>

      <!-- Include test utilities -->
      <Include Class="Sample.AI.Tools.TestUtilities" />

      <!-- Include math tools for mixed testing -->
      <Include Class="Sample.AI.Tools.Math" />

    </ToolSet>
  }
}
