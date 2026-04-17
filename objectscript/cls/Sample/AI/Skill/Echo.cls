/// Simple Echo Skill - Demonstrates the Skill pattern
/// This skill echoes back the user's request with some analysis
Class Sample.AI.Skill.Echo Extends %AI.Agent.Skill
{

/// YAML metadata for this skill
XData SUMMARY [ MimeType = "text/yaml" ]
{
name: echo
description: Echo back the user's request with analysis
}

/// SubAgent instructions (markdown format)
XData INSTRUCTIONS [ MimeType = "text/markdown" ]
{
You are an echo assistant. When the user provides input:

1. Acknowledge their input
2. Analyze the sentiment (positive, negative, neutral)
3. Count the words
4. Echo back the original message
5. Respond with a summary in this format:
   - Sentiment: [positive/negative/neutral]
   - Word count: [number]
   - Original: [their message]
}

/// Optional: Helper method exposed as additional tool
Method AnalyzeSentiment(text As %String) As %String
{
    // Simple sentiment analysis
    If text [ "happy" || (text [ "great") || (text [ "excellent") {
        Return "positive"
    } ElseIf text [ "sad" || (text [ "bad") || (text [ "terrible") {
        Return "negative"
    } Else {
        Return "neutral"
    }
}

/// Optional: Another helper method
Method CountWords(text As %String) As %Integer
{
    Set words = $LENGTH($ZSTRIP(text, "<>W"), " ")
    Return words
}

}
