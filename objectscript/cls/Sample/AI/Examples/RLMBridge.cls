/// RLM Bridge Example
/// Demonstrates invoking the Python RLM demo from ObjectScript.
Class Sample.AI.Examples.RLMBridge Extends %RegisteredObject
{

/// Run the Python RLM demo with sample context and print output.
ClassMethod RunPythonRLMDemo(
    query As %String = "Summarize the key goals in 3 bullets.",
    provider As %String = "openai",
    model As %String = "gpt-4o",
    repoRoot As %String = "."
) As %Status
{
    Try {
        Set tmpFile = ##class(%File).TempFilename("rlm_bridge_", ".out")
        If tmpFile = "" {
            Return $$$ERROR($$$GeneralError, "Unable to allocate temp file")
        }

        Set cmd = "cd "_..QuoteShellArg(repoRoot)_" && "_
                  "python python/rlm/run_rlm_demo.py "_
                  "--sample-context "_
                  "--provider "_..QuoteShellArg(provider)_" "_
                  "--model "_..QuoteShellArg(model)_" "_
                  "--query "_..QuoteShellArg(query)_" "_
                  " > "_..QuoteShellArg(tmpFile)_" 2>&1"

        Set rc = $ZF(-100, "/bin/sh", "-lc", cmd)

        Set output = ..ReadAllText(tmpFile)
        Do ##class(%File).Delete(tmpFile)

        Write !, "=== ObjectScript -> Python RLM Bridge ===", !
        Write "Command return code: ", rc, !
        Write "Output:", !, output, !

        If rc '= 0 {
            Return $$$ERROR($$$GeneralError, "Python RLM command failed")
        }

        Return $$$OK
    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

/// Single-quote a shell argument for /bin/sh.
ClassMethod QuoteShellArg(value As %String) As %String [ CodeMode = expression ]
{
    "'" _ $Replace(value, "'", "'""'""'") _ "'"
}

/// Read full file content into a string. Returns empty string if unreadable.
ClassMethod ReadAllText(path As %String) As %String
{
    Set stream = ##class(%Stream.FileCharacter).%New()
    Set sc = stream.LinkToFile(path)
    If $SYSTEM.Status.IsError(sc) {
        Return ""
    }
    Set out = ""
    For {
        Set chunk = stream.Read(32000)
        Quit:chunk=""
        Set out = out _ chunk
    }
    Quit out
}

}
