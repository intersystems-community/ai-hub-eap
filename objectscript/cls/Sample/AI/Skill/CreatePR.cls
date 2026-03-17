/// Create Pull Request Skill
/// Demonstrates a skill with tool dependencies
Class Sample.AI.Skill.CreatePR Extends %AI.Skill
{

/// Tools this skill needs
Parameter TOOLS = "%AI.Tools.FileSystem";

/// yaml "front matter"
XData SUMMARY [ mimetype="text/yaml" ]
{
name: create-pr
description: Create a pull request from current changes
}

/// Workflow instructions for the subagent
XData INSTRUCTIONS [ mimetype = "text/markdown" ]
{
    You are a Pull Request creation assistant. When invoked:

    1. Check the current directory to understand the project structure
    2. List all files to see what's available
    3. Analyze the changes (you can read specific files if needed)
    4. Generate a clear, descriptive PR title
    5. Create a PR description with:
       - Summary of changes
       - Files modified
       - Purpose of the changes
    6. When complete, respond with the PR information

    Note: In this demo, we don't have actual git tools, so focus on
    analyzing the file system and generating a mock PR description.

    Always format your final response as:

    **PR Title**: [title]

    **Description**:
    [description]

    **Files Analyzed**: [count]
}

/// Helper: Generate commit message from file analysis
Method GenerateCommitMessage(files As %DynamicArray) As %String
{
    Set fileCount = files.%Size()

    If fileCount = 0 Return "No changes detected"
    If fileCount = 1 Return "Update " _ files.%Get(0)

    Return "Update " _ fileCount _ " files"
}

}
