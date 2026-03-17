/// Demo for Skills and SubAgents
Class Sample.AI.Skill.Demo
{

/// Demo: Using the Echo skill
ClassMethod DemoEcho() As %Status
{
    Write !, "=== Echo Skill Demo ===", !

    Try {
        // Create provider
        Set provider = ##class(%AI.Provider).Create("anthropic")

        // Create main agent
        Set agent = ##class(%AI.Agent).%New(provider)
        Set agent.Model = "claude-sonnet-4-5@20250929"

        // Create echo skill and attach it to the agent
        Set echoSkill = ##class(Sample.AI.Skill.Echo).%New()
        Set echoSkill.ParentAgent = agent

        // Register skill as a tool
        Do agent.ToolManager.AddTool(echoSkill)

        // Create session
        Set session = agent.CreateSession()

        // Chat with agent - it can invoke the echo skill
        Write !, "Asking agent to echo a message...", !
        Set response = agent.Chat(session, "Please use the echo tool to analyze this message: I am feeling great today!")

        Write !, "Response:", !
        Do ##class(%AI.System).PrettyPrint(response.Content)
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
        // Create provider
        Set provider = ##class(%AI.Provider).Create("anthropic")

        // Create main agent
        Set agent = ##class(%AI.Agent).%New(provider)
        Set agent.Model = "claude-sonnet-4-5@20250929"

        // Create CreatePR skill and attach it to the agent
        Set prSkill = ##class(Sample.AI.Skill.CreatePR).%New()
        Set prSkill.ParentAgent = agent

        // Register skill as a tool
        Do agent.ToolManager.AddTool(prSkill)

        // Create session
        Set session = agent.CreateSession()

        // Chat with agent - it can invoke the PR creation skill
        Write !, "Asking agent to create a PR...", !
        Set response = agent.Chat(session, "Please create a pull request for the changes in the current directory")

        Write !, "Response:", !
        Do ##class(%AI.System).PrettyPrint(response.Content)
        Write !

        // Show stats
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

/// Demo: Direct subagent invocation (without main agent)
ClassMethod DemoDirectSubAgent() As %Status
{
    Write !, "=== Direct SubAgent Demo ===", !

    Try {
        // Create provider
        Set provider = ##class(%AI.Provider).Create("anthropic")

        // Create parent agent
        Set parentAgent = ##class(%AI.Agent).%New(provider)
        Set parentAgent.Model = "claude-sonnet-4-5@20250929"

        // Create echo skill
        Set echoSkill = ##class(Sample.AI.Skill.Echo).%New()
        Set echoSkill.ParentAgent = parentAgent

        // Invoke skill directly (simulating what LLM would do)
        Write !, "Invoking echo skill directly...", !
        Set args = {"userRequest": "This is a direct test of the echo skill!"}
        Set result = echoSkill.%Invoke("Execute", args)

        Write !, "Result:", !
        Do ##class(%AI.System).PrettyPrint(result)
        Write !

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

    Set sc = ..DemoDirectSubAgent()
    If $$$ISERR(sc) Return sc

    Return $$$OK
}

}
