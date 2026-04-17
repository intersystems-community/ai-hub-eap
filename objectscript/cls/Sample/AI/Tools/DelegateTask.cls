/// Delegate Task Tool - Demonstrates Recursive Language Model (RLM) pattern
/// This tool creates a sub-agent to handle a delegated task
Class Sample.AI.Tools.DelegateTask Extends %AI.Tool
{

/// Tool description for LLM
Parameter DESCRIPTION = "Delegate a task to a specialized sub-agent. Use this when the current task has distinct subtasks that would benefit from focused attention.";

/// Parent agent reference (set by the agent using this tool)
Property ParentAgent As %AI.Agent;

/// Delegate a task to a specialized sub-agent
///
/// Use this when the current task has distinct subtasks that would benefit from focused attention.
/// The sub-agent will have its own conversation context and can use the same tools as the parent.
///
/// Parameters:
/// - task: The task to delegate to the sub-agent (required)
/// - specialistRole: The role/expertise of the sub-agent (e.g., "code reviewer", "writer", "data analyst")
/// - context: Additional context to pass to the sub-agent
Method Execute(task As %String, specialistRole As %String = "", context As %String = "") As %String [ WebMethod ]
{
    Try {
        Write !, "[Delegation] Creating sub-agent for task: ", $EXTRACT(task, 1, 50), "...", !

        // Build system prompt for sub-agent
        Set systemPrompt = "You are a helpful assistant"
        If specialistRole '= "" {
            Set systemPrompt = "You are a " _ specialistRole _ " assistant"
        }
        If context '= "" {
            Set systemPrompt = systemPrompt _ ". Context: " _ context
        }

        Write "[Delegation] Sub-agent role: ", systemPrompt, !

        // Create sub-agent using CreateSubAgent API
        // This will use safe_block_on internally to handle nested runtime contexts
        Set subagent = ##class(%AI.Agent.SubAgent).Create(
            ..ParentAgent,
            systemPrompt,
            "" // No additional config for now
        )

        Write "[Delegation] Sub-agent created, executing task...", !

        // Run the sub-agent on the delegated task
        Set session = subagent.CreateSession()
        Set response = subagent.Run(session, task)

        Write "[Delegation] Sub-agent completed", !
        Write "[Delegation] Response length: ", $LENGTH(response.Content), " characters", !

        Return response.Content

    } Catch ex {
        Return "Error in delegation: " _ ex.DisplayString()
    }
}

}
