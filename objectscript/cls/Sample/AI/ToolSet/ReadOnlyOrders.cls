/// Read-Only Orders ToolSet
///
/// Exposes only the safe read operations from Sample.AI.Tools.OrderManagement,
/// using an <Include> Tool regex to select by naming convention.
///
/// The filter Match="^(Get|List)" is a POSIX regular expression matched against
/// each method name at compile time. It captures every method whose name begins
/// with "Get" or "List" -- the entire read-only surface of the tool class --
/// without naming individual methods.
///
/// Included (name starts with Get or List):
///   GetOrder, GetProduct, ListOrders, ListProducts
///
/// Excluded (name does not match the pattern):
///   CreateOrder, UpdateOrderStatus, CancelOrder, DeleteProduct
///
/// As the tool class grows with more Get*/List* methods (e.g. GetCustomer,
/// ListInvoices), they are automatically included here without updating this
/// filter. That is why a regex is the right tool: the selection is based on a
/// naming convention, not a fixed enumeration.
///
/// Prerequisites: Do ##class(Sample.AI.Orders.Setup).Setup()
Class Sample.AI.ToolSet.ReadOnlyOrders Extends %AI.ToolSet
    [ DependsOn = Sample.AI.Tools.OrderManagement ]
{

XData Definition [ MimeType = application/xml ]
{
  <ToolSet Name="ReadOnlyOrders">
    <Description>
      Browse orders and products. Read-only: create, update, cancel, and
      delete operations are excluded by the Tool regex filter.
    </Description>

    <!--
      Tool="^(Get|List)" is evaluated as a POSIX regex against each method name.
      It selects all Get* and List* operations and excludes all mutating ones.
    -->
    <Include Class="Sample.AI.Tools.OrderManagement" Match="^(Get|List)"/>

  </ToolSet>
}

}
