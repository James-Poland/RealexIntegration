Create Proc [Payments].[editcard]
@claimnumber varchar(50)
as begin
Set NoCount On;


OPEN SYMMETRIC KEY CreditCards_Key
	DECRYPTION BY CERTIFICATE DebtCC


IF object_id('tempdb.dbo.#EditCard', 'U') IS NOT NULL
		DROP TABLE #EditCard;
	
SELECT    top 1  ClaimNumber, Currency, CardName, 
case when t.CARDTYPE = 'mastercard' then 'MC' else upper(t.CardType) end as
		CardType,
CONVERT(varchar, DecryptByKey(c.cardnumber))CardNumber, 
Expiry, CVV, CustToken, CardToken, m.MigStatus
into #editcard 
FROM            dbo.CardDetails c
inner join 
CardType t on c.CardType=t.ID
left join Payments.Migration m on m.PAYERREF=c.CustToken
where 
ClaimNumber= @claimnumber
and dbo.fnIsValidCard(CONVERT(varchar, DecryptByKey(c.cardnumber)))=1


--Select top 1 
--		CustToken, CardToken, CardNumber, CardName, Expiry
--		from #editcard
--	where dbo.fnIsValidCard(cardnumber)=1
----	and c.ClaimNumber='2015250'


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
set @exp = (Select expiry from #editcard)
set @payref = (Select CustToken from #editcard) 
set @cardname = (select Cardname from #editcard)
--set @Cardnum = '5425230000004415'
set @Cardnum = (select cardnumber from #editcard)
set @cardref = (Select cardtoken from #editcard)
set @timestamp =convert(varchar(20),CURRENT_TIMESTAMP,112)+replace(convert(varchar, getdate(), 8),':','')
set @orderid =replace(NewID(),'-','')
set @hash1 = (select top 1 SUBSTRING(master.dbo.fn_varbintohexstr(hashbytes('sha1',(Select @timestamp+'.'+'Client'+'.'+@payref+'.'+@cardref+'.'+@exp+'.'+@Cardnum ))),3,40))
set @hash2 = @hash1+'.'+'Pass'
declare @msg xml

set @msg =(
Select top 1
'card-update-card' as "@type" ,@timestamp as "@timestamp" ,
'Client' as merchantid,
@orderid as orderid,
(
Select @cardref as ref,
@payref as payerref, 
		@Cardnum as number, @exp as expdate,
	@cardname as chname,CardType as [type]
	for xml path ('card'),type),
	SUBSTRING(master.dbo.fn_varbintohexstr(hashbytes('sha1',(select @hash1+'.'+'Pass'))),3,128) as sha1hash
	from #editcard
FOR XML PATH('request')
)
select @msg
--Declare @xmltable table (Result xml)
--Insert into @xmltable (Result)
--select @msg
----Select * from #editcard

update Payments.Migration 
set MigStatus = 'Card Loaded', CARDNUMBER='CardLoaded'
where PAYERREF = @payref
--Select * from @xmltable

end

