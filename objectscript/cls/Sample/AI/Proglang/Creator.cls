/// Person who created a programming language.
/// Serial object embedded as a nested property on Sample.AI.Proglang.Language.
Class Sample.AI.Proglang.Creator Extends (%SerialObject, %JSON.Adaptor, %XML.Adaptor)
{

Property FirstName As %String(MAXLEN = 100);

Property LastName As %String(MAXLEN = 100);

Property Email As %String(MAXLEN = 255);

Property Company As %String(MAXLEN = 255);

}
