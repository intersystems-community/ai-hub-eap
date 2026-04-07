/// IRIS Class Browser Tool
///
/// Exposes class queries against %Dictionary.ClassDefinition as tools.
/// This demonstrates the query-as-tool feature: each class query defined on an
/// %AI.Tool subclass is automatically discovered and exposed as a callable tool,
/// with ROWSPEC driving the return schema and query parameters becoming tool inputs.
///
/// No Invoke dispatch code is needed -- the base class handles execution.
///
/// Works in any IRIS namespace without any setup step.
Class Sample.AI.Tools.ClassBrowser Extends %AI.Tool
{

XData INSTRUCTIONS [ MimeType = text/markdown ]
{
# IRIS Class Browser

Search and browse IRIS class definitions in the current namespace.

**Pattern** uses SQL LIKE syntax: `%` matches any sequence of characters,
`_` matches one character. Leave empty or omit to return all classes.
Examples: `Sample.%` (all Sample classes), `%Tool%` (classes with Tool in the name).

**ClassType** narrows by kind. Values: `datatype`, `persistent`, `serial`,
`registered`, `stream`, `view`. Leave empty or omit to include all types.

Results are capped at 100 rows. Use a more specific pattern if you get truncated results.
}

/// Search IRIS class definitions by name pattern and optional class type.
/// Pattern: SQL LIKE syntax, e.g. "Sample.%", "%Tool%". Empty = all classes.
/// ClassType: filter by kind -- datatype, persistent, serial, registered, stream, view. Empty = all.
Query Search(
    Pattern As %String = "",
    ClassType As %String = "") As %SQLQuery(
    ROWSPEC = "Name:%String,ClassType:%String,Abstract:%Boolean,Description:%String") [ SqlProc ]
{
    SELECT Name, ClassType, CASE WHEN Abstract = 1 THEN 1 ELSE 0 END AS Abstract, Description
    FROM %Dictionary.ClassDefinition
    WHERE Name LIKE CASE WHEN :Pattern = '' THEN '%' ELSE :Pattern END
      AND (:ClassType = '' OR ClassType = :ClassType)
    ORDER BY Name
}

}
