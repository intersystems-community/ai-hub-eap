/// A customer order for one product.
/// SqlTableName avoids the SQL reserved word "Order".
Class Sample.AI.Orders.Order Extends %Persistent [ SqlTableName = CustomerOrder ]
{

/// Human-readable order reference (e.g. "ORD-001"). Unique across all orders.
Property OrderRef As %String(MAXLEN = 20) [ Required ];

/// Name of the customer who placed the order.
Property CustomerName As %String(MAXLEN = 100) [ Required ];

/// Product ordered.
Property Product As Sample.AI.Orders.Product;

/// Number of units ordered.
Property Quantity As %Integer [ Required ];

/// Order status: pending, shipped, delivered, or cancelled.
Property Status As %String(MAXLEN = 20) [ InitialExpression = "pending" ];

/// Date the order was placed (IRIS $HOROLOG date integer).
Property OrderDate As %Date;

/// Unique index on the human-readable reference.
Index OrderRefIdx On OrderRef [ Unique ];

}
