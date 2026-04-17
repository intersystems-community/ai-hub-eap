# InterSystems AI Hub - Advanced ObjectScript SDK features

> [!WARNING]
> This document describes a number of *experimental* and advanced features of the AI Hub. 
> These capabilities may change significantly before, or even be excluded from the initial GA release of the AI Hub.
> Please use at your own risk, and do let us know what you think!

## Table of Contents

- [InterSystems AI Hub - Advanced ObjectScript SDK features](#intersystems-ai-hub---advanced-objectscript-sdk-features)
  - [Table of Contents](#table-of-contents)
  - [Policy System](#policy-system)
    - [Authorization Policies](#authorization-policies)
    - [Audit Policies](#audit-policies)
    - [Policy Composition](#policy-composition)
      - [Benefits of Policy Composition](#benefits-of-policy-composition)
      - [How Policy Composition Works](#how-policy-composition-works)
      - [Policy Composition Rules](#policy-composition-rules)
      - [Defining ToolSet-Level Policies](#defining-toolset-level-policies)
      - [Using `<Requirement>` to pass per-tool metadata to policies](#using-requirement-to-pass-per-tool-metadata-to-policies)
      - [Example: Combining Global and ToolSet Policies](#example-combining-global-and-toolset-policies)
  - [Nested Agents (RLM Pattern)](#nested-agents-rlm-pattern)
      - [Use Cases](#use-cases)
      - [Performance Considerations](#performance-considerations)
    - [Creating Sub-Agents](#creating-sub-agents)
    - [Example: Multi-Level Delegation](#example-multi-level-delegation)
    - [Running the Examples](#running-the-examples)
    - [Troubleshooting](#troubleshooting)
  - [Skills (%AI.Agent.Skill)](#skills-aiagentskill)
    - [Defining a Skill (ObjectScript subclass)](#defining-a-skill-objectscript-subclass)
    - [Registering a Skill with an Agent](#registering-a-skill-with-an-agent)
    - [Loading a Skill from an External URI](#loading-a-skill-from-an-external-uri)
    - [Exporting a Skill](#exporting-a-skill)
    - [Skill vs. SubAgent](#skill-vs-subagent)
  - [RAG (Retrieval-Augmented Generation)](#rag-retrieval-augmented-generation)
    - [Embedding Providers](#embedding-providers)
      - [FastEmbed (local, no API key)](#fastembed-local-no-api-key)
      - [OpenAI Embeddings (API key required)](#openai-embeddings-api-key-required)
      - [Custom IRIS Embedding Provider](#custom-iris-embedding-provider)
    - [Vector Store](#vector-store)
      - [Basic Setup](#basic-setup)
      - [Promoted Fields (Indexed Filtering)](#promoted-fields-indexed-filtering)
    - [KnowledgeBase](#knowledgebase)
      - [Building](#building)
      - [Indexing Documents](#indexing-documents)
      - [Re-indexing a Changed Document](#re-indexing-a-changed-document)
      - [Connecting to an Agent](#connecting-to-an-agent)
    - [Complete Example: FastEmbed + IRIS Store](#complete-example-fastembed--iris-store)
    - [Complete Example: OpenAI Embeddings + Promoted Fields](#complete-example-openai-embeddings--promoted-fields)
    - [API Reference](#api-reference)
      - [`%AI.RAG.Embedding` (abstract base)](#airagembedding-abstract-base)
      - [`%AI.RAG.Embedding.FastEmbed`](#airagembeddingfastembed)
      - [`%AI.RAG.Embedding.OpenAI`](#airagembeddingopenai)
      - [`%AI.RAG.VectorStore.IRIS`](#airagvectorstoreiris)
      - [`%AI.RAG.KnowledgeBase`](#airagknowledgebase)



## Policy System

Policies provide governance over tool execution.

### Authorization Policies

Authorization policies let you restrict how tools are run and by whom.

The `%AI.Policy.Authorization` base class provides the `%CanExecute()` method, which should be implemented by its subclasses:

```objectscript
Class %AI.Policy.Authorization Extends %RegisteredObject [ Abstract ]
{
    /// Determine if a tool execution is permitted.
    /// Returns: $$$OK to allow, $$$ERROR(...) to deny
    Method %CanExecute(tool As %String, call As %DynamicObject, metadata As %DynamicObject) As %Status
    {
        // Must be implemented by subclasses
        Return $$$OK
    }
}
```

**Example: Read-Only Policy**

In this example, `MyApp.ReadOnlyPolicy` implements a read-only policy with an implementation of the `%CanExecute()` method, which prevents callers from using write operations:

```objectscript
Class MyApp.ReadOnlyPolicy Extends %AI.Policy.Authorization
{
    Method %CanExecute(tool As %String, call As %DynamicObject, metadata As %DynamicObject) As %Status
    {
        // Extract tool name
        Set toolName = call.name

        // Deny all write/delete operations
        If (toolName = "delete_file") ||
           (toolName = "write_file") ||
           (toolName = "execute_sql") {
            Return $$$ERROR($$$AICoreToolAccessDenied, "Write operations not allowed in read-only mode")
        }

        Return $$$OK
    }
}
```

**Example: Parameter Modification Policy**

In this example, `MyApp.PathSanitizerPolicy` defines a set of whitelisted paths upon instantiation, and its implementation of `%CanExecute()` enforces that whitelist:

```objectscript
Class MyApp.PathSanitizerPolicy Extends %AI.Policy.Authorization
{
    Property AllowedPaths As %List;

    Method %OnNew(allowedPaths As %List) As %Status
    {
        Set ..AllowedPaths = allowedPaths
        Return $$$OK
    }

    Method %CanExecute(tool As %String, call As %DynamicObject, metadata As %DynamicObject) As %Status
    {
        // Check for path parameter in arguments
        If call.arguments.%IsDefined("path") {
            Set path = call.arguments.path
            Set allowed = 0

            // Check if path starts with an allowed prefix
            Set ptr = 0
            While $LISTNEXT(..AllowedPaths, ptr, allowedPath) {
                If $EXTRACT(path, 1, $LENGTH(allowedPath)) = allowedPath {
                    Set allowed = 1
                    Quit
                }
            }

            If 'allowed {
                // Modify the call to use first allowed path
                // The system will automatically detect this modification
                Set call.arguments.path = $LISTGET(..AllowedPaths, 1)
            }
        }

        Return $$$OK
    }
}
```

**Attaching Authorization Policies**

After you define an authorization policy class, you can attach it to a `ToolManager` with `SetAuthPolicy()`:

```objectscript
// Single policy
Do agent.ToolManager.SetAuthPolicy(##class(MyApp.ReadOnlyPolicy).%New())

// Policy with parameters
Set paths = $LISTBUILD("/data", "/tmp", "/logs")
Set policy = ##class(MyApp.PathSanitizerPolicy).%New(paths)
Do agent.ToolManager.SetAuthPolicy(policy)
```

### Audit Policies

Audit policies track and log tool executions. The `%AI.Policy.Audit` base class provides the `%LogExecution()` method, which should be implemented by its subclasses:

```objectscript
Class %AI.Policy.Audit Extends %RegisteredObject [ Abstract ]
{
    Method %LogExecution(
        call As %DynamicObject,
        metadata As %DynamicObject,
        result As %DynamicObject,
        duration As %Integer,
        status As %Status)
    {
        // Must be implemented by subclasses
    }
}
```

**Example: Database Audit Log**

In this example, each entry in the audit log is represented by an instance of `MyApp.ToolAuditLog`. `MyApp.DatabaseAudit` implements the `%LogExecution()` method to create instances of `MyApp.ToolAuditLog` and record details of the tool execution to its properties:

```objectscript
Class MyApp.DatabaseAudit Extends %AI.Policy.Audit
{
    Method %LogExecution(call, metadata, result, duration, status)
    {
        Set log = ##class(MyApp.ToolAuditLog).%New()
        Set log.Timestamp = $ZDATETIME($HOROLOG, 3)
        Set log.ToolName = call.name
        Set log.Arguments = call.arguments.%ToJSON()
        Set log.Success = $$$ISOK(status)
        Set log.DurationMs = duration
        Set resultJson = result.%ToJSON()
        Set log.ResultSize = $LENGTH(resultJson)

        If $$$ISOK(status) {
            Set log.ResultPreview = $EXTRACT(resultJson, 1, 200)
        } Else {
            Set log.Error = $SYSTEM.Status.GetErrorText(status)
        }

        Do log.%Save()
    }
}
```

**Example: Metrics Collector**

In this example, `MyApp.MetricsAudit` tracks various tool execution metrics in its properties, and implements the `%LogExecution()` method to update those metrics:

```objectscript
Class MyApp.MetricsAudit Extends %AI.Policy.Audit
{
    Property TotalCalls As %Integer [ InitialExpression = 0 ];
    Property TotalErrors As %Integer [ InitialExpression = 0 ];
    Property TotalDuration As %Float [ InitialExpression = 0 ];
    Property ByTool As %DynamicObject;

    Method %OnNew() As %Status
    {
        Set ..ByTool = {}
        Return $$$OK
    }

    Method %LogExecution(call, metadata, result, duration, status)
    {
        Set ..TotalCalls = ..TotalCalls + 1
        Set ..TotalDuration = ..TotalDuration + duration

        If $$$ISERR(status) {
            Set ..TotalErrors = ..TotalErrors + 1
        }

        // Per-tool stats
        Set toolName = call.name
        If '..ByTool.%IsDefined(toolName) {
            Do ..ByTool.%Set(toolName, {
                "calls": 0,
                "errors": 0,
                "totalMs": 0
            })
        }

        Set stats = ..ByTool.%Get(toolName)
        Set stats.calls = stats.calls + 1
        Set stats.totalMs = stats.totalMs + duration
        If $$$ISERR(status) {
            Set stats.errors = stats.errors + 1
        }
    }

    Method PrintReport()
    {
        Write "Total tool calls: ", ..TotalCalls, !
        Write "Total errors: ", ..TotalErrors, !
        Write "Success rate: ", $FNUMBER((..TotalCalls - ..TotalErrors) / ..TotalCalls * 100, "", 1), "%", !
        Write "Avg duration: ", $FNUMBER(..TotalDuration / ..TotalCalls, "", 1), "ms", !, !

        Write "By Tool:", !
        Set iter = ..ByTool.%GetIterator()
        While iter.%GetNext(.toolName, .stats) {
            Set avg = stats.totalMs / stats.calls
            Write "  ", toolName, ": ", stats.calls, " calls, ", $FNUMBER(avg, "", 1), "ms avg", !
        }
    }
}
```

**Attaching Audit Policies:**

After you define an audit policy class, you can attach it to a `ToolManager` with `SetAuditPolicy()`:

```objectscript
Do agent.ToolManager.SetAuditPolicy(##class(MyApp.DatabaseAudit).%New())
```

### Policy Composition

InterSystems AI Hub supports **Policy Composition**, which allows policies to be defined at two levels:

1. **Global Policies** - Attached to the ToolManager, apply to all tools
2. **ToolSet Policies** - Defined in ToolSet XML, apply only to that ToolSet's tools

This enables layered governance where organization-wide policies (global) combine with tool-specific policies (ToolSet).


Policy classes must:
1. Extend the appropriate base class (`%AI.Policy.Authorization`, `%AI.Policy.Audit`, or `%AI.Policy.Discovery`)
2. Extend `%XML.Adaptor` for automatic XML deserialization
3. Use `XMLPROJECTION = "ELEMENT"` or `"ATTRIBUTE"` for properties
4. Implement required policy methods

#### Benefits of Policy Composition

1. **Separation of Concerns**: Organization-wide policies (global) separate from tool-specific policies (ToolSet)
2. **Declarative Configuration**: Policies configured in XML alongside tool definitions
3. **Reusable Policy Classes**: Same policy class can be used across multiple ToolSets with different configurations
4. **Type Safety**: XML framework provides type-safe property mapping
5. **Automatic Instantiation**: No manual policy creation required
6. **Layered Security**: Defense in depth with multiple policy layers

#### How Policy Composition Works

At compile time:
1. The ToolSet compiler parses the `<Policies>` block from the XML definition
2. Extracts the `Class` attribute from each policy element
3. Generates a `%OnNew()` method that deserializes the policy XML using `%XML.Reader.Correlate()`
4. Instantiates policy objects and stores them in ToolSet properties

At runtime:
1. When the ToolSet is registered with ToolManager, its policies are passed to the Rust layer
2. The Rust ToolManager stores both global and ToolSet-level policies
3. During tool execution, policies are applied in sequence

#### Policy Composition Rules

| Policy Type | Execution Order | Composition Logic |
|-------------|-----------------|-------------------|
| **Authorization** | 1. Global<br/>2. ToolSet | Both must allow (AND) |
| **Audit** | 1. Global<br/>2. ToolSet | Both used (Union) |
| **Discovery** | 1. ToolSet<br/>2. Global (fallback) | ToolSet overrides |

**Authorization Example**
```
Tool Call: ReadFile(path="/etc/passwd")
    ↓
Global Auth Policy: Check user role → Allow
    ↓
ToolSet Auth Policy: Check path is in allowed list → Deny (not in /data or /tmp)
    ↓
Result: DENIED (ToolSet policy blocked it)
```

**Audit Example**
```
Tool Call: ReadFile(path="/data/report.txt") → Success
    ↓
Global Audit Policy: Log to central database
    ↓ (parallel)
ToolSet Audit Policy: Log to file-specific log
    ↓
Result: Both logs written independently
```

#### Defining ToolSet-Level Policies

Policies can be configured declaratively in ToolSet XML using the `<Policies>` block:

```objectscript
Class MyApp.SecureFileTools Extends %AI.ToolSet
{
    XData Definition [ MimeType = application/xml ]
    {
        <ToolSet Name="FileSystemTools">
            <Description>Secure file system operations.</Description>

            <!-- Policy Definitions -->
            <Policies>
                <!-- Authorization Policy with Configuration -->
                <Authorization Class="MyApp.PathSanitizerPolicy">
                    <AllowedPath>/data</AllowedPath>
                    <AllowedPath>/tmp</AllowedPath>
                    <Strict>true</Strict>
                </Authorization>

                <!-- Audit Policy -->
                <Audit Class="MyApp.FileAuditPolicy">
                    <LogLevel>INFO</LogLevel>
                </Audit>
            </Policies>

            <!-- Tool Definitions -->
            <Tool Name="ReadFile" Method="ReadFile">
                <Description>Read a file from the filesystem.</Description>
            </Tool>

            <Tool Name="WriteFile" Method="WriteFile">
                <Description>Write content to a file.</Description>
            </Tool>
        </ToolSet>
    }

    Method ReadFile(path As %String) As %String
    {
        // Read file implementation
        Return ##class(%Stream.FileCharacter).%New().Read(path)
    }

    Method WriteFile(path As %String, content As %String) As %String
    {
        // Write file implementation
        Set file = ##class(%Stream.FileCharacter).%New()
        Do file.%Open(path)
        Do file.Write(content)
        Do file.%Save()
        Return "File written successfully"
    }
}
```

**Example XML-Enabled Policy:**

```objectscript
Class MyApp.PathSanitizerPolicy Extends (%AI.Policy.Authorization, %XML.Adaptor)
{
    Parameter XMLNAME = "Authorization";

    /// List of allowed path prefixes
    Property AllowedPath As list Of %String(
        MAXLEN = "",
        XMLITEMNAME = "AllowedPath",
        XMLPROJECTION = "ELEMENT"
    );

    /// If true, deny access to paths not in AllowedPath list
    Property Strict As %Boolean(XMLPROJECTION = "ELEMENT");

    Method %CanExecute(tool As %String, call As %DynamicObject, metadata As %DynamicObject) As %Status
    {
        Set path = call.arguments.%Get("path", "")
        If path = "" Return $$$OK

        // Check against allowed paths
        Set allowed = 0
        For i=1:1:..AllowedPath.Count() {
            Set allowedPrefix = ..AllowedPath.GetAt(i)
            If $E(path, 1, $L(allowedPrefix)) = allowedPrefix {
                Set allowed = 1
                Quit
            }
        }

        If 'allowed && ..Strict {
            Return $$$ERROR($$$AICoreToolAccessDenied, "Path not in allowed list: "_path)
        }

        // Sanitize path
        Set sanitized = ##class(%File).NormalizeFilename(path)
        If sanitized '= path {
            Set call.arguments.path = sanitized
        }

        Return $$$OK
    }
}
```

#### Using `<Requirement>` to pass per-tool metadata to policies

`<Requirement>` elements inside `<Include>` attach arbitrary key-value metadata to each included tool. Both `%CanList` (visibility) and `%CanExecute` (execution) receive this metadata as their second argument — letting a single policy class make tool-specific decisions without needing a separate policy class per tool:

```objectscript
Class MyApp.HubTools Extends %AI.ToolSet
{
    XData Definition [ MimeType = application/xml ]
    {
        <ToolSet Name="HubTools">
            <Policies>
                <Authorization Class="MyApp.AccessLevelPolicy"/>
            </Policies>

            <!-- Public tools: no requirement needed -->
            <Include Class="MyApp.PublicTools"/>

            <!-- Restricted tools: stamp AccessLevel=admin on each -->
            <Include Class="MyApp.AdminTools">
                <Requirement Name="AccessLevel" Value="admin"/>
            </Include>
        </ToolSet>
    }
}
```

The policy reads `metadata.%Get("AccessLevel")` and compares it to the current user's role:

```objectscript
Class MyApp.AccessLevelPolicy Extends %AI.Policy.Authorization
{
    Property UserRole As %String;

    /// Hide tools whose AccessLevel exceeds the user's role.
    Method %CanList(tool As %String, metadata As %DynamicObject) As %Boolean
    {
        Set required = metadata.%Get("AccessLevel")
        If (required = "") Return 1                // no requirement = always visible
        If (required = "admin") && (..UserRole '= "admin") Return 0
        Return 1
    }

    Method %CanExecute(tool As %String, call As %DynamicObject, metadata As %DynamicObject) As %Status
    {
        Set required = metadata.%Get("AccessLevel")
        If (required = "admin") && (..UserRole '= "admin") {
            Return $$$ERROR($$$AICoreToolAccessDenied, "Admin role required")
        }
        Return $$$OK
    }
}
```

Multiple `<Requirement>` elements can be combined on a single `<Include>`:

```xml
<Include Class="MyApp.FinanceTools">
    <Requirement Name="AccessLevel" Value="finance"/>
    <Requirement Name="AuditRequired" Value="1"/>
    <Requirement Name="DataClassification" Value="confidential"/>
</Include>
```

All requirements are delivered as a single `%DynamicObject` — `metadata.%Get("AuditRequired")`, `metadata.%Get("DataClassification")`, etc.


#### Example: Combining Global and ToolSet Policies

```objectscript
// Create agent with global policies
Set provider = ##class(%AI.Provider).Create("openai", {"api_key": apiKey})
Set agent = ##class(%AI.Agent).%New(provider)

// Set global authorization (organization-wide RBAC)
Set globalAuth = ##class(MyApp.RoleBasedAuth).%New()
Set globalAuth.RequiredRole = "DataAccess"
Do agent.ToolManager.SetAuthPolicy(globalAuth)

// Set global audit (central compliance logging)
Set globalAudit = ##class(MyApp.CentralAudit).%New()
Do agent.ToolManager.SetAuditPolicy(globalAudit)

// Register ToolSet with its own policies
// SecureFileTools has PathSanitizerPolicy and FileAuditPolicy defined in XML
Do agent.UseToolSet("MyApp.SecureFileTools")

// Now when file tools are executed:
// 1. Global RoleBasedAuth checks user has "DataAccess" role
// 2. ToolSet PathSanitizerPolicy checks path is allowed
// 3. Tool executes
// 4. Global CentralAudit logs to database
// 5. ToolSet FileAuditPolicy logs to file-specific log
```



## Nested Agents (RLM Pattern)

The **Recursive Language Model (RLM)** pattern lets parent agents break down tasks hierarchically and delegate tasks to specialized sub-agents.

While spawned by the parent agent, the sub-agent acts independently with hits own system prompt, model, and conversation context. Sub-agent can even spawn their own sub-agents for further delegation.

#### Use Cases

**1. Complex Task Decomposition**
- Break large tasks into manageable subtasks
- "Design a complete system" → delegate to API designer, data modeler, security specialist

**2. Specialized Processing**
- Route subtasks to agents with specific expertise
- Code review → "code reviewer" sub-agent
- Technical writing → "technical writer" sub-agent
- Data analysis → "data analyst" sub-agent

**3. Hierarchical Workflows**
- Multi-level delegation for complex projects
- Project Manager → Technical Leads → Individual Contributors

**4. Parallel Processing (Conceptual)**
- Delegate independent tasks to separate sub-agents
- Tasks are executed sequentially but represent logically parallel concerns

#### Performance Considerations

- **Cost**: Each sub-agent is a separate LLM call (API cost multiplies)
- **Latency**: Nested calls are sequential
- **Depth**: Deeper nesting = higher cost and latency
- **Trade-off**: Better task decomposition vs. execution time

**Best Practices:**
1. Use delegation strategically - not all tasks need sub-agents
2. Keep nesting shallow - 2-3 levels max in most cases
3. Use smaller/cheaper models for sub-agents when appropriate (gpt-4o-mini, claude-haiku)
4. Give sub-agents focused, specific roles and instructions
5. Monitor costs - deep delegation can be expensive

### Creating Sub-Agents

**Method 1: Using the DelegateTask Tool**

The `Sample.AI.Tools.DelegateTask` tool instructs the agent to create sub-agents dynamically:

```objectscript
// Create parent agent with delegation capability
Set agent = ##class(%AI.Agent).%New(provider)
Set agent.Model = "gpt-4"
Set agent.SystemPrompt = "You are a project manager. Break down complex tasks and delegate using delegate_task."

// Register the DelegateTask tool
Set delegateTool = ##class(Sample.AI.Tools.DelegateTask).%New()
Set delegateTool.ParentAgent = agent
Do agent.ToolManager.AddTool(delegateTool)

// Create session
Set session = agent.CreateSession()

// Give parent a complex task - it will delegate automatically
Set task = "Write a blog post about AI agents with introduction, 3 main points, and conclusion."
Set response = agent.Chat(session, task)
// Parent may delegate writing to a specialized "writer" sub-agent
```

**Method 2: Programmatic Sub-Agent Creation**

`CreateSubAgent()` creates a child agent that inherits the parent's provider, model, temperature, and `MaxIterations`. Only the system prompt changes:

```objectscript
// Create parent agent
Set parentAgent = ##class(%AI.Agent).%New(provider)
Set parentAgent.Model = "gpt-4"

// Create a sub-agent that shares the parent's provider (no extra API connection)
Set poetAgent = parentAgent.CreateSubAgent("You are a creative poet. Write short, beautiful poems.")

// Add tools specific to this sub-agent's role
Do poetAgent.ToolManager.AddTool("iris:MyApp.PoemTools")

// Run the sub-agent
Set session = poetAgent.CreateSession()
Set response = poetAgent.Run(session, "Write a haiku about the ocean")
Write response.Content
```

**Monitoring `Run()` progress with callbacks:**

Pass any object with `OnIterationStart()` and/or `OnIterationComplete()` methods as the fourth argument to `Run()`. The framework calls them on each iteration, letting you log progress, implement timeouts, or update a UI:

```objectscript
Class MyApp.AgentMonitor Extends %RegisteredObject
{
    Property TotalTokens As %Integer [ InitialExpression = 0 ];
    Property TokenBudget As %Integer [ InitialExpression = 10000 ];

    /// Called before each LLM invocation.
    /// iteration   - current iteration number (1-based)
    /// maxIter     - the Run() iteration limit (use for progress math)
    /// session     - live session; inspect GetStats() for pre-iteration state
    Method OnIterationStart(iteration As %Integer, maxIter As %Integer, session As %AI.Agent.Session)
    {
        Set stats = session.GetStats()
        Write "[", iteration, "/", maxIter, "] Thinking... ",
              "(context: ", stats."current_context_tokens", " tokens)", !
    }

    /// Called after each LLM response + tool execution round.
    /// response    - full %AI.LLM.Response: .Content, .ToolCalls, .Usage, .HasToolCalls()
    /// session     - live session after this iteration; stats are updated
    Method OnIterationComplete(iteration As %Integer, response As %AI.LLM.Response, session As %AI.Agent.Session)
    {
        // Log which tools were called this turn
        If response.HasToolCalls() {
            Set iter = response.ToolCalls.%GetIterator()
            While iter.%GetNext(.k, .call) {
                Write "  → ", call.name, !
            }
        }

        // Accumulate token cost and enforce a budget
        Set ..TotalTokens = ..TotalTokens + response.Usage."total_tokens"
        If ..TotalTokens > ..TokenBudget {
            $$$ThrowStatus($$$ERROR($$$GeneralError,
                "Token budget exceeded: "_..TotalTokens_" > "_..TokenBudget))
        }
    }
}

// Callback is optional — omit the fourth argument to run without monitoring
Set monitor = ##class(MyApp.AgentMonitor).%New()
Set monitor.TokenBudget = 5000
Set response = agent.Run(session, "Analyse this dataset and summarise findings", 10, monitor)
```

Neither method is required — define only the one you need. The framework checks at runtime whether each method exists on the callback object.


### Example: Multi-Level Delegation

```objectscript
ClassMethod DesignAPIExample() As %Status
{
    // Setup
    Set apiKey = ##class(Sample.AI.Utils).GetAPIKey("", .providerType)
    If apiKey = "" { Write "No API key found", ! Return $$$ERROR($$$GeneralError, "Missing API key") }
    Set provider = ##class(%AI.Provider).Create(providerType, {"api_key": (apiKey)})

    // Level 1: Senior architect
    Set architect = ##class(%AI.Agent).%New(provider)
    Set architect.Model = "gpt-4"
    Set architect.SystemPrompt = "You are a senior architect. Break down complex projects and delegate to specialists."

    // Add delegation tool to architect
    Set delegateTool = ##class(Sample.AI.Tools.DelegateTask).%New()
    Set delegateTool.ParentAgent = architect
    Do architect.ToolManager.AddTool(delegateTool)

    // Create session
    Set session = architect.CreateSession()

    // Complex task requiring multiple delegation levels
    Set task = "Design a REST API for a todo application. Include endpoint design, data models, and implementation plan."

    // Execute - architect may delegate to:
    //   - API design specialist (Level 2)
    //   - Data modeling specialist (Level 2)
    //   Each specialist may create their own sub-agents (Level 3)
    Set response = architect.Chat(session, task)

    Write response.Content

    Return $$$OK
}
```

### Running the Examples

The framework includes comprehensive nested agent examples in `Sample.AI.Examples.NestedAgents`:

```objectscript
// Run all examples
Do ##class(Sample.AI.Examples.NestedAgents).RunAll()

// Individual examples:

// 1. Simple delegation - Parent → Sub-agent
Do ##class(Sample.AI.Examples.NestedAgents).SimpleDelegation()

// 2. Parallel delegation - Multiple independent subtasks
Do ##class(Sample.AI.Examples.NestedAgents).ParallelDelegation()

// 3. Deep delegation - 3-level nesting
Do ##class(Sample.AI.Examples.NestedAgents).DeepDelegation()

// 4. Programmatic creation - Direct sub-agent creation
Do ##class(Sample.AI.Examples.NestedAgents).DirectSubagentCreation()
```

### Troubleshooting

**Sub-agent not receiving context**
This is expected behavior; each sub-agent is **independent** and therefore doesn't automatically inherit the parent agent's session context. If you need sub-agents to access this context, you can do one of the following:
- Pass context via the `context` parameter in `DelegateTask()`
- Include necessary context in the delegated task description

**High API costs**
Deep delegation or many parallel delegations multiply API costs. To mitigate this:
- Use smaller models for sub-agents (gpt-4o-mini, claude-haiku)
- Limit delegation depth
- Cache results when possible

## Skills (%AI.Agent.Skill)

A **Skill** is a declaratively-defined sub-agent that can be registered as a tool. It extends `%AI.Agent.SubAgent` and adds structured metadata (name, description, parameters, dependencies) via XData blocks. When a parent agent registers a Skill as a tool, it appears with the Skill's description so the LLM knows what it does and when to invoke it.

### Defining a Skill (ObjectScript subclass)

```objectscript
Class MyApp.Skill.SummarizeDocument Extends %AI.Agent.Skill
{
    /// ToolSet classes to add to this skill's sub-agent (comma-separated)
    Parameter TOOLS = "MyApp.Tools.FileSystem";

    XData SUMMARY [ MimeType = "text/yaml" ]
    {
name: summarize-document
description: Summarize a document from the filesystem. Returns a concise summary.
parameters:
  - name: userRequest
    description: Path and any summarization instructions
    type: string
    required: true
tags:
  - summarization
  - documents
    }

    XData INSTRUCTIONS [ MimeType = "text/markdown" ]
    {
You are a document summarization specialist.
When given a file path, read the file and produce a clear, concise summary.
Focus on key points and main conclusions. Keep the summary under 200 words.
    }
}
```

**Key elements:**
- `TOOLS` parameter — comma-separated ToolSet class names added to the skill's sub-agent automatically
- `XData SUMMARY` — YAML metadata: `name`, `description`, `parameters`, `tags`, `dependencies`, `author`, `version`
- `XData INSTRUCTIONS` — Markdown system prompt for the sub-agent
- The `description` field becomes the LLM-visible tool description when the skill is registered with a parent agent

### Registering a Skill with an Agent

```objectscript
Set apiKey = ##class(Sample.AI.Utils).GetAPIKey("", .providerType)
Set provider = ##class(%AI.Provider).Create(providerType, {"api_key": (apiKey)})

Set agent = ##class(%AI.Agent).%New(provider)
Set agent.Model = provider.GetDefaultModel()
Set agent.SystemPrompt = "You are a project assistant. Use your skills to handle specialized tasks."

// Register skill as a tool — the LLM sees its description and calls it when appropriate
Set skill = ##class(MyApp.Skill.SummarizeDocument).%New()
Set skill.ParentAgent = agent
Do agent.ToolManager.AddTool(skill)

Set session = agent.CreateSession()
Set response = agent.Chat(session, "Summarize the file at /data/report.pdf")
Write response.Content
```

### Loading a Skill from an External URI

Skills can also be loaded from external `SKILL.md` files — useful for sharing skills across projects or loading from a git repository:

```objectscript
// From a git repository
Set skill = ##class(%AI.Agent.Skill).GetSkillFromURI("https://github.com/myorg/skills", "summarize")

// From a local path
Set skill = ##class(%AI.Agent.Skill).GetSkillFromURI("file:///opt/skills/summarize")

// Register with agent as above
Set skill.ParentAgent = agent
Do agent.ToolManager.AddTool(skill)
```

A `SKILL.md` file uses YAML front matter followed by Markdown instructions:

```markdown
---
name: summarize-document
description: Summarize a document from the filesystem.
parameters:
  - name: userRequest
    description: Path and summarization instructions
    type: string
    required: true
tags:
  - summarization
---

You are a document summarization specialist.
Read the file at the given path and produce a concise summary under 200 words.
```

### Exporting a Skill

```objectscript
Set skill = ##class(MyApp.Skill.SummarizeDocument).%New()

// Export to a directory (creates /opt/skills/summarize-document/SKILL.md)
Set path = skill.ExportSkill("/opt/skills")
Write "Exported to: ", path, !

// Export to a specific file
Set path = skill.ExportSkill("/opt/skills/summarize.md")

// Export to a stream
Set stream = ##class(%Stream.GlobalCharacter).%New()
Do skill.ExportSkill(stream)
```

### Skill vs. SubAgent

| | `%AI.Agent.SubAgent` | `%AI.Agent.Skill` |
|---|---|---|
| **Definition** | Subclass + `GetSystemPrompt()` override | Subclass + `SUMMARY`/`INSTRUCTIONS` XData |
| **Tool description** | Derived from system prompt | From `SUMMARY.description` |
| **Tool loading** | Manual `AddTool()` | `TOOLS` parameter + `AddTool()` |
| **External source** | No | Yes — `GetSkillFromURI()` |
| **Export** | No | Yes — `ExportSkill()` |

Use `%AI.Agent.SubAgent` for simple programmatic sub-agents. Use `%AI.Agent.Skill` when you want structured, reusable, shareable skill definitions with rich metadata.



## RAG (Retrieval-Augmented Generation)

:warning: This area will undergo significant change in a future version

RAG lets an AI agent retrieve relevant passages from a knowledge base before generating a response. Rather than relying only on its training data, the agent first searches a vector store for matching chunks, then uses those chunks as context when answering.

The InterSystems IRIS AI RAG stack consists of three objects that you build in order:

1. **`%AI.RAG.Embedding`** — converts text to dense vectors
2. **`%AI.RAG.VectorStore.IRIS`** — persists vectors in an IRIS SQL table
3. **`%AI.RAG.KnowledgeBase`** — combines the above and exposes a `search_<name>` tool

### Embedding Providers

#### FastEmbed (local, no API key)

`%AI.RAG.Embedding.FastEmbed` runs the AllMiniLML6V2 ONNX model entirely in-process via the Rust bridge. It produces 384-dimensional vectors and has no external dependencies.

```objectscript
Set emb = ##class(%AI.RAG.Embedding.FastEmbed).Create()
// emb is ready immediately — %token is set in %OnInit
```

#### OpenAI Embeddings (API key required)

`%AI.RAG.Embedding.OpenAI` reuses the credentials from an existing `%AI.Provider` instance. The OpenAI `/embeddings` endpoint is called by the Rust bridge; no extra HTTP configuration is needed.

```objectscript
Set apiKey = ##class(Sample.AI.Utils).GetAPIKey("openai")
Set provider = ##class(%AI.Provider).CreateOpenAI(apiKey)
Set emb = ##class(%AI.RAG.Embedding.OpenAI).Create(provider)
// Produces 1536-dimensional vectors using text-embedding-3-small
```

#### Custom IRIS Embedding Provider

Extend `%AI.RAG.Embedding` and implement `EmbedBatch()`. The method receives a `%DynamicArray` of strings and must return a `%DynamicArray` of float arrays.

```objectscript
Class MyApp.RAG.MyEmbedder Extends %AI.RAG.Embedding
{

Parameter DIMENSIONS = 512;
Parameter MODELNAME  = "my-model-v1";

ClassMethod Create() As MyApp.RAG.MyEmbedder
{
    Set obj = ##class(MyApp.RAG.MyEmbedder).%New()
    $$$ThrowOnError(obj.%OnInit())
    Return obj
}

Method %OnInit() As %Status
{
    Set i%Dimensions      = ..#DIMENSIONS
    Set i%ModelName       = ..#MODELNAME
    Set ..OptimalBatchSize = 32
    Return $$$OK
}

Method EmbedBatch(texts As %DynamicArray) As %DynamicArray
{
    Set results = []
    Set iter = texts.%GetIterator()
    While iter.%GetNext(.k, .text) {
        // Replace with your embedding call (REST, Python bridge, etc.)
        Set vec = ..CallMyModel(text)
        Do results.%Push(vec)
    }
    Return results
}

}
```

Register the provider before passing it to `KnowledgeBase.Build()`:

```objectscript
Set emb = ##class(MyApp.RAG.MyEmbedder).%New()
$$$ThrowOnError(emb.Register())
```

> **Note:** `%AI.RAG.Embedding.FastEmbed` and `%AI.RAG.Embedding.OpenAI` call `Register()` automatically. You only need to call `Register()` explicitly for custom subclasses.

---

### Vector Store

`%AI.RAG.VectorStore.IRIS` creates and manages an IRIS SQL table. DDL runs in ObjectScript (`Build()`); all DML (inserts, similarity search, deletes) runs in Rust for performance.

#### Basic Setup

```objectscript
Set vs = ##class(%AI.RAG.VectorStore.IRIS).%New()
Set vs.TableName  = "MyApp.ProductDocs"  // fully-qualified SQL name
Set vs.Dimensions = 384                  // must match the embedding model
Set vs.ModelName  = "AllMiniLML6V2"      // informational, stored in _Config table
$$$ThrowOnError(vs.Build())
```

`Build()` creates two tables if they do not already exist:

| Table | Purpose |
|---|---|
| `MyApp.ProductDocs` | Stores `id`, `text`, `vector`, `metadata`, `source` |
| `MyApp.ProductDocs_Config` | Records model name and dimensions for mismatch detection |

#### Promoted Fields (Indexed Filtering)

Promoted fields are metadata values that are copied to dedicated SQL columns so they can be used in indexed `WHERE` clauses during similarity search.

```objectscript
Set fields = [
    {"name": "version",  "type": "varchar(20)", "description": "Product version tag"},
    {"name": "category", "type": "varchar(64)", "description": "Document category"},
    {"name": "priority", "type": "integer",     "description": "Sort priority"}
]
$$$ThrowOnError(vs.Build(fields))
```

Supported field types: `varchar(N)`, `integer`, `float`, `boolean`.

The `source` column is always created automatically — you do not need to declare it.

> **Calling `Build()` on an existing table is safe.** The SQL uses `CREATE TABLE IF NOT EXISTS`. The `_Config` table check will raise an error if the model name or dimensions have changed, protecting you from accidentally mixing embeddings from incompatible models.

---

### KnowledgeBase

`%AI.RAG.KnowledgeBase` is the central object. It wires the embedding model and vector store together, manages document chunking, and exposes a `search_<name>` tool to agents.

#### Building

```objectscript
Set kb = ##class(%AI.RAG.KnowledgeBase).%New("search_docs", "IRIS product documentation")
Set kb.TopK = 5  // results returned per search (default: 5)
$$$ThrowOnError(kb.Build(emb, vs))
```

The first argument to `%New()` becomes the tool name (`search_docs`). The second is the description the LLM reads to decide when to call the tool.

#### Indexing Documents

```objectscript
// Single document
$$$ThrowOnError(kb.AddDocument(
    "IRIS is a high-performance multimodel database.",
    {"source": "intro.txt", "category": "overview"}
))

// Batch — more efficient for large corpora
Set docs = [
    ["IRIS supports SQL, objects, and documents.", {"source": "models.txt"}],
    ["The %SQL.Statement class executes dynamic SQL.", {"source": "sql.txt"}]
]
Set chunks = kb.AddDocuments(docs)
Write "Indexed ", chunks, " chunks", !
```

The `source` key in the metadata is used to assign deterministic chunk IDs of the form `<source>-chunk-<n>`. This is required for correct re-indexing.

#### Re-indexing a Changed Document

When a document's content changes, call `ReindexDocument()` to atomically replace all its old chunks with new ones. This avoids stale duplicates accumulating in the store.

```objectscript
Set newText = "Updated introduction to IRIS 2025..."
Set chunks = kb.ReindexDocument("intro.txt", newText, {"category": "overview"})
Write "Re-indexed with ", chunks, " chunks", !
```

#### Connecting to an Agent

```objectscript
$$$ThrowOnError(kb.AddToAgent(agent))
// The agent's LLM can now call search_docs("query text")
```

Or, if you manage the `ToolManager` directly:

```objectscript
$$$ThrowOnError(kb.AddToManager(agent.ToolManager))
```

---

### Complete Example: FastEmbed + IRIS Store

```objectscript
ClassMethod FastEmbedDemo() As %Status
{
    Try {
        // 1. Embedding model — local, no API key needed
        Set emb = ##class(%AI.RAG.Embedding.FastEmbed).Create()

        // 2. Vector store — IRIS SQL table, 384 dimensions to match FastEmbed
        Set vs = ##class(%AI.RAG.VectorStore.IRIS).%New()
        Set vs.TableName  = "Sample.RAGDocs"
        Set vs.Dimensions = 384
        Set vs.ModelName  = "AllMiniLML6V2"
        $$$ThrowOnError(vs.Build())

        // 3. Knowledge base
        Set kb = ##class(%AI.RAG.KnowledgeBase).%New("search_docs", "Sample documentation")
        $$$ThrowOnError(kb.Build(emb, vs))

        // 4. Index some documents
        Set sc = kb.AddDocument("IRIS is a high-performance multimodel database platform.", {"source": "intro.txt"})
        $$$ThrowOnError(sc)
        Set sc = kb.AddDocument("The %SQL.Statement class is used to execute dynamic SQL in IRIS.", {"source": "sql.txt"})
        $$$ThrowOnError(sc)
        Write "Documents indexed.", !

        // 5. Wire up to an agent
        Set apiKey = ##class(Sample.AI.Utils).GetAPIKey("", .providerType)
        Set provider = ##class(%AI.Provider).Create(providerType, {"api_key": (apiKey)})
        Set agent = ##class(%AI.Agent).%New(provider)
        Set agent.Model = "gpt-4o"
        Set agent.SystemPrompt = "You are a helpful assistant. Use the search_docs tool to find information."
        $$$ThrowOnError(kb.AddToAgent(agent))

        // 6. Ask a question — the agent will search the KB automatically
        Set session = agent.CreateSession()
        Set response = agent.Chat(session, "How do I run a SQL query in IRIS?")
        Write response.Content, !

        Return $$$OK
    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}
```

---

### Complete Example: OpenAI Embeddings + Promoted Fields

```objectscript
ClassMethod OpenAIEmbedDemo() As %Status
{
    Try {
        Set apiKey = ##class(Sample.AI.Utils).GetAPIKey("openai")

        // 1. OpenAI embeddings — reuses provider credentials, 1536 dimensions
        Set provider = ##class(%AI.Provider).CreateOpenAI(apiKey)
        Set emb = ##class(%AI.RAG.Embedding.OpenAI).Create(provider)

        // 2. Vector store with promoted fields for filtered search
        Set fields = [
            {"name": "version",  "type": "varchar(20)", "description": "Product version"},
            {"name": "category", "type": "varchar(64)", "description": "Document category"}
        ]
        Set vs = ##class(%AI.RAG.VectorStore.IRIS).%New()
        Set vs.TableName  = "Sample.RAGDocsOpenAI"
        Set vs.Dimensions = 1536
        Set vs.ModelName  = "text-embedding-3-small"
        $$$ThrowOnError(vs.Build(fields))

        // 3. Knowledge base
        Set kb = ##class(%AI.RAG.KnowledgeBase).%New("search_docs",
            "Product documentation with version and category filters")
        Set kb.TopK = 8
        $$$ThrowOnError(kb.Build(emb, vs))

        // 4. Index documents with metadata that matches the promoted fields
        Set docs = [
            ["IRIS 2025.1 introduces vector search natively in SQL.", {"source":"rn-2025.1.txt","version":"2025.1","category":"release-notes"}],
            ["IRIS 2024.3 added OAuth2 support.", {"source":"rn-2024.3.txt","version":"2024.3","category":"release-notes"}],
            ["The %AI namespace hosts all AI integration classes.", {"source":"ai-guide.txt","version":"2025.1","category":"guide"}]
        ]
        Do kb.AddDocuments(docs)

        // 5. Connect to an agent and ask
        Set agent = ##class(%AI.Agent).%New(provider)
        Set agent.Model = "gpt-4o"
        Set agent.SystemPrompt = "You are a documentation assistant. Search for relevant docs before answering."
        $$$ThrowOnError(kb.AddToAgent(agent))

        Set session = agent.CreateSession()
        Set response = agent.Chat(session, "What's new in IRIS 2025.1?")
        Write response.Content, !

        Return $$$OK
    } Catch ex {
        Write "Error: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}
```

---

### API Reference

#### `%AI.RAG.Embedding` (abstract base)

| Member | Type | Description |
|---|---|---|
| `Dimensions` | Property (Integer) | Vector size — must match the model |
| `ModelName` | Property (String) | Canonical model identifier |
| `OptimalBatchSize` | Property (Integer) | Texts per embedding batch (default: 64) |
| `EmbedBatch(texts)` | Abstract Method | Input: `%DynamicArray` of strings → `%DynamicArray` of float arrays |
| `Register()` | Method | Registers with Rust bridge; sets `%token` |

#### `%AI.RAG.Embedding.FastEmbed`

Extends `%AI.RAG.Embedding`. Dimensions = 384, model = AllMiniLML6V2. Token is set
in `%OnNew()` — no `Register()` call needed.

#### `%AI.RAG.Embedding.OpenAI`

Extends `%AI.RAG.Embedding`. `%New(provider)` derives its token from `provider.%token`
via the Rust `query_interface` mechanism. Dimensions = 1536, model = text-embedding-3-small.

#### `%AI.RAG.VectorStore.IRIS`

| Member | Type | Description |
|---|---|---|
| `TableName` | Property (String) | Fully-qualified SQL table name (e.g. `"MyApp.Docs"`) |
| `Dimensions` | Property (Integer) | Must match the embedding model |
| `ModelName` | Property (String) | Stored in `_Config` table for mismatch detection |
| `Build(promotedFields?)` | Method | Creates SQL tables and registers with Rust bridge |

#### `%AI.RAG.KnowledgeBase`

| Member | Type | Description |
|---|---|---|
| `Name` | Property (String) | Tool name exposed to the LLM (e.g. `"search_docs"`) |
| `Description` | Property (String) | What the KB contains — the LLM reads this |
| `TopK` | Property (Integer) | Results per search (default: 5) |
| `Build(emb, vs)` | Method | Wires embedding + store; sets `%token` |
| `AddDocument(text, meta)` | Method | Chunk and index one document |
| `AddDocuments(docs)` | Method | Batch index; returns chunk count |
| `ReindexDocument(src, text, meta)` | Method | Delete old chunks for `src`, insert new |
| `AddToAgent(agent)` | Method | Registers `search_<Name>` tool on the agent |
| `AddToManager(mgr)` | Method | Registers on an explicit `%AI.ToolMgr` |
