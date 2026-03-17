Include (%AI, %occStatus)

/// Test Utilities - Tools for testing integrations
/// General-purpose test tools for validating tool execution, error handling, timing, etc.
Class Sample.AI.Tools.TestUtilities Extends %AI.Tool
{
/// Display name for this tool provider
Property Name As %String [ InitialExpression = "Test Utilities" ];

/// Description of what this tool does
Property Description As %String(MAXLEN = "") [ InitialExpression = "Utilities for testing tool integrations" ];

/// Echo the input back unchanged
/// Useful for testing basic request/response flow
ClassMethod Echo(text As %String) As %DynamicObject
{
    Set result = {
        "input": (text),
        "length": ($LENGTH(text)),
        "timestamp": ($ZDATETIME($HOROLOG, 3))
    }
    Return result
}

/// Return structured data with various types
/// Tests JSON serialization and type handling
ClassMethod GetTestData() As %DynamicObject
{
    Set data = {
        "string": "Hello, World!",
        "integer": 42,
        "float": 3.14159,
        "boolean": true,
        "null": null,
        "array": [1, 2, 3, 4, 5],
        "nested": {
            "key1": "value1",
            "key2": "value2"
        }
    }
    Return data
}

/// Always fail with a specific error
/// Tests error handling in integrations
ClassMethod Fail(message As %String = "Intentional test failure") As %DynamicObject
{
    // Throw an error that will be caught and returned
    $$$ThrowStatus($$$ERROR($$$GeneralError, message))
}

/// Sleep for specified milliseconds then return
/// Tests timeout handling and async behavior
ClassMethod Slow(milliseconds As %Integer = 1000) As %DynamicObject
{
    Set startTime = $ZH
    Hang (milliseconds / 1000)
    Set endTime = $ZH

    Set result = {
        "requested_ms": (milliseconds),
        "actual_ms": ($JUSTIFY((endTime - startTime) * 1000, 0, 0)),
        "timestamp": ($ZDATETIME($HOROLOG, 3))
    }
    Return result
}

/// Return current timestamp
/// Useful for testing caching and staleness
ClassMethod GetTimestamp() As %DynamicObject
{
    Set result = {
        "horolog": ($HOROLOG),
        "iso8601": ($ZDATETIME($HOROLOG, 3)),
        "unix_timestamp": ($ZTS)
    }
    Return result
}

/// Validate that required parameters are present
/// Tests parameter validation
ClassMethod ValidateParams(
    required As %String,
    optional As %String = "") As %DynamicObject
{
    Set result = {
        "required": (required),
        "optional": (optional),
        "optional_provided": (optional '= "")
    }
    Return result
}

}
