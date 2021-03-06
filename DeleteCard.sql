Create Proc [Payments].[deletecard]
@claimnumber varchar(50)
as begin
Set NoCount On;


OPEN SYMMETRIC KEY Crdeletecards_Key
	DECRYPTION BY CERTIFICATE DebtCC


IF object_id('tempdb.dbo.#deletecard', 'U') IS NOT NULL
		DROP TABLE #deletecard;
	
SELECT    top 1  ClaimNumber, Currency, CardName, 
case when t.CARDTYPE = 'mastercard' then 'MC' else upper(t.CardType) end as
		CardType,
CONVERT(varchar, DecryptByKey(c.cardnumber))CardNumber, 
Expiry, CVV, CustToken, CardToken, m.MigStatus
into #deletecard 
FROM            dbo.CardDetails c
inner join 
CardType t on c.CardType=t.ID
left join Payments.Migration m on m.PAYERREF=c.CustToken
where 
ClaimNumber= @claimnumber
and dbo.fnIsValidCard(CONVERT(varchar, DecryptByKey(c.cardnumber)))=1




Declare @timestamp varchar(50)
Declare @orderid varchar(50)
Declare @payref varchar(50)
declare @ref varchar(50)
Declare @cardname varchar(50)
Declare @Cardnum varchar(50)
Declare @hash1 varchar(100)
declare @hash2 varchar (100)
declare @cardref varchar(50)
declare @exp varchar(4)
set @exp = (Select expiry from #deletecard)
set @payref = (Select CustToken from #deletecard) 
set @cardname = (select Cardname from #deletecard)
set @Cardnum = (select cardnumber from #deletecard)
set @cardref = (Select cardtoken from #deletecard)
set @timestamp =convert(varchar(20),CURRENT_TIMESTAMP,112)+replace(convert(varchar, getdate(), 8),':','')
set @orderid =replace(NewID(),'-','')
set @hash1 = (select top 1 SUBSTRING(master.dbo.fn_varbintohexstr(hashbytes('sha1',(Select @timestamp+'.'+'Client'+'.'+@payref+'.'+@cardref+'.'+@exp+'.'+@Cardnum ))),3,40))
set @hash2 = @hash1+'.'+'Pass'
declare @msg xml

set @msg =(
Select top 1
'card-update-card' as "@type" ,@timestamp as "@timestamp" ,
'xsdirect' as merchantid,
@orderid as orderid,
(
Select @cardref as ref,
@payref as payerref, 
		@Cardnum as number, @exp as expdate,
	@cardname as chname,CardType as [type]
	for xml path ('card'),type),
	SUBSTRING(master.dbo.fn_varbintohexstr(hashbytes('sha1',(select @hash1+'.'+'Pass'))),3,128) as sha1hash
	from #deletecard
FOR XML PATH('request')
)
select @msg


update Payments.Migration 
set MigStatus = 'Card Loaded', CARDNUMBER='CardLoaded'
where PAYERREF = @payref
--Select * from @xmltable

end

