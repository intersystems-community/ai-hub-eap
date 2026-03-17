# InterSystems AI Hub EAP

Welcome to the Early Access Program for the InterSystems AI Hub.
The InterSystems AI Hub is our offering for InterSystems customers who wish to accelerate their AI development involving IRIS, and consists of an ObjectScript, Python and Java SDK to interact with LLMs and external MCP Servers to build agents and AI capabilities. It also includes an MCP Server capability to expose IRIS-based logic through MCP for external consumption.

:warning: As part of the EAP, we're making pre-release software available through this portal. At this time, *this software is not meant to be used in production*. We're working hard to get the packaging and integration with core IRIS features, including credential management, right and therefore some of the APIs and access control features are likely to change in the course of the API. We intend to document such changes here, in the change log at the bottom of the page.

## Accessing the software

You can download full kits or docker container images that include the latest InterSystems AI Hub updates from the [Early Access Program portal](https://evaluation.intersystems.com/Eval/early-access/AIHub). 

:information_source: In the instructions below, please note the version number is included in file names, and you may need to adjust the commands to match the files you downloaded.

No specific license is required to use the AI Hub.

The kits posted on this page can be installed like a normal InterSystems IRIS installable. 

When using a container image, use the following commands to import and launch the image after downloading:
```Shell
docker image load -i /path/to/iris-2026.2.0AI.129.0-docker.tar.gz

docker run --name iris-ai-hub -p 1972:1972 -p 52773:52773 -d --volume /path/to/license-key:/external/keys intersystems/iris:2026.2.0AI.129.0 -k /external/keys/iris-container-x64.key
```
For more about optional parameters, such as `--key` and `--volume`, see the documentation on [running IRIS in containers](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=AFL_containers#AFL_containers_deploy_run1).

To change the default password, see the documentation above or use the following commands:
```Shell
docker exec -it iris-ai-hub iris session iris -U %SYS

%SYS> write ##class(Security.Users).UnExpireUserPasswords("*")
```

## What is the AI Hub?

The AI Hub consists of two main pieces:

The **AI SDK** helps users who develop applications on IRIS to take advantage of AI resources such as AI models (with an initial focus on LLMs) and external MCP Servers. It offers an API that abstracts over the specifics of the various AI service providers' own APIs and governs access to these using IRIS RBAC policies, consistent with the security model of the rest of your IRIS based logic. 
The AI SDK is available for ObjectScript, Python, and Java developers. For Python and Java, we're ensuring this is familiar to developers already working with AI by implementing the [langchain](https://docs.langchain.com/) and [LangChain4J](https://docs.langchain4j.dev/) APIs, respectively, but ensuring access to resources is governed through the same IRIS Config Store.

The **MCP Server** facilitates exposing customer business logic and existing IRIS functionality through an MCP Server, such that Agents and other external MCP Clients can easily include this in their agentic workflows. Again, access to these is governed using standard IRIS RBAC policies. 
Exposing business logic as MCP tools can be achieved entirely declaratively, either using an XData block in a class definition, or a simple user interface.

![Basic Diagram](img/basic-diagram.png)

:information_source: Not all capabilities have been fully implemented or included in the available kits, please check in regularly for updates, or subscribe to this repo for updates!

## How to use the AI Hub

Please see the following dedicated documentation pieces:
* [MCP Server - setup](MCP_Server_Guide.md)
* [AI SDK - ObjectScript - basics](ObjectScript_SDK_Guide.md)
* [AI SDK - ObjectScript - examples](ObjectScript_SDK_Examples.md)
* [AI SDK - ObjectScript - advanced](ObjectScript_SDK.Advanced.md)

You may note that the AI SDK for ObjectScript appears way more involved than the Python and Java experiences right now. This is because the ObjectScript one was developed from the ground up for IRIS, and is not constrained by or risks overlap with those Python and Java frameworks, which may have their own ways of implementing specific capabilities. If you see any big gaping holes with opportunities to plug it, please do let us know!

## How to reach out

If you have any questions or feedback, feel free to send them to file them as issues on this repository, which makes them visible for the combined InterSystems team, or send them straight through email to [Benjamin De Boe](mailto:benjamin.de.boe@intersystems.com)