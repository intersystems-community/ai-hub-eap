/// Tool provider for the programming languages database.
/// Extends %AI.Tool so these methods are auto-discovered and invokable by AI agents.
/// Demonstrates scalar args, dynamic arrays, nested objects (Language, Creator),
/// plain object arguments (Filter), and binary stream returns (Logo).
Class Sample.AI.Proglang.Tools Extends %AI.Tool [ DependsOn = (Sample.AI.Proglang.Language, Sample.AI.Proglang.Creator, Sample.AI.Proglang.Filter) ]
{

/// List all programming languages in the database.
///
/// Returns an array of objects with name and yearCreated for each language.
Method ListLanguages() As %DynamicArray
{
    Set result = []
    Set sql = "SELECT Name, YearCreated FROM Sample_AI_Proglang.ProgrammingLanguage ORDER BY Name"
    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare(sql)
    If $$$ISERR(sc) $$$ThrowStatus(sc)
    Set rs = stmt.%Execute()
    While rs.%Next() {
        Do result.%Push({"name": (rs.%Get("Name")), "yearCreated": (rs.%Get("YearCreated"))})
    }
    Return result
}

/// Get full details for a programming language by name.
///
/// Returns the Language object including description, tags, and creator.
/// name: The exact name of the language (e.g. "Rust", "Python")
Method GetLanguage(name As %String) As Sample.AI.Proglang.Language
{
    Set lang = ##class(Sample.AI.Proglang.Language).NameIdxOpen(name)
    If '$ISOBJECT(lang) $$$ThrowStatus($$$ERROR($$$GeneralError, "Language not found: " _ name))
    Return lang
}

/// Get the creator of a programming language.
///
/// Returns creator details including name, email, and company.
/// name: The exact name of the language
Method GetCreator(name As %String) As Sample.AI.Proglang.Creator
{
    Set lang = ##class(Sample.AI.Proglang.Language).NameIdxOpen(name)
    If '$ISOBJECT(lang) $$$ThrowStatus($$$ERROR($$$GeneralError, "Language not found: " _ name))
    If '$ISOBJECT(lang.Creator) $$$ThrowStatus($$$ERROR($$$GeneralError, "No creator recorded for: " _ name))
    Return lang.Creator
}

/// Get the logo image for a programming language as a binary stream.
///
/// Returns a PNG image stream (binary). Empty stream if no logo is stored.
/// name: The exact name of the language
Method GetLogo(name As %String) As %Stream.GlobalBinary
{
    Set lang = ##class(Sample.AI.Proglang.Language).NameIdxOpen(name)
    If '$ISOBJECT(lang) $$$ThrowStatus($$$ERROR($$$GeneralError, "Language not found: " _ name))
    Return lang.Logo
}

/// Search for languages that have a specific tag.
///
/// Returns an array of matching language names.
/// tag: The tag to search for (e.g. "systems", "scripting", "web")
Method SearchByTag(tag As %String) As %DynamicArray
{
    Set result = []
    // Load all and check tags -- small dataset so this is fine
    Set sql = "SELECT ID FROM Sample_AI_Proglang.ProgrammingLanguage ORDER BY Name"
    Set stmt = ##class(%SQL.Statement).%New()
    $$$ThrowOnError(stmt.%Prepare(sql))
    Set rs = stmt.%Execute()
    While rs.%Next() {
        Set lang = ##class(Sample.AI.Proglang.Language).%OpenId(rs.%Get("ID"))
        For i=1:1:lang.Tags.Count() {
            If $ZCVT(lang.Tags.GetAt(i), "L") = $ZCVT(tag, "L") {
                Do result.%Push(lang.Name)
                Quit
            }
        }
    }
    Return result
}

/// Find languages matching a composite filter (tag and/or year range).
///
/// Returns an array of matching language names.
/// filter: Filter criteria -- Tag (empty=any), MinYear (0=none), MaxYear (0=none)
Method FindByFilter(filter As Sample.AI.Proglang.Filter) As %DynamicArray
{
    Set result = []
    Set sql = "SELECT ID FROM Sample_AI_Proglang.ProgrammingLanguage ORDER BY Name"
    Set stmt = ##class(%SQL.Statement).%New()
    $$$ThrowOnError(stmt.%Prepare(sql))
    Set rs = stmt.%Execute()
    While rs.%Next() {
        Set lang = ##class(Sample.AI.Proglang.Language).%OpenId(rs.%Get("ID"))

        // Year range filter
        If filter.MinYear > 0, lang.YearCreated < filter.MinYear Continue
        If filter.MaxYear > 0, lang.YearCreated > filter.MaxYear Continue

        // Tag filter
        If filter.Tag '= "" {
            Set found = 0
            For i=1:1:lang.Tags.Count() {
                If $ZCVT(lang.Tags.GetAt(i), "L") = $ZCVT(filter.Tag, "L") { Set found = 1  Quit }
            }
            If 'found Continue
        }

        Do result.%Push({"name": (lang.Name), "yearCreated": (lang.YearCreated)})
    }
    Return result
}

/// Add a new programming language to the database.
///
/// Returns "OK: <name>" on success. Raises an error if the name already exists.
/// lang: The language to add, with Name (required), YearCreated, Description, Tags, Creator
Method AddLanguage(lang As Sample.AI.Proglang.Language) As %String
{
    $$$ThrowOnError(lang.%Save())
    Return "OK: " _ lang.Name
}

/// Update the creator information for an existing programming language.
///
/// Returns "OK: <name>" on success.
/// name: The exact name of the language to update
/// creator: New creator details (FirstName, LastName, Email, Company)
Method UpdateCreator(name As %String, creator As Sample.AI.Proglang.Creator) As %String
{
    Set lang = ##class(Sample.AI.Proglang.Language).NameIdxOpen(name, -1)
    If '$ISOBJECT(lang) $$$ThrowStatus($$$ERROR($$$GeneralError, "Language not found: " _ name))
    Set lang.Creator = creator
    $$$ThrowOnError(lang.%Save())
    Return "OK: " _ name
}

}
