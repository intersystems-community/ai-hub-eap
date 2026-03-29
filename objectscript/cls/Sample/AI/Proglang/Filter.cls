/// Search filter for programming languages.
/// Passed to FindByFilter() as a structured argument.
Class Sample.AI.Proglang.Filter Extends %RegisteredObject
{

/// Filter by tag (e.g. "systems", "scripting", "web"). Empty means any tag.
Property Tag As %String(MAXLEN = 100);

/// Earliest creation year (inclusive). 0 means no lower bound.
Property MinYear As %Integer;

/// Latest creation year (inclusive). 0 means no upper bound.
Property MaxYear As %Integer;

}
