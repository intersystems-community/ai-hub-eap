Include %AI

/// Interactive "Programming Language Professor" agent.
/// Uses the Sample.AI.Proglang tool set to answer questions about
/// programming languages from the local database.
///
/// Quick start (Terminal session):
///   Do ##class(Sample.AI.Proglang.Professor).Demo()
Class Sample.AI.Proglang.Professor Extends %AI.Agent
{

Parameter MODELS = "openai=gpt-4o,anthropic=claude-sonnet-4-6,gemini=gemini-2.0-flash,grok=grok-3";

XData INSTRUCTIONS [ MimeType = text/markdown ]
{
# Programming Language Professor

You are an enthusiastic and deeply knowledgeable professor of programming languages.
You have access to a curated local database of programming languages and their creators.

**Always call a tool first before answering any question about a programming language.**
Do not rely on your training data for facts that the database can provide -- use the tools every time.

## Behaviour

- Call ListLanguages at the start of any conversation where the user has not yet specified a language,
  so you know what is in the database
- Call GetLanguage or GetCreator before stating any fact about a language in the database
- When discussing a language, highlight its key design goals, strengths, and typical use cases
- Draw interesting comparisons between languages when relevant
- You have a particular fondness for ObjectScript -- the language of InterSystems IRIS -- and enjoy
  highlighting its unique multi-model database integration, globals, and seamless interoperability
  when it is relevant to the conversation
- If asked about a language not in the database, say so clearly, then answer from your own knowledge
- Format all responses in CommonMark Markdown; use fenced code blocks with a language tag for any code

## Tools available

- **ListLanguages** -- list all languages in the database
- **GetLanguage** -- retrieve full details for a specific language
- **GetCreator** -- look up the creator of a language
- **SearchByTag** -- find languages by category tag (e.g. "systems", "scripting", "web")
- **FindByFilter** -- search by tag and/or year range
- **AddLanguage** -- add a new language record
- **UpdateCreator** -- update the creator information for a language
}

/// Auto-detect provider from environment, set model, and attach the Proglang tool provider.
Method %OnInit() As %Status
{
    If '$ISOBJECT(..Provider) {
        Set key = ##class(Sample.AI.Utils).GetAPIKey("", .providerName)
        If key = "" {
            Return $$$ERROR($$$GeneralError, "No API key found. Set OPENAI_API_KEY, ANTHROPIC_API_KEY, GEMINI_API_KEY, or GROK_API_KEY")
        }
        Set ..Provider = ##class(%AI.Provider).Create(providerName, { "api_key": (key) })
        For i=1:1:$LENGTH(..#MODELS, ",") {
            Set pair = $PIECE(..#MODELS, ",", i)
            If $PIECE(pair, "=", 1) = providerName {
                Set ..Model = $PIECE(pair, "=", 2)
                Quit
            }
        }
    }

    // Attach the programming languages tool provider
    Set sc = ..ToolManager.AddTool(##class(Sample.AI.Proglang.Tools).%New())
    Return sc
}

/// Run an interactive professor session in the terminal.
ClassMethod Demo() As %Status
{
    Set bold    = $C(27)_"[1m"
    Set clr     = $C(27)_"[0m"
    Set cyan    = $C(27)_"[36m"
    Set blue    = $C(27)_"[34m"
    Set yellow  = $C(27)_"[33m"
    Set gray    = $C(27)_"[90m"
    Set green   = $C(27)_"[32m"
    Set red     = $C(27)_"[31m"
    Set line    = $SELECT($ZBITGET($ZVERSION(0),1):$C($ZHEX("2500")),1:"-")

    Write gray, "============================================================", clr, !
    Write bold, cyan, "  Programming Language Professor", clr, !
    Write gray, "  Your guide to the world of programming languages", clr, !
    Write gray, "  Type /help for commands, /exit to leave.", clr, !
    Write gray, "============================================================", clr, !

    Try {
        Set agent = ..%New()
        Set sc = agent.%Init()
        If $$$ISERR(sc) {
            Write red, "Initialization failed: ", $SYSTEM.Status.GetErrorText(sc), clr, !
            Return sc
        }

        Write !, gray, "Provider : ", clr, green, agent.Provider.%ClassName(0), clr, !
        Write gray, "Model    : ", clr, green, agent.Model, clr, !

        Set config = ##class(%AI.System).InitializeConfig(agent.Provider)
        Set session = agent.CreateSession(config)

        Write gray, "Streaming: ", clr,
              $SELECT(config.streaming: green_"enabled", 1: yellow_"disabled"), clr, !
        Write gray, $TR($J("", 60), " ", line), clr, !, !

        Set wallStart = $ZH
        Do $SYSTEM.Process.NewLineRecallContext("Prof")

        Set done = 0
        While 'done {
            Write blue, bold, "You", clr, blue, "> ", clr
            Read input, !

            Set input = $ZSTRIP(input, "<>W")
            If input = "" { Continue }

            Set cmd = $ZCONVERT($PIECE(input, " ", 1), "L")

            If (cmd = "/exit") || (cmd = "/quit") {
                Set done = 1
                Continue
            }

            If (cmd = "/help") {
                Write yellow, "Commands:", clr, !
                Write "  /exit, /quit   Leave the session", !
                Write "  /reset         Clear conversation history", !
                Write "  /stats         Show session token usage", !
                Write "  /tools         List available tools", !
                Continue
            }

            If cmd = "/reset" {
                Set session = agent.CreateSession(config)
                Write gray, "Conversation reset.", clr, !
                Continue
            }

            If cmd = "/stats" {
                Set stats = session.GetStats()
                Set wall = $ZH - wallStart
                Write !, cyan, bold, "Session Stats", clr, !
                Write "  Wall time  : ", $FNUMBER(wall, "", 1), "s", !
                Write "  Tool calls : ", stats."total_tool_calls", !
                Set total = stats."total_prompt_tokens" + stats."total_completion_tokens"
                Write "  Tokens     : ", total, !
                Write "    Prompt   : ", stats."total_prompt_tokens", !
                Write "    Completion: ", stats."total_completion_tokens", !
                Write !
                Continue
            }

            If cmd = "/tools" {
                Set tools = agent.ToolManager.%Discover()
                Write !, yellow, "Available tools:", clr, !
                For i=0:1:tools.%Size()-1 {
                    Set t = tools.%Get(i)
                    Write "  ", green, $E(t.name _ $J("", 20), 1, 20), clr
                    Write gray, t.description, clr, !
                }
                Write !
                Continue
            }

            // Run the agent
            Set startTime = $ZH
            Set thinkingMsg = "Thinking ..."

            If config.streaming {
                Write gray, thinkingMsg, clr
                Write *-3
                Write $C(27)_"[?25l"

                Set renderer = ##class(%AI.System.StreamRenderer).%New()
                Set renderer.ThinkingPrompt = thinkingMsg
                Set renderer.StartTime = startTime

                Set responseObj = agent.StreamChat(session, input, renderer, "OnChunk")
                Do renderer.Flush()

                Write $C(27)_"[?25h"

                If renderer.FirstChunk {
                    Write $C(13), $C(27), "[2K"
                    Write cyan, bold, "Professor", clr, cyan, "> ", clr
                    Write "(No response)", !
                }

            } Else {
                Write gray, thinkingMsg, clr
                Write *-3

                Set feedback = ##class(%AI.System.StreamRenderer).%New()
                Set feedback.ThinkingPrompt = thinkingMsg
                Set feedback.StartTime = startTime

                Set responseObj = agent.Chat(session, input, feedback)

                Write $C(13), $C(27), "[2K"
                Write cyan, bold, "Professor", clr, cyan, "> ", clr
                Do ##class(%AI.System).RenderMarkdown(responseObj.Content)
            }

            Write !
            Set elapsed = $ZH - startTime
            Set stats = session.GetStats()
            Do ##class(%AI.System).PrintTurnSummary(elapsed, stats)
            Write !
        }

    } Catch ex {
        Write $C(27)_"[?25h"
        Write $C(13), $C(27), "[K"
        Write red, "Error: ", ex.DisplayString(), clr, !
        Return ex.AsStatus()
    }

    Write gray, "Goodbye!", clr, !
    Return $$$OK
}

}
