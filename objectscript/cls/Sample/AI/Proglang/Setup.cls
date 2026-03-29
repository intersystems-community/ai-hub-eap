/// Setup and seed data for the Sample.AI.Proglang demo.
/// Run ##class(Sample.AI.Proglang.Setup).Load() to populate the database.
/// Run ##class(Sample.AI.Proglang.Setup).Reset() to clear it.
Class Sample.AI.Proglang.Setup
{

/// Seed data for five programming languages.
XData Languages
{
<Languages>

  <Language>
    <Name>ObjectScript</Name>
    <YearCreated>1997</YearCreated>
    <Description>ObjectScript is the primary language of InterSystems IRIS, combining
object-oriented programming with direct access to a high-performance multi-model
database. It supports objects, SQL, globals (sparse multidimensional arrays), and
seamless interoperability with Java, Python, .NET, and other languages via embedded
gateways. Its tight integration with the database engine makes it exceptionally fast
for transactional workloads.</Description>
    <Tag>database</Tag>
    <Tag>enterprise</Tag>
    <Tag>object-oriented</Tag>
    <Tag>scripting</Tag>
    <Creator>
      <FirstName>Jeffrey</FirstName>
      <LastName>Chow</LastName>
      <Company>InterSystems Corporation</Company>
    </Creator>
    <Logo>iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==</Logo>
  </Language>

  <Language>
    <Name>Rust</Name>
    <YearCreated>2015</YearCreated>
    <Description>Rust is a systems programming language focused on safety, speed, and
concurrency. It eliminates entire classes of bugs at compile time through its
ownership and borrowing model, guaranteeing memory safety without a garbage
collector. Rust is widely used for operating systems, WebAssembly, embedded systems,
network services, and anywhere C or C++ would traditionally be used.</Description>
    <Tag>systems</Tag>
    <Tag>safe</Tag>
    <Tag>concurrent</Tag>
    <Tag>compiled</Tag>
    <Tag>webassembly</Tag>
    <Creator>
      <FirstName>Graydon</FirstName>
      <LastName>Hoare</LastName>
      <Company>Mozilla Research</Company>
    </Creator>
    <Logo>iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==</Logo>
  </Language>

  <Language>
    <Name>Go</Name>
    <YearCreated>2009</YearCreated>
    <Description>Go (also known as Golang) is a statically typed, compiled language
designed at Google for simplicity and scalability. It features built-in concurrency
primitives (goroutines and channels), fast compilation, a garbage collector, and a
rich standard library. Go is a popular choice for cloud infrastructure, microservices,
CLI tools, and network programming.</Description>
    <Tag>systems</Tag>
    <Tag>concurrent</Tag>
    <Tag>compiled</Tag>
    <Tag>cloud</Tag>
    <Tag>microservices</Tag>
    <Creator>
      <FirstName>Robert</FirstName>
      <LastName>Griesemer</LastName>
      <Company>Google</Company>
    </Creator>
    <Logo>iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==</Logo>
  </Language>

  <Language>
    <Name>Python</Name>
    <YearCreated>1991</YearCreated>
    <Description>Python is a high-level, dynamically typed language renowned for its
readable syntax and broad ecosystem. It is the dominant language for data science,
machine learning, and AI, and is widely used for web development, scripting,
automation, and scientific computing. Python's extensive standard library and
package index (PyPI) make it one of the most versatile languages available.</Description>
    <Tag>scripting</Tag>
    <Tag>data-science</Tag>
    <Tag>machine-learning</Tag>
    <Tag>web</Tag>
    <Tag>general-purpose</Tag>
    <Creator>
      <FirstName>Guido</FirstName>
      <LastName>van Rossum</LastName>
      <Company>CWI</Company>
    </Creator>
    <Logo>iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==</Logo>
  </Language>

  <Language>
    <Name>TypeScript</Name>
    <YearCreated>2012</YearCreated>
    <Description>TypeScript is a strongly typed superset of JavaScript developed by
Microsoft. It adds optional static typing, interfaces, generics, and modern language
features that compile down to plain JavaScript. TypeScript has become the standard
for large-scale frontend and Node.js development, offering better tooling, refactoring
support, and early error detection compared to plain JavaScript.</Description>
    <Tag>web</Tag>
    <Tag>typed</Tag>
    <Tag>javascript</Tag>
    <Tag>frontend</Tag>
    <Tag>node</Tag>
    <Creator>
      <FirstName>Anders</FirstName>
      <LastName>Hejlsberg</LastName>
      <Company>Microsoft</Company>
    </Creator>
    <Logo>iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==</Logo>
  </Language>

</Languages>
}

/// Load seed languages into the database. Safe to call multiple times
/// (existing records are skipped via the unique Name index).
ClassMethod Load() As %Status
{
    Set sc = $$$OK
    Try {
        // Open XData stream
        Set xdata = ##class(%Dictionary.XDataDefinition).IDKEYOpen($CLASSNAME(), "Languages")
        If '$ISOBJECT(xdata) $$$ThrowStatus($$$ERROR($$$GeneralError, "XData Languages not found"))

        // Parse with %XML.Reader, correlating <Language> elements to the persistent class
        Set reader = ##class(%XML.Reader).%New()
        Set sc = reader.OpenStream(xdata.Data)
        If $$$ISERR(sc) $$$ThrowStatus(sc)

        Do reader.Correlate("Language", "Sample.AI.Proglang.Language")

        While reader.Next(.lang, .sc) {
            If $$$ISERR(sc) $$$ThrowStatus(sc)

            // Skip if this language already exists
            If ##class(Sample.AI.Proglang.Language).NameIdxExists(lang.Name) Continue

            Set sc = lang.%Save()
            If $$$ISERR(sc) $$$ThrowStatus(sc)
        }

    } Catch ex {
        Set sc = ex.AsStatus()
    }
    Return sc
}

/// Delete all language records from the database.
ClassMethod Reset() As %Status
{
    Return ##class(Sample.AI.Proglang.Language).%DeleteExtent()
}

/// Load seed data (if not already loaded) and pretty-print all stored languages.
/// Run from the IRIS terminal: Do ##class(Sample.AI.Proglang.Setup).Setup()
ClassMethod Setup() As %Status
{
    Set sc = ..Load()
    If $$$ISERR(sc) {
        Write "Load failed: ", $SYSTEM.Status.GetErrorText(sc), !
        Return sc
    }

    Write "=== Sample.AI.Proglang ===", !

    Set sql = "SELECT ID FROM Sample_AI_Proglang.ProgrammingLanguage ORDER BY Name"
    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare(sql)
    If $$$ISERR(sc) {
        Write "SQL error: ", $SYSTEM.Status.GetErrorText(sc), !
        Return sc
    }

    Set rs = stmt.%Execute()
    Set count = 0
    While rs.%Next() {
        Set count = count + 1
        Set lang = ##class(Sample.AI.Proglang.Language).%OpenId(rs.%Get("ID"))

        Write !, "[", count, "] ", lang.Name, " (", lang.YearCreated, ")", !

        // Creator
        If $ISOBJECT(lang.Creator) {
            Set creator = lang.Creator
            Set name = creator.FirstName _ " " _ creator.LastName
            If creator.Company '= "" {
                Set name = name _ " (" _ creator.Company _ ")"
            }
            Write "    Creator:     ", name, !
        }

        // Tags
        If lang.Tags.Count() > 0 {
            Set tagStr = ""
            For i=1:1:lang.Tags.Count() {
                Set tagStr = tagStr _ $SELECT(i>1:", ", 1:"") _ lang.Tags.GetAt(i)
            }
            Write "    Tags:        ", tagStr, !
        }

        // Description (first 80 chars)
        Set desc = lang.Description
        If $LENGTH(desc) > 80 {
            Set desc = $EXTRACT(desc, 1, 77) _ "..."
        }
        Write "    Description: ", desc, !

        // Logo
        If $ISOBJECT(lang.Logo) && (lang.Logo.Size > 0) {
            Write "    Logo:        ", lang.Logo.Size, " bytes", !
        } Else {
            Write "    Logo:        (none)", !
        }
    }

    Write !, count, " language(s) loaded.", !
    Return $$$OK
}

}
