/// Nested Agents Example - Demonstrates RLM (Recursive Language Model) Pattern
/// Shows how parent agents can spawn sub-agents to handle subtasks
Class Sample.AI.Examples.NestedAgents Extends %RegisteredObject
{

/// Resolve API key and provider type, preferring OpenAI then Anthropic.
/// Returns 1 on success and sets apiKey, providerType, model by reference.
/// Returns 0 and writes an error message on failure.
ClassMethod ResolveProvider(Output apiKey As %String, Output providerType As %String, Output model As %String) As %Boolean [ Private ]
{
    Set apiKey = ##class(Sample.AI.Utils).GetAPIKey("openai", .providerType)
    If apiKey = "" {
        Set apiKey = ##class(Sample.AI.Utils).GetAPIKey("anthropic", .providerType)
    }
    If apiKey = "" {
        Write "Error: No API key found.", !
        Write "Set one of: OPENAI_API_KEY, ANTHROPIC_API_KEY", !
        Write "  export OPENAI_API_KEY='sk-...'", !
        Write "  Set ^||ENV(""OPENAI_API_KEY"") = ""sk-...""", !
        Quit 0
    }
    Set model = $SELECT(providerType = "anthropic": "claude-sonnet-4-5@20250929", 1: "gpt-4o")
    Quit 1
}

/// Example 1: Simple delegation with DelegateTask tool
/// The parent agent uses a tool that creates a sub-agent
ClassMethod SimpleDelegation() As %Status
{
    Try {
        Write !, "=== Simple Delegation Example ===", !
        Write "Parent agent will delegate a subtask to a sub-agent", !, !

        If '..ResolveProvider(.apiKey, .providerType, .model) {
            Return $$$ERROR($$$GeneralError, "Missing API key")
        }

        Set settings = {}
        Do settings.%Set("api_key", apiKey)
        Set provider = ##class(%AI.Provider).Create(providerType, settings)
        Write "Provider: ", providerType, !

        Set parentAgent = ##class(%AI.Agent).%New(provider)
        Set parentAgent.Model = model
        Set parentAgent.SystemPrompt = "You are a project manager. When you receive a complex task, break it down and delegate subtasks using the delegate_task tool."
        Write "Parent Agent Model: ", model, !, !

        Set delegateTool = ##class(Sample.AI.Tools.DelegateTask).%New()
        Set delegateTool.ParentAgent = parentAgent
        Do parentAgent.ToolManager.AddTool(delegateTool)
        Write "Registered delegate_task tool", !, !

        Set session = parentAgent.CreateSession()
        Set task = "I need you to write a short blog post about the benefits of nested AI agents. The post should have an introduction, 3 main points, and a conclusion."

        Write "Task: ", task, !, !
        Write "--- Parent Agent Working ---", !

        Set response = parentAgent.Chat(session, task)

        Write !, "--- Final Response ---", !
        Do ##class(%AI.System).PrettyPrint(response.Content)

        Set stats = session.GetStats()
        Write !, !, "Session Stats:", !
        Write "  Interactions: ", stats."total_interactions", !
        Write "  Tool Calls: ", stats."total_tool_calls", !

        Return $$$OK

    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

/// Example 2: Multi-level delegation (3 levels deep)
/// Parent -> Sub-agent -> Sub-sub-agent
ClassMethod DeepDelegation() As %Status
{
    Try {
        Write !, "=== Deep Delegation Example (3 Levels) ===", !
        Write "Demonstrates parent -> sub-agent -> sub-sub-agent pattern", !, !

        If '..ResolveProvider(.apiKey, .providerType, .model) {
            Return $$$ERROR($$$GeneralError, "Missing API key")
        }

        Set settings = {}
        Do settings.%Set("api_key", apiKey)
        Set provider = ##class(%AI.Provider).Create(providerType, settings)

        Set level1Agent = ##class(%AI.Agent).%New(provider)
        Set level1Agent.Model = model
        Set level1Agent.SystemPrompt = "You are a senior architect. Break down complex projects and delegate to specialists."

        Set delegateTool1 = ##class(Sample.AI.Tools.DelegateTask).%New()
        Set delegateTool1.ParentAgent = level1Agent
        Do level1Agent.ToolManager.AddTool(delegateTool1)

        Write "Level 1 Agent: Senior Architect", !
        Write "  Model: ", model, !
        Write "  Has delegate_task tool: Yes", !, !

        Set session = level1Agent.CreateSession()
        Set task = "Design a simple REST API for a todo application. Include endpoint design, data models, and a brief implementation plan."

        Write "Task: ", task, !, !
        Write "--- Execution (watch for nested delegations) ---", !

        Set response = level1Agent.Chat(session, task)

        Write !, "--- Final Response ---", !
        Do ##class(%AI.System).PrettyPrint(response.Content)

        Set stats = session.GetStats()
        Write !, !, "Session Stats:", !
        Write "  Total Interactions: ", stats."total_interactions", !
        Write "  Total Tool Calls: ", stats."total_tool_calls", !
        Write "  (Each delegation is a tool call that creates a sub-agent)", !

        Return $$$OK

    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

/// Example 3: Parallel delegation
/// Parent delegates multiple independent subtasks concurrently (conceptually)
ClassMethod ParallelDelegation() As %Status
{
    Try {
        Write !, "=== Parallel Delegation Example ===", !
        Write "Parent delegates multiple independent subtasks", !, !

        If '..ResolveProvider(.apiKey, .providerType, .model) {
            Return $$$ERROR($$$GeneralError, "Missing API key")
        }

        Set settings = {}
        Do settings.%Set("api_key", apiKey)
        Set provider = ##class(%AI.Provider).Create(providerType, settings)

        Set coordinator = ##class(%AI.Agent).%New(provider)
        Set coordinator.Model = model
        Set coordinator.SystemPrompt = "You are a project coordinator. When given a task with multiple independent parts, delegate each part to a specialist using delegate_task."

        Set delegateTool = ##class(Sample.AI.Tools.DelegateTask).%New()
        Set delegateTool.ParentAgent = coordinator
        Do coordinator.ToolManager.AddTool(delegateTool)
        Write "Coordinator Agent configured", !, !

        Set session = coordinator.CreateSession()
        Set task = "I need three things: 1) A haiku about coding, 2) Calculate 15% tip on $47.50, 3) Suggest a healthy breakfast. Delegate each to a specialist."

        Write "Task: ", task, !, !
        Write "--- Coordinator delegating subtasks ---", !

        Set response = coordinator.Chat(session, task)

        Write !, "--- Aggregated Response ---", !
        Do ##class(%AI.System).PrettyPrint(response.Content)

        Set stats = session.GetStats()
        Write !, !, "Session Stats:", !
        Write "  Interactions: ", stats."total_interactions", !
        Write "  Tool Calls: ", stats."total_tool_calls", !
        Write "  (Expect ~3 tool calls for 3 delegations)", !

        Return $$$OK

    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

/// Example 4: Direct subagent creation (programmatic)
/// Shows how to create sub-agents directly without tool delegation
ClassMethod DirectSubagentCreation() As %Status
{
    Try {
        Write !, "=== Direct Subagent Creation Example ===", !
        Write "Creating sub-agents programmatically (not via LLM tool use)", !, !

        If '..ResolveProvider(.apiKey, .providerType, .model) {
            Return $$$ERROR($$$GeneralError, "Missing API key")
        }
        // Use mini model for cost efficiency in the direct creation example
        If providerType = "openai" { Set model = "gpt-4o-mini" }

        Set settings = {}
        Do settings.%Set("api_key", apiKey)
        Set provider = ##class(%AI.Provider).Create(providerType, settings)

        Set parentAgent = ##class(%AI.Agent).%New(provider)
        Set parentAgent.Model = model
        Write "Parent Agent created", !

        Write !, "Creating specialized sub-agents:", !

        Write "  1. Poet sub-agent...", !
        Set poetAgent = ##class(%AI.SubAgent).Create(parentAgent, "You are a creative poet. Write short, beautiful poems.", "")
        Set session1 = poetAgent.CreateSession()
        Set response1 = poetAgent.Run(session1, "Write a haiku about the ocean")
        Write "     Result: ", $EXTRACT(response1.Content, 1, 50), "...", !

        Write "  2. Mathematician sub-agent...", !
        Set mathAgent = ##class(%AI.SubAgent).Create(parentAgent, "You are a precise mathematician. Provide exact calculations.", "")
        Set session2 = mathAgent.CreateSession()
        Set response2 = mathAgent.Run(session2, "What is 17 * 23?")
        Write "     Result: ", response2.Content, !

        Write "  3. Chef sub-agent...", !
        Set chefAgent = ##class(%AI.SubAgent).Create(parentAgent, "You are a professional chef. Give cooking advice.", "")
        Set session3 = chefAgent.CreateSession()
        Set response3 = chefAgent.Run(session3, "Quick breakfast idea?")
        Write "     Result: ", $EXTRACT(response3.Content, 1, 50), "...", !

        Write !, "All sub-agents completed successfully!", !

        Return $$$OK

    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

/// Run all examples
ClassMethod RunAll() As %Status
{
    // Box-drawing characters: Unicode on Unicode IRIS instances, ASCII fallback on 8-bit
    Set uni   = $zbitget($zversion(0),1)
    Set lbox  = $SELECT(uni:$C($ZHEX("2554")),1:"+")  // U+2554 top-left corner
    Set rbox  = $SELECT(uni:$C($ZHEX("2557")),1:"+")  // U+2557 top-right corner
    Set blbox = $SELECT(uni:$C($ZHEX("255A")),1:"+")  // U+255A bottom-left corner
    Set brbox = $SELECT(uni:$C($ZHEX("255D")),1:"+")  // U+255D bottom-right corner
    Set hbar  = $SELECT(uni:$C($ZHEX("2550")),1:"=")  // U+2550 horizontal bar
    Set vbar  = $SELECT(uni:$C($ZHEX("2551")),1:"|")  // U+2551 vertical bar
    Write !, lbox_$TR($J("",44)," ",hbar)_rbox, !
    Write vbar_"  Nested Agents / RLM Pattern Examples      "_vbar, !
    Write blbox_$TR($J("",44)," ",hbar)_brbox, !

    Set hasOpenAI    = (##class(Sample.AI.Utils).GetAPIKey("openai") '= "")
    Set hasAnthropic = (##class(Sample.AI.Utils).GetAPIKey("anthropic") '= "")

    If 'hasOpenAI && 'hasAnthropic {
        Write !, "ERROR: No API key found!", !
        Write !, "Set an API key using one of these methods:", !
        Write "  1. Environment variable (requires IRIS restart):", !
        Write "       export OPENAI_API_KEY='sk-...'", !
        Write "  2. Process-private global (works immediately):", !
        Write "       Set ^||ENV(""OPENAI_API_KEY"") = ""sk-...""", !
        Return $$$ERROR($$$GeneralError, "Missing API key")
    }

    Write !, "API Keys configured:", !
    Write "  OpenAI: ", $SELECT(hasOpenAI:"Yes", 1:"No"), !
    Write "  Anthropic: ", $SELECT(hasAnthropic:"Yes", 1:"No"), !

    Set sc = ..SimpleDelegation()
    If $$$ISERR(sc) Return sc

    Set sc = ..ParallelDelegation()
    If $$$ISERR(sc) Return sc

    Set sc = ..DirectSubagentCreation()
    If $$$ISERR(sc) Return sc

    Write !,!
    Write "=== Optional: Deep Delegation (3 levels) ===", !
    Write "This example is more expensive (multiple nested LLM calls).", !
    Write "Run it manually with: Do ##class(Sample.AI.Examples.NestedAgents).DeepDelegation()", !

    Write !,!
    Write lbox_$TR($J("",44)," ",hbar)_rbox, !
    Write vbar_"  All examples completed!                   "_vbar, !
    Write blbox_$TR($J("",44)," ",hbar)_brbox, !

    Return $$$OK
}

}
