## Introduction

The following demo shows how the IRIS config store can be used to store LLM and MCP configurations for use with LangChain. The demo first stores the following configurations in the IRIS config store.
- an OpenAI `gpt-4o` configuration
- an Ollama `llama3.2` configuration
- an MCP server that provides a tool to do addition
- an MCP server that provides a tool to do multiplication

Then we use LangChain to retrieve and use these configurations.

## Setup

### Python Setup

Open a terminal at the root of this project. Create and activate a virtual environment.
```Shell
python -m venv .venv
.venv\Scripts\activate  # if on Windows
source .venv/bin/activate  # if on Unix
```

Install the latest version of the `langchain-intersystems` module, available as a wheel from the [Early Access Program portal](https://evaluation.intersystems.com/Eval/early-access/AIHub). Make sure the version number matches the file you downloaded, and optionally use `--force-reinstall` to overwrite any earlier versions.

```Shell
pip install ./langchain_intersystems-0.0.1-py3-none-any.whl
```

To run this demo, you'll also need to install the `mcp`, `langchain-openai`, and `langchain-ollama` packages:

```Shell
pip install mcp langchain-openai langchain-ollama
```

### Ollama Setup

Install Ollama with the `llama3.2` model. See https://ollama.com/ for instructions for how to do this.

### Creating the configurations

See the 4 parameters at the top of `ConfigStoreTest.cls`. Replace them with values appropriate for your local environment. Load the class into the IRIS instance and execute the following command:

```ObjectScript
w ##class(User.ConfigStoreTest).Test()
```

This creates 2 LLM configurations named `'openai'` and `'llama'` and 2 simple MCP server configurations named `'addition'` and `'multiplication'` that use use FastMCP over stdio.

## Run the Demo

Obtain and use the OpenAI `gpt-4o` LLM.

```Python
import iris
from langchain_intersystems.chat_models import init_chat_model

# change to match your IRIS instance
conn = iris.connect('localhost', 51774, 'USER', '_SYSTEM', 'SYS')  

model = init_chat_model('openai', conn)
print(model.invoke('Hello, how are you?'))
```

Obtain and use the Ollama `llama3.2` LLM.

```Python
import iris
from langchain_intersystems.chat_models import init_chat_model

conn = iris.connect('localhost', 51774, 'USER', '_system', 'SYS')  # change as needed
model = init_chat_model('llama', conn)
print(model.invoke('Hello, how are you?'))
```

Connect to the addition and multiplication MCP servers.

```Python
import asyncio
import pprint
import iris
from langchain_intersystems import init_mcp_client

conn = iris.connect('localhost', 51774, 'USER', '_system', 'SYS')  # change as needed
client = init_mcp_client(['addition', 'multiplication'], conn)

pprint.pprint(asyncio.run(client.get_tools()))
```

Create an agent that uses the Ollama `llama3.2` LLM and uses tools from the addition and multiplication MCP servers.

```Python
import asyncio
import pprint

import iris
from langchain.agents import create_agent
from langchain_intersystems import init_mcp_client
from langchain_intersystems.chat_models import init_chat_model

conn = iris.connect('localhost', 51774, 'USER', '_system', 'SYS')  # change as needed
model = init_chat_model('llama', conn)
client = init_mcp_client(['addition', 'multiplication'], conn)


async def main():
    agent = create_agent(model, await client.get_tools())
    questions = ['What is 3+5?', 'What is 3x5?']
    for question in questions:
        print(question)
        pprint.pprint(await agent.ainvoke({'messages': question}))


asyncio.run(main())
```
