/// Tool Usage Example
/// Demonstrates how to use tools with AI agents
Class Sample.AI.Examples.ToolUsage Extends %RegisteredObject
{

/// Example using the BMI calculator tool
ClassMethod BMIExample() As %Status
{
    Try {
        Write !, "=== BMI Calculator Tool Example ===", !

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
        Set agent.SystemPrompt = "You are a health assistant. Use tools when appropriate."

        Do agent.ToolManager.AddTool(##class(Sample.AI.Tools.BMI).%New())
        Write "Agent created with BMI calculator tool", !, !

        Set session = agent.CreateSession()
        Set question = "What is my BMI if I'm 1.75 meters tall and weigh 70 kilograms?"
        Write "Q: ", question, !
        Set response = agent.Chat(session, question)
        Write "A: ", response.Content, !

        Return $$$OK

    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

/// Example using file system tools
ClassMethod FileSystemExample() As %Status
{
    Try {
        Write !, "=== File System Tool Example ===", !

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
        Set agent.SystemPrompt = "You are a file system assistant."

        Set fsTool = ##class(Sample.AI.Tools.FileSystem).%New()
        Set fsTool.BaseDirectory = $system.Util.TempDirectory()
        Do agent.ToolManager.AddTool(fsTool)
        Write "Agent created with file system tools", !
        Write "Base directory: ", fsTool.BaseDirectory, !, !

        Set session = agent.CreateSession()
        Set question = "List the files in the current directory"
        Write "Q: ", question, !
        Set response = agent.Chat(session, question)
        Write "A: ", response.Content, !

        Return $$$OK

    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

/// Example using SQL tool
ClassMethod SQLExample() As %Status
{
    Try {
        Write !, "=== SQL Tool Example ===", !

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
        Set agent.SystemPrompt = "You are a database assistant. Help users query the database."

        Set sqlTool = ##class(%AI.Tools.SQL).%New()
        Do agent.ToolManager.AddTool(sqlTool)
        Write "Agent created with SQL tool", !, !

        Set session = agent.CreateSession()
        Set question = "Show me the top 5 namespaces in the system"
        Write "Q: ", question, !
        Set response = agent.Chat(session, question)
        Write "A: ", response.Content, !

        Return $$$OK

    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

/// Example using multiple tools together
ClassMethod MultiToolExample() As %Status
{
    Try {
        Write !, "=== Multi-Tool Example ===", !

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
        Set agent.SystemPrompt = "You are a helpful assistant with access to multiple tools. Use them as needed."

        Do agent.ToolManager.AddTool(##class(Sample.AI.Tools.BMI).%New())
        Do agent.ToolManager.AddTool(##class(%AI.Tools.SQL).%New())
        Write "Agent created with BMI and SQL tools", !, !

        Set session = agent.CreateSession()
        Set question = "First, calculate my BMI for height 1.80m and weight 75kg. Then check how many namespaces we have."
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
