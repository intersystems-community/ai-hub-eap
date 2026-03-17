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
    If val '= "" Quit val
    Quit $Get(^||ENV(varName))
}

/// Map a provider name to its API key environment variable.
/// Returns "" for providers that do not use a simple API key (vertex, bedrock).
ClassMethod EnvVarForProvider(provider As %String) As %String [ Private ]
{
    Set lower = $ZCONVERT(provider, "L")
    If lower = "openai"    Quit "OPENAI_API_KEY"
    If lower = "anthropic" Quit "ANTHROPIC_API_KEY"
    If lower = "gemini"    Quit "GEMINI_API_KEY"
    If lower = "google"    Quit "GEMINI_API_KEY"
    If lower = "grok"      Quit "GROK_API_KEY"
    If lower = "meta"      Quit "META_API_KEY"
    If lower = "nim"       Quit "NIM_API_KEY"
    Quit ""
}

// --- Public API ------------------------------------------------------------------

/// Return an API key for the given provider, or auto-detect from common providers.
///
/// Arguments:
///   provider      - Optional provider name: openai, anthropic, gemini, grok, meta, nim.
///                   If omitted or "", tries providers in priority order until a key is found.
///   foundProvider - Output. Set to the normalised provider name whose key was returned
///                   (useful when provider="" to learn which was auto-detected).
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
///   // Auto-detect - also returns which provider was found
///   Set key = ##class(Sample.AI.Utils).GetAPIKey("", .providerType)
///   If key = "" { Write "No API key found", ! }
///   Else { Write "Using ", providerType, !}
///
///   // To set a key without a shell restart:
///   Set ^||ENV("OPENAI_API_KEY") = "sk-..."
ClassMethod GetAPIKey(provider As %String = "", Output foundProvider As %String) As %String
{
    Set foundProvider = ""

    // Specific provider requested
    If provider '= "" {
        Set envVar = ..EnvVarForProvider(provider)
        If envVar = "" Quit ""
        Set foundProvider = $ZCONVERT(provider, "L")
        Quit ..GetEnvKey(envVar)
    }

    // Auto-detect: try common providers in priority order
    Set key = ""
    For p = "openai","anthropic","gemini","grok","meta","nim" {
        Set envVar = ..EnvVarForProvider(p)
        Set key = ..GetEnvKey(envVar)
        If key '= "" {
            Set foundProvider = p
            Quit
        }
        Set key = ""
    }
    Quit key
}

}
