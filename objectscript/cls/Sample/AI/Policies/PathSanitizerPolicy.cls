Include %AI

/// Sample authorization policy that restricts file access to allowed paths
/// This example demonstrates how to implement security policies for file operations
Class Sample.AI.Policies.PathSanitizerPolicy Extends %AI.Policy.Authorization
{

/// List of allowed path prefixes
Property AllowedPath As list Of %String(MAXLEN = "");

/// If true, deny access to paths not in AllowedPath list
Property Strict As %Boolean;

Method %CanExecute(tool As %String, call As %DynamicObject, metadata As %DynamicObject) As %Status
{
    // Parse arguments
    Set args = {}.%FromJSON(call.arguments)

    // Check for path parameter
    If args.%IsDefined("path") {
        Set path = args.path
        Set allowed = 0

        // Check if path starts with an allowed prefix
        For i=1:1:..AllowedPath.Count() {
            Set allowedPrefix = ..AllowedPath.GetAt(i)
            If $EXTRACT(path, 1, $LENGTH(allowedPrefix)) = allowedPrefix {
                Set allowed = 1
                Quit
            }
        }

        If 'allowed && ..Strict {
            Return $$$ERROR($$$AICoreToolAccessDenied, "Path not in allowed list: "_path)
        }

        // Sanitize path (remove relative components)
        Set sanitized = ##class(%File).NormalizeFilename(path)
        If sanitized '= path {
            Set args.path = sanitized
            Set call.arguments = args.%ToJSON()
        }
    }

    Return $$$OK
}

}
