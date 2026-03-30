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
        "optional": (optional)
    }
    Do result.%Set("optional_provided", (optional '= ""), "boolean")
    Return result
}

/// Return a large response for frame-reassembly testing.
///
/// Generates a string of `count` repeated characters and wraps it in a
/// JSON object.  When unicode=0 (default) the character is ASCII "x" (1 byte
/// in UTF-8); when unicode=1 it is U+3042 HIRAGANA LETTER A (3 bytes in UTF-8).
///
/// Choosing count so that the total STP envelope exceeds 8192 bytes forces
/// iris-mcp-server to reassemble the response from multiple wgproto frames:
///   - ASCII: count > 8192 triggers JSON-split reassembly.
///   - Unicode: count > 2731 guarantees a multi-byte UTF-8 sequence straddles
///     a frame boundary (because the STP envelope offset misaligns the 3-byte
///     characters relative to the 8192-byte frame size).
ClassMethod LargeResponse(
    count As %Integer = 10000,
    unicode As %Boolean = 0) As %DynamicObject
{
    Set char = $SELECT(unicode: $CHAR(12354), 1: "x")
    // Build string by doubling to avoid O(n^2) concatenation in a loop
    Set block = char
    While ($LENGTH(block) < count) {
        Set block = block _ block
    }
    Set data = $EXTRACT(block, 1, count)
    Set result = {
        "data": (data),
        "count": (count)
    }
    Do result.%Set("unicode", unicode, "boolean")
    Return result
}

}
