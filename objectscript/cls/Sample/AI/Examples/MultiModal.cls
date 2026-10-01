/// Multi-Modal AI Example
///
/// This sample demonstrates using images along with text in AI conversations.
/// It shows how to send weather satellite images to vision-capable models.
///
/// See ShowGenericMediaUsage() below for %AI.LLM.ContentPart's generic
/// escape hatch -- Document()/Video() accept ANY media type + data, not
/// just PDFs/video, for content this class has no dedicated builder for.
/// See the User Guide's "Multi-Modal Content" section for the full writeup.
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
/// Demonstrates ContentPart's generic escape hatch: Document() accepts ANY
/// media type + data, not just PDFs -- despite the method name (kept for
/// backwards compatibility). Video()/VideoFile() are thin wrappers over the
/// exact same mechanism, not a distinct wire shape.
///
/// Structural only -- no live provider call. No provider wired up in this
/// codebase natively supports inline video today (OpenAI's "file" block
/// and Anthropic's "document" block are both document-oriented), so
/// sending this to ChatWithContent() would currently get a provider-side
/// rejection. This just shows the API shape; swap in a real video file
/// and a live agent/session once a provider adds video support.
ClassMethod ShowGenericMediaUsage() As %Status
{
    Write !, "=== Generic Media Content Part Demo (structural only) ===", !

    // Video() is exactly Document() under the hood -- same "file" wire type.
    Set videoPart = ##class(%AI.LLM.ContentPart).Video("ZmFrZS12aWRlby1ieXRlcw==", "video/mp4", "clip.mp4")
    Write "Video(): ", videoPart.%ToJSON(), !

    // Document() works for ANY media type -- an EPUB here, but it could be
    // anything this class has no named builder for.
    Set epubPart = ##class(%AI.LLM.ContentPart).Document("ZmFrZS1lcHViLWJ5dGVz", "application/epub+zip", "book.epub")
    Write "Document() with a non-PDF media type: ", epubPart.%ToJSON(), !

    Write !, "See the User Guide's ""Multi-Modal Content"" section for the full writeup.", !
    Return $$$OK
}

}
