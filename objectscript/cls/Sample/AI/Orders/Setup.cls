/// Setup and seed data for the Sample.AI.Orders demo.
/// Run ##class(Sample.AI.Orders.Setup).Setup() to populate the database.
/// Run ##class(Sample.AI.Orders.Setup).Reset() to clear all data.
Class Sample.AI.Orders.Setup
{

XData Products
{
<Products>

  <Product>
    <Name>Wireless Headphones</Name>
    <Category>electronics</Category>
    <Price>74.99</Price>
    <Stock>15</Stock>
    <Description>Over-ear wireless headphones with active noise cancellation and 30-hour battery life.</Description>
  </Product>

  <Product>
    <Name>USB-C Hub</Name>
    <Category>electronics</Category>
    <Price>89.50</Price>
    <Stock>8</Stock>
    <Description>7-port hub with USB-A, USB-C PD passthrough, 4K HDMI, SD card, and Ethernet.</Description>
  </Product>

  <Product>
    <Name>Laptop Stand</Name>
    <Category>accessories</Category>
    <Price>55.00</Price>
    <Stock>23</Stock>
    <Description>Adjustable aluminium laptop stand compatible with 11 to 17 inch laptops.</Description>
  </Product>

  <Product>
    <Name>Mechanical Keyboard</Name>
    <Category>electronics</Category>
    <Price>129.00</Price>
    <Stock>5</Stock>
    <Description>Tenkeyless mechanical keyboard with Cherry MX Brown switches and detachable USB-C cable.</Description>
  </Product>

  <Product>
    <Name>Mouse Pad XL</Name>
    <Category>accessories</Category>
    <Price>19.99</Price>
    <Stock>42</Stock>
    <Description>Extended desk pad, 900x400mm, stitched edges, compatible with all mice.</Description>
  </Product>

  <Product>
    <Name>Webcam 1080p</Name>
    <Category>electronics</Category>
    <Price>65.00</Price>
    <Stock>12</Stock>
    <Description>Full HD webcam with built-in microphone, autofocus, and privacy shutter.</Description>
  </Product>

</Products>
}

/// Load seed products into the database. Safe to call multiple times
/// (existing records are skipped via the unique Name index).
ClassMethod LoadProducts() As %Status
{
    Set sc = $$$OK
    Try {
        Set xdata = ##class(%Dictionary.XDataDefinition).IDKEYOpen($CLASSNAME(), "Products")
        If '$ISOBJECT(xdata) $$$ThrowStatus($$$ERROR($$$GeneralError, "XData Products not found"))

        Set reader = ##class(%XML.Reader).%New()
        Set sc = reader.OpenStream(xdata.Data)
        If $$$ISERR(sc) $$$ThrowStatus(sc)

        Do reader.Correlate("Product", "Sample.AI.Orders.Product")

        While reader.Next(.product, .sc) {
            If $$$ISERR(sc) $$$ThrowStatus(sc)
            If ##class(Sample.AI.Orders.Product).NameIdxExists(product.Name) Continue
            Set sc = product.%Save()
            If $$$ISERR(sc) $$$ThrowStatus(sc)
        }

    } Catch ex {
        Set sc = ex.AsStatus()
    }
    Return sc
}

/// Load seed orders into the database. Products must be loaded first.
ClassMethod LoadOrders() As %Status
{
    Set sc = $$$OK
    Try {
        // Each entry: OrderRef, CustomerName, ProductName, Quantity, Status, OrderDate (ISO yyyy-mm-dd)
        Set n = 0
        Set r($INCREMENT(n)) = $LISTBUILD("ORD-001", "Alice Smith",  "Wireless Headphones", 2, "pending",   "2026-03-28")
        Set r($INCREMENT(n)) = $LISTBUILD("ORD-002", "Bob Jones",    "USB-C Hub",           1, "shipped",   "2026-03-29")
        Set r($INCREMENT(n)) = $LISTBUILD("ORD-003", "Carol White",  "Laptop Stand",        4, "delivered", "2026-03-20")
        Set r($INCREMENT(n)) = $LISTBUILD("ORD-004", "Dave Brown",   "Mouse Pad XL",        1, "cancelled", "2026-03-15")
        Set r($INCREMENT(n)) = $LISTBUILD("ORD-005", "Eve Johnson",  "Mechanical Keyboard", 3, "pending",   "2026-04-01")
        Set r($INCREMENT(n)) = $LISTBUILD("ORD-006", "Frank Lee",    "USB-C Hub",           2, "shipped",   "2026-03-30")
        Set r($INCREMENT(n)) = $LISTBUILD("ORD-007", "Grace Kim",    "Webcam 1080p",        1, "delivered", "2026-03-18")
        Set r($INCREMENT(n)) = $LISTBUILD("ORD-008", "Hank Miller",  "Wireless Headphones", 1, "pending",   "2026-04-02")

        For i = 1:1:n {
            Set ref = $LIST(r(i), 1)
            If ##class(Sample.AI.Orders.Order).OrderRefIdxExists(ref) Continue

            Set productName = $LIST(r(i), 3)
            Set product = ##class(Sample.AI.Orders.Product).NameIdxOpen(productName)
            If '$ISOBJECT(product) $$$ThrowStatus($$$ERROR($$$GeneralError, "Product not found: " _ productName))

            Set order              = ##class(Sample.AI.Orders.Order).%New()
            Set order.OrderRef     = ref
            Set order.CustomerName = $LIST(r(i), 2)
            Set order.Product      = product
            Set order.Quantity     = $LIST(r(i), 4)
            Set order.Status       = $LIST(r(i), 5)
            Set order.OrderDate    = $ZDATEH($LIST(r(i), 6), 3)

            Set sc = order.%Save()
            If $$$ISERR(sc) $$$ThrowStatus(sc)
        }

    } Catch ex {
        Set sc = ex.AsStatus()
    }
    Return sc
}

/// Load all seed data. Safe to call multiple times.
ClassMethod Load() As %Status
{
    Set sc = ..LoadProducts()
    If $$$ISERR(sc) Return sc
    Return ..LoadOrders()
}

/// Delete all orders and products from the database.
ClassMethod Reset() As %Status
{
    Set sc = ##class(Sample.AI.Orders.Order).%DeleteExtent()
    If $$$ISERR(sc) Return sc
    Return ##class(Sample.AI.Orders.Product).%DeleteExtent()
}

/// Load seed data (if not already loaded) and print a summary to the terminal.
/// Run from the IRIS terminal: Do ##class(Sample.AI.Orders.Setup).Setup()
ClassMethod Setup() As %Status
{
    Set sc = ..Load()
    If $$$ISERR(sc) {
        Write "Load failed: ", $SYSTEM.Status.GetErrorText(sc), !
        Return sc
    }

    Write "=== Sample.AI.Orders ===", !

    Write !, "Products:", !
    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare("SELECT Name, Category, Price, Stock FROM Sample_AI_Orders.Product ORDER BY Category, Name")
    If $$$ISERR(sc) { Write "SQL error: ", $SYSTEM.Status.GetErrorText(sc), !  Return sc }
    Set rs = stmt.%Execute()
    Set count = 0
    While rs.%Next(.sc) && $$$ISOK(sc) {
        Set count = count + 1
        Write $JUSTIFY(count, 3), ". ", rs.%GetData(1)
        Write " [", rs.%GetData(2), "]"
        Write "  $", rs.%GetData(3)
        Write "  (", rs.%GetData(4), " in stock)", !
    }

    Write !, "Orders:", !
    Set sc = stmt.%Prepare(
        "SELECT OrderRef, CustomerName, Product->Name, Quantity, Status, OrderDate"
        _ " FROM Sample_AI_Orders.CustomerOrder ORDER BY OrderRef")
    If $$$ISERR(sc) { Write "SQL error: ", $SYSTEM.Status.GetErrorText(sc), !  Return sc }
    Set rs = stmt.%Execute()
    Set count = 0
    While rs.%Next(.sc) && $$$ISOK(sc) {
        Set count = count + 1
        Write $JUSTIFY(count, 3), ". ", rs.%GetData(1)
        Write "  ", rs.%GetData(2)
        Write "  x", rs.%GetData(4), " ", rs.%GetData(3)
        Write "  [", rs.%GetData(5), "]"
        Write "  ", $ZDATE(rs.%GetData(6), 3), !
    }

    Write !, count, " order(s) loaded.", !
    Return $$$OK
}

}
