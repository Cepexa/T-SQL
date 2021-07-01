USE Sports_Shop
go

--создаём процедуру, которая отображает полную информацию о всех товарах
create procedure prFullInfoProduct
as
select * from sports.table_product
go
exec prFullInfoProduct
go

--создаём процедуру, которая показывает полную информацию
--о товаре конкретного вида. Вид товара передаётся в качестве параметра.
--Например, если в качестве параметра указана обувь, нужно показать всю обувь,
--которая есть в наличии
create procedure prInfoProductOnType (@type nvarchar(30))
as
select * from sports.table_product where type_product = @type
go
exec prInfoProductOnType @type='Обувь'
go

--создаём процедуру, которая показывает топ-3 самых старых клиентов.
--Топ-3 определяется по дате регистрации
create procedure prOldClientTop3
as
select Top 3 * from sports.table_clients order by date_of_registration
go
exec prOldClientTop3
go

--создаём процедуру, которая показывает информацию о самом
--успешном продавце. Успешность определяется по общей сумме продаж за всё время.
create procedure prBestSeller
as
declare @count_seller int
declare @best_sum int = 0
declare @id_best_seller int = null
select @count_seller=count(*) from sports.table_employee

while(@count_seller !=0)
begin
if exists (select * from sports.table_history_sale
where (select sum(sale_price) from sports.table_history_sale
where id_seller=@count_seller and status_sale = 'Выполнен')>@best_sum)
begin
select @best_sum = (select sum(sale_price) from sports.table_history_sale
where id_seller=@count_seller and status_sale = 'Выполнен')
select @id_best_seller = @count_seller
end

set @count_seller= @count_seller-1
end
select * from sports.table_employee where id_employee = @id_best_seller
Print ('сумма продаж лучшим работником за все время: ' + convert(char(50),@best_sum))
go
exec prBestSeller
go


--создаём процедуру, которая проверяет есть ли хоть один товар указанного производителя в наличии.
--Название производителя передаётся в качестве параметра.
--По итогам работы хранимая процедура должна вернуть yes в том случае, если
--товар есть, и no, если товара нет
create procedure prCheckAvailability(@manuf nvarchar(30))
as
if exists (select * from sports.table_product where manufacturer = @manuf and
quantity_in_stock > 0)
Print ('YES')
else
Print ('NO')
go
exec prCheckAvailability @manuf = 'adidas'
go

--создаём процедуру, которая отображает информацию о самом популярном производителе
--среди покупателей. Популярность среди покупателей определяется по общей сумме продаж
create procedure prPopularProduct
as
declare @best_manuf nvarchar(30)
declare @sum int
declare @max_sum int = 0
declare @count_sale int
declare @manuf nvarchar(30)
select @count_sale = min(id_history_sale) from sports.table_history_sale
select @manuf = manufacturer from sports.table_product
where id_prod = (select product_id from sports.table_history_sale
where id_history_sale = @count_sale)
while(@count_sale is not null)
begin
select @sum = sum(sale_price) from sports.table_history_sale where
status_sale = 'Выполнен' and product_id = (
select id_prod from sports.table_product where manufacturer = @manuf)
if (@max_sum < @sum)
begin
set @best_manuf =@manuf
set @max_sum = @sum
end
select @count_sale = min(id_history_sale) from sports.table_history_sale
where id_history_sale > @count_sale
end
Print ('ЛУЧШИЙ ПРОИЗВОДИТЕЛЬ: ' +@best_manuf)
go
exec prPopularProduct
go


--создаём процедуру, которая удаляет всех клиентов, зарегистрированных после указанной даты.
--Дата передаётся в качестве параметра. Процедура возвращает количество удаленных записей.
create procedure prDelClientsOnDate(@date date)
as
DISABLE TRIGGER sports.trProhibitDel ON sports.table_clients
declare @count_del int
select @count_del = count(*) from sports.table_clients where date_of_registration > @date
delete from sports.table_clients where date_of_registration > @date;
ENABLE TRIGGER sports.trProhibitDel ON sports.table_clients
go
exec prDelClientsOnDate @date = '2020-12-31'
go

--пример кластеризованных индексов
CREATE CLUSTERED INDEX IX_Product_IdProd
ON sports.table_product (id_prod);
GO
--пример некластеризованных индексов
CREATE NONCLUSTERED INDEX IX_Product_Manufacturer
ON sports.table_product (manufacturer);
GO

--пример составного индекса
CREATE UNIQUE INDEX IX_Employee_Full_Name
ON sports.table_employee (surname_employee,name_employee, patronymic)
WITH FILLFACTOR= 80;
go


--создаём функцию, которая возвращает количество уникальных покупателей
create function sports.Unique_Clients()
returns int
as
begin
declare @count int

select @count = count(*) from sports.table_clients

return @count
end
go
select sports.Unique_Clients()
go
--создаём функцию, которая возвращает среднюю цену товара конкретного вида.
--Вид товара передаётся в качестве параметра. Например, среднюю цену обуви
create function sports.Average_Price(@type nvarchar(30))
returns money
as
begin
declare @AVG_Price money

select @AVG_Price = AVG(selling_price) from sports.table_product
where type_product = @type

return @AVG_Price
end
go
select sports.Average_Price('обувь')
go

--создаём функцию, которая возвращает среднюю цену
--продажи по каждой дате, когда осуществлялись продажи
create function sports.Average_Price_On_Date()
returns @new_Table
table (AVG_Price money, date_selling date)
as
begin
declare @AVG_Price money
declare @date_selling table (id int identity (1,1) Primary key, date_s date)
insert @date_selling select DISTINCT date_of_sale from sports.table_history_sale
where status_sale = 'Выполнен'
declare @count_id int
select @count_id = count(*) from @date_selling
while (@count_id != 0)
begin
select @AVG_Price = AVG(sale_price) from sports.table_history_sale
where date_of_sale = (select date_s from @date_selling
where id = @count_id)
insert @new_Table select @AVG_Price, a.date_s from @date_selling a
where id = @count_id
set @count_id = @count_id - 1
end

return
end
go
select * from sports.Average_Price_On_Date()
go


--создаём функцию, которая возвращает информацию о последнем проданном товаре.
--Критерий определения последнего проданного товара: дата продажи
create function sports.Info_Last_Sale(@date date)
returns @new_Table
table (Product_id int, date_selling date, quantity_sale int,
sale_price money, id_seller int, id_client int, manufacturer nvarchar(30))
as
begin
insert @new_Table select product_id, date_of_sale, quantity_sale,
sale_price, id_seller,id_client,manufacturer
from sports.table_history_sale
where status_sale = 'Выполнен' and id_history_sale =
(select max(id_history_sale) from sports.table_history_sale
where date_of_sale = @date)


return
end
go
select * from sports.Info_Last_Sale('2021-03-19')
go

--создаём функцию, которая возвращает информацию о первом проданном товаре.
--Критерий определения первого проданного товара: дата продажи.
create function sports.Info_First_Sale(@date date)
returns @new_Table
table (Product_id int, date_selling date, quantity_sale int,
sale_price money, id_seller int, id_client int, manufacturer nvarchar(30))
as
begin
insert @new_Table select product_id, date_of_sale, quantity_sale,
sale_price, id_seller,id_client,manufacturer
from sports.table_history_sale
where status_sale = 'Выполнен' and id_history_sale =
(select min(id_history_sale) from sports.table_history_sale
where date_of_sale = @date)


return
end
go
select * from sports.Info_First_Sale('2021-03-19')
go


--создаём функцию, которая возвращает информацию о заданном виде товаров конкретного производителя.
--Вид товара и название производителя передаются в качестве параметров
create function sports.Info_Product_on_type_name(@manufacturer nvarchar(30) ,@type nvarchar(30))
returns @new_Table
table (id_prod int, name_product nvarchar(30),type_product nvarchar(30),
quantity_in_stock int, cost_price money,
manufacturer nvarchar(30),selling_price money)
as
begin
insert @new_Table select id_prod, name_product, type_product,
quantity_in_stock, cost_price,manufacturer,selling_price
from sports.table_product
where manufacturer = @manufacturer and type_product = @type

return
end
go
select * from sports.Info_Product_on_type_name('adidas','обувь')
go

--создаём функцию, которая возвращает информацию о покупателях,
--которым в этом году исполнится 35 лет.
create function sports.Info_45old_clients()
returns @new_Table table (id_client int, surname_client nvarchar(40),
name_client nvarchar(30), patronymic nvarchar(40),
email nvarchar(40), phone_number varchar(20), discount_percentage int,
subscribe_news bit, gender varchar(10), date_of_registration date, date_bithday date)
as
begin
insert @new_Table select id_client, surname_client, name_client,
patronymic,email,phone_number,discount_percentage,
subscribe_news, gender,date_of_registration, date_bithday
from sports.table_clients
where 35 = YEAR(GETDATE()) - YEAR(date_bithday)


return
end
go
select * from sports.Info_45old_clients()
go
