/// Shared utilities for Sample.AI examples.
Class Sample.AI.Utils Extends %RegisteredObject
{

// --- Internal helpers ------------------------------------------------------------

/// Look up an environment variable, trying $System.Util.GetEnviron first,
/// then the process-private global ^||ENV as a fallback.
///
/// The fallback is useful inside irissession.exe / Studio sessions that do not
/// inherit shell environment variables:
///   Set ^||ENV("OPENAI_API_KEY") = "sk-..."
ClassMethod GetEnvKey(varName As %String) As %String [ Private ]
{
    Set val = $System.Util.GetEnviron(varName)
    If val '= "" Return val
    Return $Get(^||ENV(varName))
}

// --- Public API ------------------------------------------------------------------

/// Return an API key for the given provider, or auto-detect from all known providers.
///
/// Arguments:
///   provider      - Optional provider name (openai, anthropic, gemini, grok, meta, nim, deepseek, openrouter, zai/glm, zhipu/bigmodel)
///                   If omitted or "", tries providers in priority order until a key is found.
///   foundProvider - Output. Set to the normalised provider name whose key was returned
///                   
///
/// Returns the key string, or "" if not found.
///
/// Key lookup tries, in order:
///   1. $System.Util.GetEnviron(VAR_NAME)
///   2. $Get(^||ENV(VAR_NAME))
///
/// Examples:
///   // Specific provider
///   Set key = ##class(Sample.AI.Utils).GetAPIKey("openai")
///   If key = "" { Write "OPENAI_API_KEY not set", ! }
///
///   // Auto-detect -- also returns which provider was found
///   Set key = ##class(Sample.AI.Utils).GetAPIKey("", .providerType)
///   If key = "" { Write "No API key found", ! }
///   Else { Write "Using ", providerType, ! }
///
///   // To set a key without a shell restart:
///   Set ^||ENV("OPENAI_API_KEY") = "sk-..."
ClassMethod GetAPIKey(provider As %String = "", Output foundProvider As %String) As %String
{
    Set foundProvider = ""

    // Provider name -> environment variable name
    Set map("anthropic")  = "ANTHROPIC_API_KEY"
    Set map("bigmodel")   = "ZHIPU_API_KEY"
    Set map("deepseek")   = "DEEPSEEK_API_KEY"
    Set map("gemini")     = "GEMINI_API_KEY"
    Set map("glm")        = "ZAI_API_KEY"
    Set map("google")     = "GEMINI_API_KEY"
    Set map("meta")       = "META_API_KEY"
    Set map("nim")        = "NIM_API_KEY"
    Set map("openai")     = "OPENAI_API_KEY"
    Set map("openrouter") = "OPENROUTER_API_KEY"
    Set map("xai")        = "XAI_API_KEY"
    Set map("zai")        = "ZAI_API_KEY"
    Set map("zhipu")      = "ZHIPU_API_KEY"


    // Specific provider requested
    If provider '= "" {
        Set lower = $ZCONVERT(provider, "L")
        Set envVar = $GET(map(lower))
        If envVar = "" Return ""
        Set foundProvider = lower
        Return ..GetEnvKey(envVar)
    }

    // Auto-detect: try explicit providers in priority order
    Set key = ""
    For p = "openai","anthropic","gemini","xai","meta","nim","deepseek","openrouter","zai","zhipu" {
        Set key = ..GetEnvKey($GET(map(p)))
        If key '= "" {
            Set foundProvider = p
            Quit
        }
        Set key = ""
    }
    Return key
}

}
