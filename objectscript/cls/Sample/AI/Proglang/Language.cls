/// A programming language with metadata, tags, creator, and logo.
/// Persistent class with JSON and XML adaptor support.
/// Features nested objects (Creator), list collections (Tags),
/// binary stream storage (Logo)
Class Sample.AI.Proglang.Language Extends (%Persistent, %JSON.Adaptor, %XML.Adaptor) [ SqlTableName = ProgrammingLanguage ]
{

/// Language name (e.g. "Rust", "Python").
Property Name As %String(MAXLEN = 100) [ Required ];

/// Year the language was first publicly released.
Property YearCreated As %Integer;

/// Brief description of the language and its design goals.
Property Description As %String(MAXLEN = 2000);

/// Classification tags (e.g. "systems", "scripting", "web", "data-science").
Property Tags As list Of %String(XMLNAME = "Tag", XMLPROJECTION = "ELEMENT");

/// Primary creator or lead designer of the language.
Property Creator As Sample.AI.Proglang.Creator;

/// Small logo image (PNG thumbnail) stored as binary stream.
Property Logo As %Stream.GlobalBinary(XMLPROJECTION = "ELEMENT");

Index NameIdx On Name [ Unique ];

}
