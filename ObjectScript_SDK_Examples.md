# InterSystems AI Hub ObjectScript Examples

> [!IMPORTANT]
> Please note this is prerelease software, and any APIs and functionality described in this document is subject to change without prior notice before the initial GA release of the AI Hub.

This document describes comprehensive examples demonstrating the InterSystems AI Hub framework in ObjectScript. Please see the [User Guide](ObjectScript_SDK_Guide.md) and, for some examples, the [Advanced Features Guide](ObjectScript_SDK_Advanced.md) for a broader description of the functionalities.

## Directory Structure

```
objectscript/
├── cls/
│   └── Sample/
│       ├── AI/
│       │   ├── Tools/          # Sample tool implementations
│       │   ├── ToolSet/        # Sample toolset definitions
│       │   ├── Policies/       # Sample policy implementations
│       │   ├── Agent/          # Sample agent subclasses
│       │   ├── Skill/          # Sample skill definitions
│       │   └── Examples/       # Complete usage examples
│       └── MCP/
│           └── Service/        # Sample MCP service implementations
├── USER_GUIDE.md              # Complete user guide
└── README.md                  # This file
```

## Examples

### Basic Usage (`Sample.AI.Examples.BasicUsage`)

Simple examples showing fundamental AI interactions without tools.

**Examples:**
- `SimpleQA()` - Basic question and answer
- `Conversation()` - Multi-turn conversation with context
- `MultiProvider()` - Using different AI providers (OpenAI, Anthropic, etc.)

**Usage:**
```objectscript
Do ##class(Sample.AI.Examples.BasicUsage).SimpleQA()
```

### Tool Usage (`Sample.AI.Examples.ToolUsage`)

Demonstrates how agents use tools to perform tasks.

**Examples:**
- `BMIExample()` - Using the BMI calculator tool
- `FileSystemExample()` - File system operations
- `SQLExample()` - Database queries
- `MultiToolExample()` - Using multiple tools together

**Usage:**
```objectscript
Do ##class(Sample.AI.Examples.ToolUsage).BMIExample()
```

### Multi-Modal (`Sample.AI.Examples.MultiModal`)

Shows how to work with images and other media types.

**Examples:**
- `Run()` - Analyze a satellite weather image
- `SimpleExample()` - Compare with text-only request

**Usage:**
```objectscript
Do ##class(Sample.AI.Examples.MultiModal).Run()
```

### Policy Enforcement (`Sample.AI.Examples.PolicyEnforcement`)

:warning: advanced / experimental feature -- this capability may change significantly before GA release

Demonstrates security and governance with policies.

**Examples:**
- `AuthorizationExample()` - Restrict file access to specific paths
- `AuditExample()` - Log all tool executions
- `CombinedPoliciesExample()` - Use both authorization and audit

**Usage:**
```objectscript
Do ##class(Sample.AI.Examples.PolicyEnforcement).AuthorizationExample()
```

### RAG — Knowledge Bases (`Sample.AI.Examples.RAGUsage`)

Demonstrates retrieval-augmented generation: build a knowledge base, index documents,
and let agents retrieve relevant context before answering.

**Examples:**
- `FastEmbedDemo()` — Local AllMiniLML6V2 embeddings + IRIS SQL store (no embedding API key)
- `OpenAIEmbedDemo()` — OpenAI text-embedding-3-small + promoted metadata fields
- `ReindexDemo()` — Atomic document replacement with `ReindexDocument()`

**Usage:**
```objectscript
// Local embeddings, no API key for embedding
Do ##class(Sample.AI.Examples.RAGUsage).FastEmbedDemo()

// OpenAI embeddings (requires OPENAI_API_KEY)
Do ##class(Sample.AI.Examples.RAGUsage).OpenAIEmbedDemo()

// Re-indexing a changed document
Do ##class(Sample.AI.Examples.RAGUsage).ReindexDemo()
```

### Advanced ToolSet (`Sample.AI.Examples.AdvancedToolSet`)

XML-based toolset definition showing advanced features:
- Local inline tools
- Included tools from other classes
- Policy composition
- MCP server integration (local stdio and remote HTTP)

**Usage:**
```objectscript
Set toolset = ##class(Sample.AI.Examples.AdvancedToolSet).%New()
Do agent.ToolManager.AddTool(toolset)
```

## Sample Tools

### BMI Calculator (`Sample.AI.Tools.BMI`)

Calculate Body Mass Index given height and weight.

**Methods:**
- `CalculateBMI(heightM, weightKg)` - Returns BMI value and category

### File System (`Sample.AI.Tools.FileSystem`)

Safe file and directory operations.

**Methods:**
- `ReadDirectory(path)` - List files in a directory
- `ReadFile(path)` - Read file contents

**Properties:**
- `BaseDirectory` - Root directory for operations
- `MaxFileSize` - Maximum file size to read (default 1MB)

## Sample Policies

:warning: advanced / experimental feature -- this capability may change significantly before GA release

### Path Sanitizer (`Sample.AI.Policies.PathSanitizerPolicy`)

Authorization policy that restricts file access to allowed paths.

**Properties:**
- `AllowedPath` - List of allowed path prefixes
- `Strict` - If true, deny access to non-allowed paths

**Usage:**
```objectscript
Set policy = ##class(Sample.AI.Policies.PathSanitizerPolicy).%New()
Do policy.AllowedPath.Insert("/tmp")
Do policy.AllowedPath.Insert("/data")
Set policy.Strict = 1
Do agent.ToolManager.SetAuthPolicy(policy)
```

## Prerequisites

1. IRIS installation with AI Hub included
2. API keys for providers (set as environment variables):
   - `OPENAI_API_KEY` for OpenAI
   - `ANTHROPIC_API_KEY` for Anthropic
   - Others as needed

## Running Examples

### Import the Package

```objectscript
Do $system.OBJ.LoadDir("path/to/examples/objectscript/cls", "ck")
```

### Run an Example

```objectscript
// Basic example
Do ##class(Sample.AI.Examples.BasicUsage).SimpleQA()

// Tool example
Do ##class(Sample.AI.Examples.ToolUsage).BMIExample()

// Multi-modal example
Do ##class(Sample.AI.Examples.MultiModal).Run()

// Policy example
Do ##class(Sample.AI.Examples.PolicyEnforcement).AuthorizationExample()
```

## Example Categories

### 1. **Getting Started**
Start with `BasicUsage.SimpleQA()` to understand the fundamentals.

### 2. **Using Tools**
Progress to `ToolUsage` examples to see how agents use tools.

### 3. **Advanced Features**
- Multi-modal: `MultiModal.Run()`
- Policies: `PolicyEnforcement` examples
- ToolSets: `AdvancedToolSet`

### 4. **Knowledge Bases (RAG)**
- Local embeddings: `RAGUsage.FastEmbedDemo()`
- OpenAI embeddings + filtered search: `RAGUsage.OpenAIEmbedDemo()`
- Updating documents: `RAGUsage.ReindexDemo()`

### 5. **Custom Development**
Use the sample tools and policies as templates for your own:
- Extend `%AI.Tool` for custom tools
- Extend `%AI.Policy.Authorization` for auth policies
- Extend `%AI.Policy.Audit` for audit policies
- Extend `%AI.ToolSet` for XML-based tool collections
- Extend `%AI.RAG.Embedding` for custom embedding providers