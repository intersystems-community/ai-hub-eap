Include (%AI, %occStatus)

/// Math Tool - Basic arithmetic operations
/// General-purpose tool that can be used in agents, MCP services, or any tool-based integration
Class Sample.AI.Tools.Math Extends %AI.Tool
{
/// Display name for this tool provider
Property Name As %String [ InitialExpression = "Math" ];

/// Description of what this tool does
Property Description As %String(MAXLEN = "") [ InitialExpression = "Perform basic arithmetic operations" ];

/// Add two numbers
/// Returns the sum of a and b
ClassMethod Add(a As %Numeric, b As %Numeric) As %DynamicObject
{
    Set result = {
        "operation": "add",
        "a": (a),
        "b": (b),
        "result": (a + b)
    }
    Return result
}

/// Subtract two numbers
/// Returns a minus b
ClassMethod Subtract(a As %Numeric, b As %Numeric) As %DynamicObject
{
    Set result = {
        "operation": "subtract",
        "a": (a),
        "b": (b),
        "result": (a - b)
    }
    Return result
}

/// Multiply two numbers
/// Returns the product of a and b
ClassMethod Multiply(a As %Numeric, b As %Numeric) As %DynamicObject
{
    Set result = {
        "operation": "multiply",
        "a": (a),
        "b": (b),
        "result": (a * b)
    }
    Return result
}

/// Sum all numbers in a list
/// Returns the total of all values in the array
ClassMethod Sum(values As %DynamicArray(ELEMENTTYPE="%Numeric")) As %Numeric
{
    Set total = 0
    Set iter = values.%GetIterator()
    While iter.%GetNext(.key, .value) {
        Set total = total + value
    }
    Return total
}

/// Divide two numbers
/// Returns a divided by b, or error if b is zero
ClassMethod Divide(a As %Numeric, b As %Numeric) As %DynamicObject
{
    If (b = 0) {
        Set error = {
            "error": "Division by zero",
            "code": "DIVIDE_BY_ZERO"
        }
        Return error
    }

    Set result = {
        "operation": "divide",
        "a": (a),
        "b": (b),
        "result": (a / b)
    }
    Return result
}

}
