Include (%AI, %occStatus)

/// %AI.Agent subclass that packages an RLM-style tool workflow.
Class Sample.AI.RLMAgent Extends %AI.Agent
{

Property RLMTools As Sample.AI.Tools.RLM;
Property MaxTurns As %Integer [ InitialExpression = 6 ];

Method ConfigureRLM(context As %String = "") As %Status
{
    Set sc = $$$OK
    Try {
        Set ..RLMTools = ##class(Sample.AI.Tools.RLM).%New()
        $$$ThrowOnError(..RLMTools.Reset(context))

        // Register this specific toolset instance so it keeps per-run state.
        Do ..ToolManager.RegisterLocalTool("Sample.AI.Tools.RLM", ..RLMTools)
        Set ..SystemPrompt = ..RLMSystemPrompt()
    } Catch ex {
        Set sc = ex.AsStatus()
    }

    Return sc
}

Method RunRLM(query As %String, context As %String = "", maxTurns As %Integer = 0) As %DynamicObject
{
    Set out = {}
    Set turns = $Select(maxTurns>0:maxTurns, 1:..MaxTurns)

    Set sc = ..ConfigureRLM(context)
    If $$$ISERR(sc) {
        Do out.%Set("success", 0)
        Do out.%Set("error", $System.Status.GetErrorText(sc))
        Return out
    }

    // Build 122+ uses CreateSession() to inherit provider/model/prompt/tool config
    Set session = ..CreateSession()

    Set last = ""
    For i=1:1:turns {
        Set response = ..Chat(session, query)
        Set last = $Get(response.Content)

        If ..RLMTools.IsFinalized {
            Do out.%Set("success", 1)
            Do out.%Set("finalized", 1)
            Do out.%Set("iterations", i)
            Do out.%Set("answer", ..RLMTools.FinalAnswer)
            Return out
        }

        // Nudge the model toward explicit completion in subsequent turns.
        Set query = "Continue analysis using tools; call finalize(result) when complete."
    }

    Do out.%Set("success", 1)
    Do out.%Set("finalized", 0)
    Do out.%Set("iterations", turns)
    Do out.%Set("answer", last)
    Do out.%Set("note", "Max turns reached before finalize().")

    Return out
}

ClassMethod RLMSystemPrompt() As %String
{
    Quit "You are an RLM-style assistant. Treat context as external and use tools instead of asking for full context in prompt. "_
         "Workflow: inspect_context -> search_context -> store_note -> summarize_notes -> finalize. "_
         "Do not call finalize until you have enough evidence."
}

}
