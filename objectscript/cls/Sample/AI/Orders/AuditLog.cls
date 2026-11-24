/// Minimal, privacy-preserving audit record for governed order tools.
/// Tool arguments and results are intentionally not persisted.
Class Sample.AI.Orders.AuditLog Extends %Persistent
{

Property EventTime As %TimeStamp;

Property UserName As %String(MAXLEN = 128);

Property ToolName As %String(MAXLEN = 128);

Property Outcome As %String(VALUELIST = ",success,error");

Property DurationMs As %Integer(MINVAL = 0);

Index TimeIndex On EventTime;

}
