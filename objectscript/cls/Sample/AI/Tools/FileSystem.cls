Include (%AI, %occStatus)

/// Filesystem Tool - Sample implementation for file and directory operations
/// This example demonstrates how to implement filesystem tools with safety controls
Class Sample.AI.Tools.FileSystem Extends %AI.Tool
{
/// Display name for this tool provider
Property Name As %String [ InitialExpression = "File Operations" ];

/// Description of what this tool does
Property Description As %String(MAXLEN = "") [ InitialExpression = "Read files and list directories" ];

/// Base directory that this tool can access
Property BaseDirectory As %String [ InitialExpression = {$system.Util.TempDirectory()} ];

/// Maximum file size to read (in bytes, default 1MB)
Property MaxFileSize As %Integer [ InitialExpression = 1048576 ];

/// List files and directories in a path
/// path: Path to the directory to list (relative to BaseDirectory or absolute)
/// Returns object with files, directories, and metadata
Method ReadDirectory(path As %String) As %DynamicObject
{
    Try {
        // Resolve path
        Set fullPath = $SELECT(
            $EXTRACT(path,1) = "/": path,
            1: ..BaseDirectory _ "/" _ path
        )

        // Check if directory exists
        If '##class(%File).DirectoryExists(fullPath) {
            Set error = {"error": ("Directory does not exist: " _ fullPath)}
            Return error
        }

        Set files = []
        Set dirs = []

        Set file = ""
        For  {
            Set file = ##class(%File).FindFirstFile(fullPath _ "/*")
            Quit:file=""

            Set filename = ##class(%File).GetFilename(file)
            Set filepath = fullPath _ "/" _ filename

            If ##class(%File).DirectoryExists(filepath) {
                Set dirInfo = {
                    "name": (filename),
                    "type": "directory",
                    "path": (filepath)
                }
                Do dirs.%Push(dirInfo)
            } Else {
                Set size = ##class(%File).GetFileSize(filepath)
                Set fileInfo = {
                    "name": (filename),
                    "type": "file",
                    "path": (filepath),
                    "size": (size)
                }
                Do files.%Push(fileInfo)
            }
        }

        Set result = {
            "path": (fullPath),
            "files": (files),
            "directories": (dirs),
            "totalFiles": (files.%Size()),
            "totalDirectories": (dirs.%Size())
        }

        Return result

    } Catch ex {
        Set error = {"error": ("Directory listing failed: " _ ex.DisplayString())}
        Return error
    }
}

/// Read the contents of a file
/// path: Path to the file to read (relative to BaseDirectory or absolute)
/// Returns object with file content and metadata
Method ReadFile(path As %String) As %DynamicObject
{
    Try {
        // Resolve path
        Set fullPath = $SELECT(
            $EXTRACT(path,1) = "/": path,
            1: ..BaseDirectory _ "/" _ path
        )

        // Check if file exists
        If '##class(%File).Exists(fullPath) {
            Set error = {"error": ("File does not exist: " _ fullPath)}
            Return error
        }

        // Get file size
        Set fileSize = ##class(%File).GetFileSize(fullPath)

        // Check file size
        If fileSize > ..MaxFileSize {
            Set error = {"error": ("File too large: " _ fileSize _ " bytes, max is " _ ..MaxFileSize)}
            Return error
        }

        // Read the file
        Set stream = ##class(%FileCharacterStream).%New()
        Set status = stream.LinkToFile(fullPath)
        If $$$ISERR(status) {
            Set error = {"error": ("Failed to open file: " _ fullPath)}
            Return error
        }

        Set content = stream.Read()
        Do stream.%Close()

        // Return result
        Set result = {
            "path": (fullPath),
            "content": (content),
            "size": (fileSize),
            "encoding": "UTF-8"
        }

        Return result

    } Catch ex {
        Set error = {"error": ("File read failed: " _ ex.DisplayString())}
        Return error
    }
}

}
