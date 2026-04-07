Include (%AI, %occStatus)

/// RLM ToolSet for ObjectScript %AI.Agent workflows.
/// Provides tool-mediated context exploration to avoid full prompt stuffing.
Class Sample.AI.Tools.RLM Extends %AI.ToolSet
{

Property Context As %String(MAXLEN = "") [ InitialExpression = "" ];
Property FinalAnswer As %String(MAXLEN = "") [ InitialExpression = "" ];
Property IsFinalized As %Boolean [ InitialExpression = 0 ];
Property Notes As list Of %String;

XData Definition [ MimeType = application/xml ]
{
    <ToolSet Name="RLMTools">
        <Description>Recursive language model style tools for large-context exploration.</Description>

        <Tool Name="inspect_context" Method="InspectContext">
            <Description>Inspect context size and structure before deeper analysis.</Description>
        </Tool>

        <Tool Name="search_context" Method="SearchContext">
            <Description>Search context for a query and return matching snippets.</Description>
            <Parameters>
                <Parameter Name="query" Type="string" Required="true">
                    <Description>Case-insensitive query term</Description>
                </Parameter>
                <Parameter Name="limit" Type="integer" Required="false">
                    <Description>Maximum number of matches (default 5)</Description>
                </Parameter>
            </Parameters>
        </Tool>

        <Tool Name="store_note" Method="StoreNote">
            <Description>Store an intermediate note for later synthesis.</Description>
            <Parameters>
                <Parameter Name="note" Type="string" Required="true">
                    <Description>Intermediate finding to persist</Description>
                </Parameter>
            </Parameters>
        </Tool>

        <Tool Name="summarize_notes" Method="SummarizeNotes">
            <Description>Summarize all stored notes into a concise draft.</Description>
        </Tool>

        <Tool Name="finalize" Method="Finalize">
            <Description>Finalize the answer and mark workflow complete.</Description>
            <Parameters>
                <Parameter Name="result" Type="string" Required="true">
                    <Description>Final answer text</Description>
                </Parameter>
            </Parameters>
        </Tool>
    </ToolSet>
}

Method Reset(context As %String = "") As %Status
{
    Set ..Context = context
    Set ..FinalAnswer = ""
    Set ..IsFinalized = 0
    Kill ..Notes
    Quit $$$OK
}

Method InspectContext() As %String
{
    Set chars = $Length(..Context)
    Set approxTokens = chars \ 4
    Set lines = $Length(..Context, $Char(10)) + 1
    Quit "context_chars="_chars_", approx_tokens="_approxTokens_", lines="_lines
}

Method SearchContext(args As %DynamicObject) As %String
{
    Set query = $ZCONVERT($Get(args.query), "L")
    Set limit = +$Get(args.limit, 5)
    If limit<1 Set limit = 1
    If query="" Quit "ERROR: query is required"

    Set source = ..Context
    Set sourceL = $ZCONVERT(source, "L")
    Set qlen = $Length(query)
    Set pos = 1
    Set hits = 0
    Set out = ""

    For  {
        Set idx = $Find(sourceL, query, pos)
        Quit:idx=0
        Set start = idx - qlen
        Set left = start - 60 If left<1 Set left=1
        Set right = start + qlen + 120 If right>$Length(source) Set right=$Length(source)
        Set snippet = $Extract(source, left, right)

        Set hits = hits + 1
        Set out = out_"[match "_hits_" @char "_start_"] "_snippet_$Char(10,10)
        Quit:hits'<limit
        Set pos = idx
    }

    If hits=0 Quit "No matches for '"_query_"'"
    Quit out
}

Method StoreNote(args As %DynamicObject) As %String
{
    Set note = $Get(args.note)
    If note="" Quit "ERROR: note is required"

    If '$Data(..Notes) {
        Set ..Notes = ##class(%ListOfDataTypes).%New()
    }
    Do ..Notes.Insert(note)
    Quit "stored note #"_..Notes.Count()
}

Method SummarizeNotes() As %String
{
    If '$Data(..Notes) Quit "No notes stored."
    If ..Notes.Count()=0 Quit "No notes stored."

    Set out = "Notes summary:"_$Char(10)
    For i=1:1:..Notes.Count() {
        Set out = out_"- "_..Notes.GetAt(i)_$Char(10)
    }
    Quit out
}

Method Finalize(args As %DynamicObject) As %String
{
    Set result = $Get(args.result)
    If result="" Quit "ERROR: result is required"
    Set ..FinalAnswer = result
    Set ..IsFinalized = 1
    Quit "FINAL: "_result
}

}
