Class User.ConfigStoreTest
{

/// REPLACE WITH YOUR OPENAI KEY
Parameter key = "sk-your-key-here";

/// REPLACE WITH YOUR PATH TO PYTHON INSTANCE THAT HAS mcp PACKAGE INSTALLED
Parameter python = "/path/to/python.exe";

/// REPLACE WITH YOUR PATH TO addition_server.py
Parameter additionserver = "/path/to/addition_server.py";

/// REPLACE WITH YOUR PATH TO multiplication_server.py
Parameter multiplicationserver = "/path/to/multiplication_server.py";

ClassMethod CreateSecretResources()
{
    New $NAMESPACE
    Set $NAMESPACE="%SYS"
    DO ##class(Security.Resources).Create("MyUseResource")
    DO ##class(Security.Resources).Create("MyEditResource")

    Do ##class(%Wallet.Collection).Delete("MyCollection")
    Do ##class(%Wallet.Collection).Create("MyCollection", {"UseResource" : "MyUseResource", "EditResource" : "MyEditResource"})
    Do ##class(%Wallet.Collection).Create("MyCollection", {"UseResource" : "MyUseResource", "EditResource" : "MyEditResource"})
    set secret1 = {
        "Usage": "CUSTOM",
        "Secret": {
            "key": (..#key)
        }
    }
    $$$QuitOnError(##class(%Wallet.KeyValue).Create("MyCollection.TestSecret", secret1))
}

ClassMethod Test() As %Status
{
    Do ..CreateSecretResources()
    Do ##class(%ConfigStore.Configuration).Delete("AI.MCP.addition")
    Do ##class(%ConfigStore.Configuration).Delete("AI.MCP.multiplication")
    Do ##class(%ConfigStore.Configuration).Delete("AI.LLM.llm1")
    Do ##class(%ConfigStore.Configuration).Delete("AI.LLM.llm2")

    set mcp1 = {
        "command": (..#python),
        "args": [(..#additionserver)],
        "transport": "stdio"
    }
    set mcp2 = {
        "command": (..#python),
        "args": [(..#multiplicationserver)],
        "transport": "stdio"
    }

    set llm1 = {
        "model_provider": "openai",
        "model": "gpt-4o",
        "api_key": "secret://MyCollection.TestSecret#key"
    }
    set llm2 = {
        "model_provider": "ollama",
        "model": "llama3.2"
    }

    $$$QuitOnError(##class(%ConfigStore.Configuration).Create("AI", "MCP", "", "addition", mcp1))
    $$$QuitOnError(##class(%ConfigStore.Configuration).Create("AI", "MCP", "", "multiplication", mcp2))
    $$$QuitOnError(##class(%ConfigStore.Configuration).Create("AI", "LLM", "", "openai", llm1))
    $$$QuitOnError(##class(%ConfigStore.Configuration).Create("AI", "LLM", "", "llama", llm2))

    quit $$$OK
}

}
