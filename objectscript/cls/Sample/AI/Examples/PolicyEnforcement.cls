/// Policy Enforcement Example
/// Demonstrates authorization and audit policies
Class Sample.AI.Examples.PolicyEnforcement Extends %RegisteredObject
{

/// Example with authorization policy
ClassMethod AuthorizationExample() As %Status
{
    Try {
        Write !, "=== Authorization Policy Example ===", !
        Write "This example restricts file access to specific paths", !, !

        Set apiKey = ##class(Sample.AI.Utils).GetAPIKey("openai")
        If apiKey = "" {
            Write "Error: OPENAI_API_KEY not set (try: Set ^||ENV(""OPENAI_API_KEY"") = ""sk-..."")", !
            Return $$$ERROR($$$GeneralError, "Missing API key")
        }

        Set settings = {}
        Do settings.%Set("api_key", apiKey)
        Set provider = ##class(%AI.Provider).Create("openai", settings)

        Set agent = ##class(%AI.Agent).%New(provider)
        Set agent.Model = "gpt-4o"
        Set agent.SystemPrompt = "You are a file assistant with restricted access."

        Set fsTool = ##class(Sample.AI.Tools.FileSystem).%New()
        Do agent.ToolManager.AddTool(fsTool)

        Set policy = ##class(Sample.AI.Policies.PathSanitizerPolicy).%New()
        Do policy.AllowedPath.Insert("/tmp")
        Do policy.AllowedPath.Insert("/data")
        Set policy.Strict = 1
        Do agent.ToolManager.SetAuthPolicy(policy)

        Write "Agent created with path restriction policy", !
        Write "Allowed paths: /tmp, /data", !, !

        Set session = agent.CreateSession()

        Write "--- Testing allowed path ---", !
        Set question = "List files in /tmp"
        Write "Q: ", question, !
        Set response = agent.Chat(session, question)
        Write "A: ", response.Content, !, !

        Write "--- Testing disallowed path ---", !
        Set question = "List files in /etc"
        Write "Q: ", question, !
        Set response = agent.Chat(session, question)
        Write "A: ", response.Content, !

        Return $$$OK

    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

/// Example with audit policy
ClassMethod AuditExample() As %Status
{
    Try {
        Write !, "=== Audit Policy Example ===", !
        Write "This example logs all tool executions", !, !

        Set apiKey = ##class(Sample.AI.Utils).GetAPIKey("openai")
        If apiKey = "" {
            Write "Error: OPENAI_API_KEY not set (try: Set ^||ENV(""OPENAI_API_KEY"") = ""sk-..."")", !
            Return $$$ERROR($$$GeneralError, "Missing API key")
        }

        Set settings = {}
        Do settings.%Set("api_key", apiKey)
        Set provider = ##class(%AI.Provider).Create("openai", settings)

        Set agent = ##class(%AI.Agent).%New(provider)
        Set agent.Model = "gpt-4o"
        Set agent.SystemPrompt = "You are a helpful assistant."

        Do agent.ToolManager.AddTool(##class(Sample.AI.Tools.BMI).%New())
        Do agent.ToolManager.SetAuditPolicy(##class(%AI.Policy.ConsoleAudit).%New())
        Write "Agent created with audit logging enabled", !, !

        Set session = agent.CreateSession()
        Set question = "Calculate BMI for 1.75m height and 70kg weight"
        Write "Q: ", question, !
        Set response = agent.Chat(session, question)
        Write "A: ", response.Content, !
        Write !, "(Check console output for audit log)", !

        Return $$$OK

    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

/// Example with both authorization and audit policies
ClassMethod CombinedPoliciesExample() As %Status
{
    Try {
        Write !, "=== Combined Policies Example ===", !
        Write "This example uses both authorization and audit policies", !, !

        Set apiKey = ##class(Sample.AI.Utils).GetAPIKey("openai")
        If apiKey = "" {
            Write "Error: OPENAI_API_KEY not set (try: Set ^||ENV(""OPENAI_API_KEY"") = ""sk-..."")", !
            Return $$$ERROR($$$GeneralError, "Missing API key")
        }

        Set settings = {}
        Do settings.%Set("api_key", apiKey)
        Set provider = ##class(%AI.Provider).Create("openai", settings)

        Set agent = ##class(%AI.Agent).%New(provider)
        Set agent.Model = "gpt-4o"
        Set agent.SystemPrompt = "You are a secure file assistant."

        Set fsTool = ##class(Sample.AI.Tools.FileSystem).%New()
        Do agent.ToolManager.AddTool(fsTool)

        Set authPolicy = ##class(Sample.AI.Policies.PathSanitizerPolicy).%New()
        Do authPolicy.AllowedPath.Insert($system.Util.TempDirectory())
        Set authPolicy.Strict = 1
        Do agent.ToolManager.SetAuthPolicy(authPolicy)

        Do agent.ToolManager.SetAuditPolicy(##class(%AI.Policy.ConsoleAudit).%New())

        Write "Agent created with authorization and audit policies", !
        Write "All file operations will be:", !
        Write "  1. Checked for path authorization", !
        Write "  2. Logged to audit trail", !, !

        Set session = agent.CreateSession()
        Set question = "What files are in the temp directory?"
        Write "Q: ", question, !
        Set response = agent.Chat(session, question)
        Write "A: ", response.Content, !

        Return $$$OK

    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

}
