/// Demo for Skills
Class Sample.AI.Skill.Demo
{

/// Demo: Using the Echo skill
ClassMethod DemoEcho() As %Status
{
    Write !, "=== Echo Skill Demo ===", !

    Try {
        Set apiKey = ##class(Sample.AI.Utils).GetAPIKey("anthropic")
        Set provider = ##class(%AI.Provider).Create("anthropic", {"api_key": (apiKey)})

        Set agent = ##class(%AI.Agent).%New(provider)
        Set agent.Model = "claude-sonnet-4-6"
        Set agent.SystemPrompt = "You are a helpful assistant."

        // Load the Echo skill -- its instructions merge into the system prompt
        // and its tools are added to the catalog
        $$$ThrowOnError(agent.UseSkill("Sample.AI.Skill.Echo"))

        Set session = agent.CreateSession()

        Write !, "Asking agent to echo a message...", !
        Set response = agent.Chat(session, "Please echo this message: I am feeling great today!")

        Write !, "Response:", !
        Do ##class(%AI.System).RenderMarkdown(response.Content)
        Write !

        Return $$$OK

    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

/// Demo: Using the CreatePR skill
ClassMethod DemoCreatePR() As %Status
{
    Write !, "=== CreatePR Skill Demo ===", !

    Try {
        Set apiKey = ##class(Sample.AI.Utils).GetAPIKey("anthropic")
        Set provider = ##class(%AI.Provider).Create("anthropic", {"api_key": (apiKey)})

        Set agent = ##class(%AI.Agent).%New(provider)
        Set agent.Model = "claude-sonnet-4-6"
        Set agent.SystemPrompt = "You are a project assistant."

        // Load the CreatePR skill -- contributes filesystem tools and PR instructions
        $$$ThrowOnError(agent.UseSkill("Sample.AI.Skill.CreatePR"))

        Set session = agent.CreateSession()

        Write !, "Asking agent to create a PR description...", !
        Set response = agent.Chat(session, "Please create a pull request description for the changes in the current directory")

        Write !, "Response:", !
        Do ##class(%AI.System).RenderMarkdown(response.Content)
        Write !

        Set stats = session.GetStats()
        Write !, "Session Stats:", !
        Write "  Interactions: ", stats."total_interactions", !
        Write "  Tool Calls: ", stats."total_tool_calls", !

        Return $$$OK

    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

/// Run all demos
ClassMethod Demo() As %Status
{
    Set sc = ..DemoEcho()
    If $$$ISERR(sc) Return sc

    Set sc = ..DemoCreatePR()
    If $$$ISERR(sc) Return sc

    Return $$$OK
}

}
