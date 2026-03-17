/// Multi-Modal AI Example
///
/// This sample demonstrates using images along with text in AI conversations.
/// It shows how to send weather satellite images to vision-capable models.
Class Sample.AI.Examples.MultiModal Extends %RegisteredObject
{

/// Run the multi-modal demo
ClassMethod Run() As %Status
{
    Try {
        Write !, "=== Multi-Modal AI Demo ===", !
        Write "This demo sends a satellite weather image to a vision model", !, !

        Set apiKey = ##class(Sample.AI.Utils).GetAPIKey("openai")
        If apiKey = "" {
            Write "Error: OPENAI_API_KEY not set (try: Set ^||ENV(""OPENAI_API_KEY"") = ""sk-..."")", !
            Return $$$ERROR($$$GeneralError, "Missing API key")
        }

        Set settings = {}
        Do settings.%Set("api_key", apiKey)
        Set provider = ##class(%AI.Provider).Create("openai", settings)
        Write "Provider created: OpenAI", !, !

        Set agent = ##class(%AI.Agent).%New(provider)
        Set agent.Model = "gpt-4o"
        Set agent.SystemPrompt = "You are a helpful weather analyst. Analyze satellite images and describe weather patterns concisely."
        Write "Agent created with model: ", agent.Model, !, !

        Set session = agent.CreateSession()

        Set imageUrl = "https://cdn.star.nesdis.noaa.gov/GOES16/ABI/CONUS/GEOCOLOR/latest.jpg"
        Write "Analyzing NOAA GOES-16 Satellite Image...", !
        Write "Image URL: ", imageUrl, !, !

        Set parts = ##class(%AI.LLM.ContentPart).Build(
            ##class(%AI.LLM.ContentPart).Text("What major weather patterns can you see in this satellite image? Describe briefly."),
            ##class(%AI.LLM.ContentPart).ImageURL(imageUrl)
        )

        Write "Sending multi-modal request...", !, !
        Set response = agent.ChatWithContent(session, parts)

        Write "=== AI Response ===", !
        Write response.Content, !
        Write !, "=== Demo Complete ===", !

        Return $$$OK

    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

/// Simple text-only example for comparison
ClassMethod SimpleExample(provider As %String = "openai", apiKey As %String = "") As %Status
{
    Try {
        Write !, "=== Simple Text Example ===", !

        If apiKey = "" {
            Set apiKey = ##class(Sample.AI.Utils).GetAPIKey(provider)
        }

        Set settings = {}
        Do settings.%Set("api_key", apiKey)
        Set prov = ##class(%AI.Provider).Create(provider, settings)

        Set agent = ##class(%AI.Agent).%New(prov)
        Set agent.Model = "gpt-4o"

        Set session = agent.CreateSession()
        Write "Asking: What's the weather like in Boston?", !, !

        Set response = agent.Chat(session, "What's the weather like in Boston?")
        Write "Response: ", response.Content, !

        Return $$$OK

    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

}
