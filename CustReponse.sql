Create proc [Payments].[CustResponse]
(@orderid varchar(50), @result varchar(50), @msg xml)
as begin
Set NoCount on;

Insert into Payments.CardRequests (OrderID, MsgType, MsgDate, MsgResult, MsgContent)
Values
(@orderid, 'Response', getdate(), @result, @msg)


update P1
set p1.Payerref=p2.Payerref
from Payments.CardRequests p1
inner join Payments.CardRequests p2
on p1.OrderID=p2.OrderID
and p2.MsgType='card-new'
and p2.id<p1.id

update m
set m.MigStatus = 'CardLoaded', m.CARDNUMBER = 'CardLoaded'
from Payments.Migration m
inner join 
Payments.CardRequests CR  on
replace(m.PAYMENTREF,' ','_')  =cr.Payerref
where cr.MsgType='Response' and cr.MsgResult='Successful'
and m.MigStatus !='CardLoaded'

end
