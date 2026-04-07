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
      <!-- ConsoleAuth prompts for confirmation; ConsoleAudit logs every call. -->
      <Authorization Class="%AI.Policy.ConsoleAuth"/>
      <Audit Class="%AI.Policy.ConsoleAudit"/>
    </Policies>

    <!-- No Tool filter: all methods (Get*, List*, Create*, Update*, Cancel*, Delete*) are included. -->
    <Include Class="Sample.AI.Tools.OrderManagement"/>

  </ToolSet>
}

}
