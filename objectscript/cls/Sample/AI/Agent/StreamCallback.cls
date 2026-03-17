/// Simple streaming callback for demo
Class Sample.AI.Agent.StreamCallback Extends %RegisteredObject
{

/// Called at the start of streaming
Method OnBegin() As %String
{
    // Return empty string to continue
    Quit ""
}

/// Called for each chunk of streamed content
Method OnChunk(chunk As %String)
{
    Write chunk
}

/// Called at the end of streaming
Method OnEnd()
{
    // Optional cleanup
}

}
