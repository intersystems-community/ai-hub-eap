Include (%AI, %occStatus)

/// Order Management Tool
///
/// Provides read and write operations for orders and products, backed by the
/// Sample.AI.Orders database. Seed the database first:
///   Do ##class(Sample.AI.Orders.Setup).Setup()
///
/// Methods follow a verb-prefix naming convention:
///   Get*, List*                          -- safe read operations
///   Create*, Update*, Cancel*, Delete*   -- mutating write operations
///
/// This convention lets a ToolSet use an <Include> regex to select only the
/// read surface without enumerating individual method names:
///   <Include Class="Sample.AI.Tools.OrderManagement" Tool="^(Get|List)"/>
///
/// See: Sample.AI.ToolSet.ReadOnlyOrders  (read-only, regex-filtered)
///      Sample.AI.ToolSet.FullAccessOrders (all operations)
Class Sample.AI.Tools.OrderManagement Extends %AI.Tool
    [ DependsOn = (Sample.AI.Orders.Product, Sample.AI.Orders.Order) ]
{

// -------------------------------------------------------------------------
// Read operations  (matched by the "^(Get|List)" Include regex)
// -------------------------------------------------------------------------

/// List orders, optionally filtered by status.
/// status: "pending", "shipped", "delivered", or "cancelled" -- omit for all.
/// limit: maximum results to return (default 20, capped at 100).
Method ListOrders(status As %String = "", limit As %Integer = 20) As %DynamicObject
{
    Set stmt = ##class(%SQL.Statement).%New()
    Set sql = "SELECT OrderRef, CustomerName, Product->Name AS Product,"
        _ " Quantity, Status, OrderDate"
        _ " FROM Sample_AI_Orders.CustomerOrder"

    If status '= "" {
        Set sql = sql _ " WHERE Status = ? ORDER BY OrderDate DESC"
        Set sc = stmt.%Prepare(sql)
        If $$$ISERR(sc) Return {"error": ($SYSTEM.Status.GetErrorText(sc))}
        Set rs = stmt.%Execute(status)
    } Else {
        Set sql = sql _ " ORDER BY OrderDate DESC"
        Set sc = stmt.%Prepare(sql)
        If $$$ISERR(sc) Return {"error": ($SYSTEM.Status.GetErrorText(sc))}
        Set rs = stmt.%Execute()
    }

    Set rows = []
    Set cap = $SELECT(limit > 100: 100, limit < 1: 1, 1: limit)
    While rs.%Next() && (rows.%Size() < cap) {
        Set entry = {}
        Set entry.orderId      = rs.%GetData(1)
        Set entry.customerName = rs.%GetData(2)
        Set entry.product      = rs.%GetData(3)
        Set entry.quantity     = rs.%GetData(4)
        Set entry.status       = rs.%GetData(5)
        Set entry.orderDate    = $ZDATE(rs.%GetData(6), 3)
        Do rows.%Push(entry)
    }
    Return {"orders": (rows), "count": (rows.%Size())}
}

/// Get full details of a single order by order reference (e.g. "ORD-001").
Method GetOrder(orderId As %String) As %DynamicObject
{
    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare(
        "SELECT OrderRef, CustomerName, Product->Name AS Product,"
        _ " Product->Price AS UnitPrice, Quantity, Status, OrderDate"
        _ " FROM Sample_AI_Orders.CustomerOrder WHERE OrderRef = ?")
    If $$$ISERR(sc) Return {"error": ($SYSTEM.Status.GetErrorText(sc))}

    Set rs = stmt.%Execute(orderId)
    If 'rs.%Next() Return {"error": "Order not found", "orderId": (orderId)}

    Set unitPrice = rs.%GetData(4)
    Set qty       = rs.%GetData(5)
    Return {
        "orderId":      (rs.%GetData(1)),
        "customerName": (rs.%GetData(2)),
        "product":      (rs.%GetData(3)),
        "unitPrice":    (unitPrice),
        "quantity":     (qty),
        "status":       (rs.%GetData(6)),
        "orderDate":    ($ZDATE(rs.%GetData(7), 3)),
        "total":        (unitPrice * qty)
    }
}

/// List all products, optionally filtered by category (e.g. "electronics", "accessories").
Method ListProducts(category As %String = "") As %DynamicObject
{
    Set stmt = ##class(%SQL.Statement).%New()
    If category '= "" {
        Set sc = stmt.%Prepare(
            "SELECT Name, Category, Price, Stock, Description"
            _ " FROM Sample_AI_Orders.Product WHERE Category = ? ORDER BY Name")
        If $$$ISERR(sc) Return {"error": ($SYSTEM.Status.GetErrorText(sc))}
        Set rs = stmt.%Execute(category)
    } Else {
        Set sc = stmt.%Prepare(
            "SELECT Name, Category, Price, Stock, Description"
            _ " FROM Sample_AI_Orders.Product ORDER BY Category, Name")
        If $$$ISERR(sc) Return {"error": ($SYSTEM.Status.GetErrorText(sc))}
        Set rs = stmt.%Execute()
    }

    Set rows = []
    While rs.%Next(.sc) && $$$ISOK(sc) {
        Set entry = {}
        Set entry.name        = rs.%GetData(1)
        Set entry.category    = rs.%GetData(2)
        Set entry.price       = rs.%GetData(3)
        Set entry.stock       = rs.%GetData(4)
        Set entry.description = rs.%GetData(5)
        Do rows.%Push(entry)
    }
    If $$$ISERR(sc) Return {"error": ($SYSTEM.Status.GetErrorText(sc))}
    Return {"products": (rows), "count": (rows.%Size())}
}

/// Get full details of a single product by name (e.g. "USB-C Hub").
Method GetProduct(name As %String) As %DynamicObject
{
    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare(
        "SELECT Name, Category, Price, Stock, Description"
        _ " FROM Sample_AI_Orders.Product WHERE Name = ?")
    If $$$ISERR(sc) Return {"error": ($SYSTEM.Status.GetErrorText(sc))}

    Set rs = stmt.%Execute(name)
    If 'rs.%Next() Return {"error": "Product not found", "name": (name)}

    Return {
        "name":        (rs.%GetData(1)),
        "category":    (rs.%GetData(2)),
        "price":       (rs.%GetData(3)),
        "stock":       (rs.%GetData(4)),
        "description": (rs.%GetData(5))
    }
}

// -------------------------------------------------------------------------
// Write operations  (excluded by the "^(Get|List)" Include regex)
// -------------------------------------------------------------------------

/// Create a new pending order.
/// productName must match an existing product name exactly (use ListProducts to browse).
Method CreateOrder(customerName As %String, productName As %String, quantity As %Integer) As %DynamicObject
{
    Set product = ##class(Sample.AI.Orders.Product).NameIdxOpen(productName)
    If '$ISOBJECT(product) Return {"error": "Product not found", "productName": (productName)}

    // Derive next order reference from current row count
    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare("SELECT COUNT(*) FROM Sample_AI_Orders.CustomerOrder")
    If $$$ISERR(sc) Return {"error": ($SYSTEM.Status.GetErrorText(sc))}
    Set rs = stmt.%Execute()
    If 'rs.%Next() Return {"error": "COUNT query returned no rows"}
    Set ref = "ORD-" _ $TRANSLATE($JUSTIFY(rs.%GetData(1) + 1, 3), " ", "0")

    Set order              = ##class(Sample.AI.Orders.Order).%New()
    Set order.OrderRef     = ref
    Set order.CustomerName = customerName
    Set order.Product      = product
    Set order.Quantity     = quantity
    Set order.Status       = "pending"
    Set order.OrderDate    = +$HOROLOG

    Set sc = order.%Save()
    If $$$ISERR(sc) Return {"error": ($SYSTEM.Status.GetErrorText(sc))}

    Return {
        "orderId":      (ref),
        "customerName": (customerName),
        "product":      (productName),
        "quantity":     (quantity),
        "status":       "pending",
        "orderDate":    ($ZDATE(+$HOROLOG, 3))
    }
}

/// Update the status of an existing order.
/// status must be one of: pending, shipped, delivered, cancelled.
Method UpdateOrderStatus(orderId As %String, status As %String) As %DynamicObject
{
    If '$LISTFIND($LISTBUILD("pending", "shipped", "delivered", "cancelled"), status) {
        Return {"error": "Invalid status. Must be: pending, shipped, delivered, or cancelled"}
    }

    Set order = ##class(Sample.AI.Orders.Order).OrderRefIdxOpen(orderId)
    If '$ISOBJECT(order) Return {"error": "Order not found", "orderId": (orderId)}

    Set order.Status = status
    Set sc = order.%Save()
    If $$$ISERR(sc) Return {"error": ($SYSTEM.Status.GetErrorText(sc))}

    Return {"orderId": (orderId), "status": (status), "updated": ($ZDATETIME($HOROLOG, 3, 1))}
}

/// Cancel an order (convenience wrapper for UpdateOrderStatus to "cancelled").
Method CancelOrder(orderId As %String) As %DynamicObject
{
    Return ..UpdateOrderStatus(orderId, "cancelled")
}

/// Delete a product from the catalogue.
/// Fails if the product has any non-cancelled orders.
Method DeleteProduct(name As %String) As %DynamicObject
{
    Set product = ##class(Sample.AI.Orders.Product).NameIdxOpen(name)
    If '$ISOBJECT(product) Return {"error": "Product not found", "name": (name)}

    // Refuse if there are open orders for this product
    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare(
        "SELECT COUNT(*) FROM Sample_AI_Orders.CustomerOrder"
        _ " WHERE Product = ? AND Status <> 'cancelled'")
    If $$$ISERR(sc) Return {"error": ($SYSTEM.Status.GetErrorText(sc))}
    Set rs = stmt.%Execute(product.%Id())
    If 'rs.%Next() Return {"error": "COUNT query returned no rows"}
    If rs.%GetData(1) > 0 {
        Return {"error": "Cannot delete: product has open (non-cancelled) orders", "name": (name)}
    }

    Set sc = ##class(Sample.AI.Orders.Product).%DeleteId(product.%Id())
    If $$$ISERR(sc) Return {"error": ($SYSTEM.Status.GetErrorText(sc))}

    Return {"deleted": (name)}
}

}
