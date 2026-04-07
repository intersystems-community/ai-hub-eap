/// A product available for ordering.
Class Sample.AI.Orders.Product Extends (%Persistent, %XML.Adaptor)
{

/// Product display name (e.g. "Wireless Headphones").
Property Name As %String(MAXLEN = 100) [ Required ];

/// Product category (e.g. "electronics", "accessories").
Property Category As %String(MAXLEN = 50);

/// Unit price.
Property Price As %Numeric(SCALE = 2);

/// Units currently in stock.
Property Stock As %Integer;

/// Short description of the product and its key features.
Property Description As %String(MAXLEN = 500);

/// Unique index so products can be looked up by name.
Index NameIdx On Name [ Unique ];

}
