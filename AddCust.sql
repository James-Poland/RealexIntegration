Create Proc [Payments].[AddCust] 
@claimnumber varchar(50)
as Begin
Set NoCount on;

OPEN SYMMETRIC KEY CreditCards_Key
	DECRYPTION BY CERTIFICATE DebtCC

insert into  Payments.Migration
Select 
'Retail' as PAYERTYPE,
p.ST_NUMBER +' '+convert(varchar(10),cc.claimnumber) as PAYERREF,
replace(cc.Claimnumber,' ','*') +'_' + right(CONVERT(varchar, DecryptByKey(cc.cardnumber)),4) as PAYMENTREF,
 parsename(replace(p.ST_PROPOSER, ' ', '.'), 3) as Title,
 parsename(replace(p.ST_PROPOSER, ' ', '.'), 2) as FirstName,
 parsename(replace(p.ST_PROPOSER, ' ', '.'), 1) as LastName,
CONVERT(varchar, DecryptByKey(cc.cardnumber)) as CARDNUMBER,
Expiry as CARDEXPIRYDATE,
CardName as CARDHOLDERNAME,
t.CardType as CARDTYPE,
NULL
from 
DebtManagement.dbo.XSD02_POLICY p 
inner join DebtManagement.dbo.XSD10_CLAIM_STATIC_DATA c on p.ID_POLICY = c.FK_XSD02_XSD10_POLICY
inner join DebtManagement.dbo.VW_ClaimDebtStatus cs on c.ST_NUMBER=cs.ClaimNumber
inner join CardDetails cc on cs.ClaimNumber=cc.ClaimNumber
inner join CardType t on cc.CardType=t.ID
left join Payments.Migration m on p.ST_NUMBER +' '+convert(varchar(10),cc.claimnumber)=m.PAYERREF
where 
cs.closingdebt >0
and dbo.fnIsValidCard(CONVERT(varchar, DecryptByKey(cc.cardnumber)))=1
and m.PAYERREF is null
and cc.ClaimNumber =@claimnumber


IF object_id('tempdb.dbo.#debt', 'U') IS NOT NULL
		DROP TABLE #debt;

		Select top 1
		Payerref, Title, FirstName, Lastname
		into #debt
		from Payments.Migration where migstatus is null and
		left(PAYMENTREF, charindex('_', PAYMENTREF) -1)=@claimnumber

Declare @timestamp varchar(50)
Declare @orderid varchar(50)
Declare @xsref varchar(50)
Declare @hash1 varchar(100)
declare @hash2 varchar (100)
set @timestamp =convert(varchar(20),CURRENT_TIMESTAMP,112)+replace(convert(varchar, getdate(), 8),':','')
set @orderid =replace(NewID(),'-','')
set @xsref = (Select top 1 PayerRef from #debt)
set @hash1 = (select top 1 SUBSTRING(master.dbo.fn_varbintohexstr(hashbytes('sha1',(Select @timestamp+'.'+'Client'+'.'+@orderid+'...'+@xsref ))),3,40))
set @hash2 = @hash1+'.'+'Pass'
declare @msg xml

set @msg =(
Select top 1
'payer-new' as "@type" ,@timestamp as "@timestamp" ,
'Client' as merchantid,
'internet' as account,
@orderid as orderid,
(Select @xsref as "@ref", 'Retail' as "@type",
 Title as Title,
 FirstName as FirstName,
 LastName as LastName
FOR XML PATH('payer'),type),
SUBSTRING(master.dbo.fn_varbintohexstr(hashbytes('sha1',(select @hash1+'.'+'Pass'))),3,40) as sha1hash
from
#debt
FOR XML PATH('request')
)
select @msg

Insert into Payments.CardRequests
Select @xsref, @orderid, 'payer-new' as MsgType,getdate() as MsgDate,NULL, @msg 

update Payments.Migration
set MigStatus ='PayerSent'
where payerref= @xsref

Close SYMMETRIC KEY CreditCards_Key


End
