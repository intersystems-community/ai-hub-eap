/// Full-Access Orders ToolSet
///
/// Exposes all operations from Sample.AI.Tools.OrderManagement: reads and writes.
/// Compare with Sample.AI.ToolSet.ReadOnlyOrders, which uses Tool="^(Get|List)"
/// to exclude all mutating operations.
///
/// Prerequisites: Do ##class(Sample.AI.Orders.Setup).Setup()
Class Sample.AI.ToolSet.FullAccessOrders Extends %AI.ToolSet
    [ DependsOn = Sample.AI.Tools.OrderManagement ]
{

XData Definition [ MimeType = application/xml ]
{
  <ToolSet Name="FullAccessOrders">
    <Description>
      Full order management: browse, create, update, cancel, and delete
      orders and products.
    </Description>

    <Policies>
      <!-- ConsoleAuth prompts for confirmation; ConsoleAudit logs every call. Both write to the current device, so this toolset is for terminal and agent use only. Do not expose it over MCP: console output corrupts the JSON-RPC response body and every tools/call will fail. ConsoleAuth is worse there, since nothing can answer its prompt.-->
      <Authorization Class="%AI.Policy.ConsoleAuth"/>
      <Audit Class="%AI.Policy.ConsoleAudit"/>
    </Policies>

    <!-- No Tool filter: all methods (Get*, List*, Create*, Update*, Cancel*, Delete*) are included. -->
    <Include Class="Sample.AI.Tools.OrderManagement"/>

  </ToolSet>
}

}
