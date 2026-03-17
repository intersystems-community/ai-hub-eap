Include (%AI, %occStatus)

/// BMI Calculator Tool - Sample implementation demonstrating a simple calculation tool
/// This example shows how to create a basic tool that performs calculations.
Class Sample.AI.Tools.BMI Extends %AI.Tool
{
/// Display name for this tool provider
Property Name As %String [ InitialExpression = "BMI Calculator" ];

/// Description of what this tool does
Property Description As %String(MAXLEN = "") [ InitialExpression = "Calculate Body Mass Index (BMI) given height and weight" ];

/// Calculate Body Mass Index (BMI)
/// heightM: Height in meters
/// weightKg: Weight in kilograms
/// Returns object with BMI value and category
ClassMethod CalculateBMI(heightM As %Float, weightKg As %Float) As %DynamicObject
{
    Set status = $$$OK
    Try {
        // Validate inputs
        If (heightM <= 0) {
            Set error = {"error": "Height must be greater than 0"}
            Return error
        }

        If (weightKg <= 0) {
            Set error = {"error": "Weight must be greater than 0"}
            Return error
        }

        // Calculate BMI
        Set bmi = weightKg / (heightM * heightM)

        // Determine category
        Set category = $SELECT(
            bmi < 18.5: "underweight",
            bmi < 25: "normal",
            bmi < 30: "overweight",
            1: "obese"
        )

        // Return result
        Set result = {
            "bmi": (bmi),
            "category": (category),
            "height_m": (heightM),
            "weight_kg": (weightKg)
        }
        Return result

    } Catch ex {
        Set error = {"error": ("Calculation failed: " _ ex.DisplayString())}
        Return error
    }
}
}
