# Config Store Guide

The **Config Store** is an ObjectScript API in InterSystems IRIS that provides centralized management of configuration data. It allows you to store and retrieve application configurations in a secure, structured manner, with the ability to govern access by specifying an [IRIS Resource](https://docs.intersystems.com/iris20261/csp/docbook/Doc.View.cls?KEY=GSA_using_resources) a user must have in order to be able to read, use, or write the configuration. The Config Store is used by various components of the AI Hub, including the [LangChain integration](langchain_SDK.md) and the [ObjectScript SDK](ObjectScript_SDK_Guide.md).

This guide explains how to use the Config Store through the `%ConfigStore.Configuration` API class and how to securely manage credentials using the [IRIS Wallet](https://docs.intersystems.com/iris20261/csp/docbook/Doc.View.cls?KEY=ROARS_secrets_mgmt). 

## Table of Contents

- [Config Store Guide](#config-store-guide)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Core Concepts](#core-concepts)
    - [Typing and Naming](#typing-and-naming)
    - [Configuration Details](#configuration-details)
  - [Working with the IRIS Wallet](#working-with-the-iris-wallet)
    - [Creating Security Resources](#creating-security-resources)
    - [Creating a Wallet Collection](#creating-a-wallet-collection)
    - [Storing Secrets](#storing-secrets)
  - [Working with Config Store](#working-with-config-store)
    - [Creating Configurations](#creating-configurations)
    - [Retrieving Configurations](#retrieving-configurations)
    - [Deleting Configurations](#deleting-configurations)
    - [Referencing Secrets](#referencing-secrets)
  - [Practical Examples](#practical-examples)
    - [Example 1: Setting Up an LLM Configuration with OpenAI](#example-1-setting-up-an-llm-configuration-with-openai)
    - [Example 2: Setting Up Multiple MCP Server Configurations](#example-2-setting-up-multiple-mcp-server-configurations)
    - [Example 3: Retrieving and Using a Configuration](#example-3-retrieving-and-using-a-configuration)

## Overview

The Config Store provides a straightforward and governed way to store configuration data with the following benefits:

- **Centralized Management**: Single source of truth for application configurations, with integrated Role-Based Access Control (RBAC)
- **Secure Credential Storage**: Integration with the IRIS Wallet for storing sensitive data
- **Automatic validation**: Store and retrieve configuration details as JSON objects that are automatically validated

## Core Concepts

### Typing and Naming

Configuration type names are structured using a simple `&lt;area&gt;.&lt;type&gt;.&lt;subtype&gt;` pattern, in which the last segment is optional. 

For example:
- `AI.MCP`
- `AI.LLM.AWSBedrock`

Actual configurations then have a logical name, and are fully identified by concatenating the configuration type and logical name.

For example:
- `AI.MCP.MyServer`
- `AI.LLM.the_local_server`


### Configuration Details

Configuration details are stored as JSON objects. Each configuration is a complete JSON object that contains all necessary settings for a specific component or service. The descriptor class associated with the configuration type specifies what details are required, and offers automatic validation.

## Working with the IRIS Wallet

The [IRIS Wallet](https://docs.intersystems.com/iris20261/csp/docbook/Doc.View.cls?KEY=ROARS_secrets_mgmt) provides secure storage for sensitive credentials that can be referenced from configurations. The Wallet uses a collection-based approach with fine-grained access controls.

Because of the Wallet's highly secured nature, it is not an appropriate place to store full configuration data. For example, the Wallet does not have a method to inspect its contents. You can think of the Config Store as a light wrapper around the Wallet that offers some convenience and structure, but otherwise it has the same access control features offered by the Wallet.


### Creating Security Resources

First, create security resources that control access to your wallet collection:

```objectscript
New $NAMESPACE
Set $NAMESPACE="%SYS"
Do ##class(Security.Resources).Create("MyUseResource")
Do ##class(Security.Resources).Create("MyEditResource")
```

- **UseResource**: Controls read access to secrets in the wallet
- **EditResource**: Controls write/edit access to secrets in the wallet

### Creating a Wallet Collection

Create a wallet collection with the security resources you defined:

```objectscript
Do ##class(%Wallet.Collection).Create(
    "MyCollection", 
    {
        "UseResource": "MyUseResource", 
        "EditResource": "MyEditResource"
    }
)
```

Parameters:
- **Collection Name**: A unique identifier for your collection (e.g., "MyCollection")
- **Permissions**: A JSON object specifying `UseResource` and `EditResource`

### Storing Secrets

Store sensitive data in the wallet using the `%Wallet.KeyValue` class:

```objectscript
set secret = {
    "Usage": "CUSTOM",
    "Secret": {
        "key": "sk-your-api-key-here"
    }
}
$$$QuitOnError(##class(%Wallet.KeyValue).Create("MyCollection.TestSecret", secret))
```

Parameters:
- **Key Name**: Format is `CollectionName.SecretName` (e.g., "MyCollection.TestSecret")
- **Secret Object**: A JSON object with:
  - `Usage`: Type of secret (e.g., "CUSTOM", "OAuth2", etc.)
  - `Secret`: A JSON object containing the actual secret data

## Working with Config Store

The `%ConfigStore.Configuration` class provides methods to manage configurations.

### Creating Configurations

Create a new configuration using the `Create` method:

```objectscript
set configData = {
    "model_provider": "openai",
    "model": "gpt-4o",
    "api_key": "secret://MyCollection.TestSecret#key"
}
$$$QuitOnError(##class(%ConfigStore.Configuration).Create(
    "AI",           ; Area
    "LLM",          ; Type  
    "",             ; Subtype
    "openai",       ; Name
    configData      ; Configuration object
))
```

Parameters:
- **Area**: Top-level category (e.g., "AI")
- **Type**: Second-level category (e.g., "LLM", "MCP")
- **Subtype**: Third-level category (can be empty string, not in use for this example)
- **Name**: Specific configuration name (e.g., "openai", "my-gpt4-key")
- **Configuration**: JSON object containing the configuration data

:information_source: Note how we use the `secret://` prefix to identify elements in the configuration that need to be retrieved from the IRIS Wallet.

### Retrieving Configurations

To retrieve a stored configuration:

```objectscript
set config = ##class(%ConfigStore.Configuration).Get(
    "AI",           ; Area
    "LLM",          ; Type
    "",             ; Subtype
    "openai"        ; Name
)
```

### Deleting Configurations

Remove a configuration:

```objectscript
Do ##class(%ConfigStore.Configuration).Delete(
    "AI.LLM.openai"  ; Full name with dots
)
```

Or using the full parameter syntax:

```objectscript
Do ##class(%ConfigStore.Configuration).Delete(
    "AI",           ; Area
    "LLM",          ; Type
    "",             ; Subtype
    "openai"        ; Name
)
```

### Referencing Secrets

When creating configurations that need credentials, reference wallet secrets using the URI format:

```
secret://CollectionName.SecretName#FieldName
```

Example:
```objectscript
set llmConfig = {
    "model_provider": "openai",
    "model": "gpt-4o",
    "api_key": "secret://MyCollection.TestSecret#key"
}
```

When the configuration is used, the system will automatically resolve `secret://MyCollection.TestSecret#key` to the actual value stored in the wallet.

## Practical Examples

### Example 1: Setting Up an LLM Configuration with OpenAI

```objectscript
ClassMethod SetupOpenAI(apiKey As %String) As %Status
{
    New $NAMESPACE
    Set $NAMESPACE = "%SYS"
    
    ; Create security resources
    Do ##class(Security.Resources).Create("AIUseResource")
    Do ##class(Security.Resources).Create("AIEditResource")
    
    ; Create wallet collection
    Do ##class(%Wallet.Collection).Create("AISecrets", {
        "UseResource": "AIUseResource",
        "EditResource": "AIEditResource"
    })
    
    ; Store API key in wallet
    set secret = {
        "Usage": "CUSTOM",
        "Secret": {
            "api_key": (apiKey)
        }
    }
    $$$QuitOnError(##class(%Wallet.KeyValue).Create("AISecrets.OpenAI", secret))
    
    ; Create LLM configuration referencing the wallet secret
    set llmConfig = {
        "model_provider": "openai",
        "model": "gpt-4o",
        "api_key": "secret://AISecrets.OpenAI#api_key",
        "temperature": 0.7
    }
    
    $$$QuitOnError(##class(%ConfigStore.Configuration).Create(
        "AI",
        "LLM",
        "",
        "openai",
        llmConfig
    ))
    
    Quit $$$OK
}
```

### Example 2: Setting Up Multiple MCP Server Configurations

```objectscript
ClassMethod SetupMCPServers(pythonPath As %String, serverPaths As %List) As %Status
{
    ; Clean up existing configurations
    Do ##class(%ConfigStore.Configuration).Delete("AI.MCP.addition")
    Do ##class(%ConfigStore.Configuration).Delete("AI.MCP.multiplication")
    
    ; Create addition server configuration
    set additionConfig = {
        "command": pythonPath,
        "args": [($ListGet(serverPaths, 1))],
        "transport": "stdio"
    }
    $$$QuitOnError(##class(%ConfigStore.Configuration).Create(
        "AI",
        "MCP",
        "",
        "addition",
        additionConfig
    ))
    
    ; Create multiplication server configuration
    set multiplicationConfig = {
        "command": pythonPath,
        "args": [($ListGet(serverPaths, 2))],
        "transport": "stdio"
    }
    $$$QuitOnError(##class(%ConfigStore.Configuration).Create(
        "AI",
        "MCP",
        "",
        "multiplication",
        multiplicationConfig
    ))
    
    Quit $$$OK
}
```

### Example 3: Retrieving and Using a Configuration

```objectscript
ClassMethod UseConfiguration() As %Status
{
    ; Retrieve the LLM configuration
    set llmConfig = ##class(%ConfigStore.Configuration).Get(
        "AI",
        "LLM",
        "",
        "openai"
    )
    
    If llmConfig = "" {
        Quit $$$ERROR($$$GeneralError, "Configuration not found")
    }
    
    ; Access configuration properties
    set provider = llmConfig.model_provider
    set model = llmConfig.model
    set apiKey = llmConfig.api_key
    
    ; Use the configuration
    Write "Provider: " _ provider _ !
    Write "Model: " _ model _ !
    Write "API Key Reference: " _ apiKey _ !
    
    Quit $$$OK
}
```
