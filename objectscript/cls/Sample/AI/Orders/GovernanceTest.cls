Include (%AI, %occStatus)

/// Executable smoke test for the governed Orders sample.
Class Sample.AI.Orders.GovernanceTest
{

/// Run from the application namespace:
///   Do ##class(Sample.AI.Orders.GovernanceTest).Run()
/// ExpectWrite must match whether the current IRIS identity has USE permission
/// on Sample_Orders_Write. Local container terminals normally have %All.
ClassMethod Run(ExpectWrite As %Boolean = 1) As %Status
{
    Set sc = $$$OK
    Try {
        Set sc = ##class(Sample.AI.Orders.Setup).Load()
        If $$$ISERR(sc) $$$ThrowStatus(sc)

        Set tools = ##class(Sample.AI.Tools.OrderManagement).%New()
        Set order = tools.GetOrder("ORD-001")
        If order.%IsDefined("error") {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "GetOrder failed: " _ order.error))
        }
        If order.orderId '= "ORD-001" {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "GetOrder returned the wrong order"))
        }
        Write "PASS read ORD-001 as ", $USERNAME, !

        Set policy = ##class(Sample.AI.Policies.OrdersAccessPolicy).%New()
        Set call = {"name":"UpdateOrderStatus"}

        Set sc = policy.%CanExecute("iris:orders", call, {"Access":"read"})
        If $$$ISERR(sc) $$$ThrowStatus(sc)
        Write "PASS read authorization", !

        Set writeSC = policy.%CanExecute("iris:orders", call, {"Access":"write"})
        If ExpectWrite, $$$ISERR(writeSC) $$$ThrowStatus(writeSC)
        If 'ExpectWrite, $$$ISOK(writeSC) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Write was allowed but denial was expected"))
        }
        Write "PASS write authorization expected=", ExpectWrite, !

        Set before = ..AuditCount()
        Set audit = ##class(Sample.AI.Policies.OrdersAuditPolicy).%New()
        Set sc = audit.%LogExecution(call, {}, {}, 12, $$$OK)
        If $$$ISERR(sc) $$$ThrowStatus(sc)
        Set after = ..AuditCount()
        If after '= (before + 1) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Audit row count did not increase by one"))
        }
        Write "PASS sanitized audit persistence", !
        Write "Governance smoke test passed.", !
    } Catch ex {
        Set sc = ex.AsStatus()
        Write "FAIL ", $SYSTEM.Status.GetErrorText(sc), !
    }
    Return sc
}

ClassMethod AuditCount() As %Integer [ Private ]
{
    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare("SELECT COUNT(*) FROM Sample_AI_Orders.AuditLog")
    If $$$ISERR(sc) $$$ThrowStatus(sc)
    Set rs = stmt.%Execute()
    If 'rs.%Next(.sc) $$$ThrowStatus(sc)
    Return rs.%GetData(1)
}

}
