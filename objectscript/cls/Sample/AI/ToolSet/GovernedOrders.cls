/// Order tools governed by the caller's real IRIS security context.
///
/// Read operations are available normally. Mutating operations carry an
/// Access=write requirement and require USE permission on the
/// Sample_Orders_Write resource at execution time.
Class Sample.AI.ToolSet.GovernedOrders Extends %AI.ToolSet
    [ DependsOn = (Sample.AI.Tools.OrderManagement, Sample.AI.Policies.OrdersAccessPolicy, Sample.AI.Policies.OrdersAuditPolicy) ]
{

XData Definition [ MimeType = application/xml ]
{
  <ToolSet Name="GovernedOrders">
    <Description>
      Order management with IRIS resource authorization for mutations and
      privacy-preserving database auditing.
    </Description>

    <Policies>
      <Authorization Class="Sample.AI.Policies.OrdersAccessPolicy"/>
      <Audit Class="Sample.AI.Policies.OrdersAuditPolicy"/>
    </Policies>

    <Include Class="Sample.AI.Tools.OrderManagement" Match="^(Get|List)"/>

    <Include Class="Sample.AI.Tools.OrderManagement" Match="^(Create|Update|Cancel|Delete)">
      <Requirement Name="Access" Value="write"/>
    </Include>
  </ToolSet>
}

}
