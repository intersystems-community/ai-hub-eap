/// Basic Math ToolSet
/// Demonstrates composing math tools with audit policies
/// General-purpose toolset usable in any tool-based integration
Class Sample.AI.ToolSet.BasicMath Extends %AI.ToolSet [ DependsOn = Sample.AI.Tools.Math ]
{
  XData Definition [ MimeType = application/xml ]
  {
    <ToolSet Name="BasicMath">
      <Description>Basic arithmetic operations with audit logging</Description>

      <!-- Policies -->
      <Policies>
        <Audit Class="%AI.Policy.ConsoleAudit" />
      </Policies>

      <!-- Include Math tools -->
      <Include Class="Sample.AI.Tools.Math" />

    </ToolSet>
  }
}
