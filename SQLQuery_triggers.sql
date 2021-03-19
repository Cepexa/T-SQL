use Sports_Shop
go

--создаем триггер, который При продаже товара, заносит информацию о продаже в таблицу «История» 
create trigger sports.trHistoryEntry
on sports.table_sale
for insert, update
as
begin
	  IF @@ROWCOUNT = 0
	  RETURN
	  SET NOCOUNT ON
	   
	  IF exists (select * from sports.table_sale where (status_sale = 'Выполнен') or (status_sale = 'Отменён'))				  
		insert into sports.table_history_sale (product_id,date_of_sale,quantity_sale,
												sale_price, id_seller, id_client,status_sale)
		values 
			((select id_product from inserted),
			(select date_of_sale from inserted),
			(select quantity_sale from inserted),
			(select sale_price from inserted),
			(select id_seller from inserted),
			(select id_client from inserted),
			(select status_sale from inserted))
	
		DELETE FROM sports.table_sale where (status_sale = 'Выполнен') or (status_sale = 'Отменён')
end
go

--создаем триггер, который
--Если после продажи товара не осталось ни одной единицы данного товара, переносит информацию 
--о полностью проданном товаре в таблицу «Архив»
create trigger sports.ArchiveEntry
on sports.table_product
for insert, update
as
begin
	  IF @@ROWCOUNT = 0
	  RETURN
	  SET NOCOUNT ON
	if exists (select * from inserted where quantity_in_stock = 0)
	if exists (select * from sports.table_sale where id_product = 
	(select id_prod from inserted where quantity_in_stock = 0))
	return
	else
	begin
		insert into sports.table_archive (product_name, type_product,
										manufacturer, cost_price)
		values ((select name_product from inserted),
			  (select type_product from inserted),
			  (select manufacturer from inserted),
			  (select cost_price from inserted))
		
		 
		DELETE FROM sports.table_product where id_prod = (select id_prod from inserted)
	end
end
go

--создаем триггер, который вычитает количество купленного товара
create trigger trCountProductInsert
on sports.table_sale
for insert
as
begin
	  IF @@ROWCOUNT = 0
	  RETURN
	  SET NOCOUNT ON
	
	 IF exists(select * 
		from inserted i
		inner join sports.table_product k
			on k.quantity_in_stock < i.quantity_sale where k.id_prod = i.id_product)
		begin
			RAISERROR ('Данное количество отсутвует', 12,1)
			ROLLBACK
			RETURN
		end

	update sports.table_product
	set quantity_in_stock = quantity_in_stock - i.quantity_sale
	from inserted i 
	where id_prod = i.id_product
end
go
--создаем триггер, который вычитает количество купленного товара при update
create trigger trCountProductUpdate
on sports.table_sale
for update
as
begin
	  IF @@ROWCOUNT = 0
	  RETURN
	  SET NOCOUNT ON
	
	 IF exists(select * 
		from inserted i
		inner join sports.table_product k
			on k.quantity_in_stock < i.quantity_sale where k.id_prod = i.id_product)
		begin
			RAISERROR ('Данное количество отсутвует', 12,1)
			ROLLBACK
			RETURN
		end

	update sports.table_product
	set quantity_in_stock = quantity_in_stock - i.quantity_sale + d.quantity_sale
	from inserted i, deleted d
	where id_prod = i.id_product
end
go
--создаем триггер, который при удалении не выполненой продажи возвращает исходное количество товаров
create trigger sports.trDeleteString
on sports.table_sale
for delete
as
	update sports.table_product
	set quantity_in_stock = quantity_in_stock + d.quantity_sale
	from deleted d 
	where (id_prod = d.id_product) and (d.status_sale <> ('Выполнен'))
	--обновить таблицу о товарах нужно в любом случае (это для того чтобы при значении 0  данные улетали в архив)
	update sports.table_product
	set quantity_in_stock = quantity_in_stock
	from deleted d 
	where (id_prod = d.id_product) and (d.status_sale = ('Выполнен'))
go
--создаем триггер, который Не позволять регистрировать уже существующего клиента.
--При вставке проверяет наличие клиента по email (ФИО может повторяться)
create trigger sports.trCheckFullName
on sports.table_clients 
for insert, update
as
begin

	IF @@ROWCOUNT = 0
	  RETURN
	  SET NOCOUNT ON
	
	 IF exists(SELECT * FROM sports.table_clients, inserted 
				WHERE inserted.email = sports.table_clients.email and 
				inserted.id_client <> sports.table_clients.id_client)
		begin
			RAISERROR ('Пользователь с таким email уже существует', 10,2)
			ROLLBACK
		end
end
go

--создаем триггер, который Запрещает удаление существующих клиентов
create trigger sports.trProhibitDel
on sports.table_clients 
for delete
as
begin
	RAISERROR ('Запрет на удаление Пользователя', 5,1)
	ROLLBACK
end
go

--создаем триггер, который Запрещает удаление сотрудников, принятых на работу до 2015 года
create trigger sports.trProhibitDelEmployee
on sports.table_employee
for delete
as

	IF exists(SELECT * FROM deleted 
				WHERE deleted.date_of_employment < '01-01-2015')
	begin
		RAISERROR ('Запрет на удаление сотрудника, принятого на работу до 2015 года', 5,1)
		ROLLBACK
	end
go

--создаем триггер, который . При новой покупке товара нужно проверяет общую сумму покупок клиента. 
--Если сумма превысила 50000, устанавливает процент скидки в 15%
create trigger sports.trSetDiscount
on sports.table_sale
for insert, update
as
	IF @@ROWCOUNT = 0
	  RETURN
	  SET NOCOUNT ON
	   
	IF exists(select * from sports.table_history_sale where
				(SELECT sum(sale_price) FROM sports.table_history_sale 
				WHERE status_sale = 'Выполнен' and id_client = (select id_client from inserted)) > 50000)
	begin
		UPDATE sports.table_clients
		set discount_percentage = 15
		from inserted i join sports.table_clients k 
		on k.id_client = i.id_client
		where k.id_client = i.id_client
	end
go

--создаем триггер, который Запрещает добавлять товар конкретной фирмы. 
--Например, товар фирмы «Спорт, солнце и штанга»
create trigger sports.trProhibitAddFirm
on sports.table_product
for insert, update
as
	IF exists(SELECT * FROM inserted 
				WHERE manufacturer = 'Спорт, солнце и штанга')
	begin
		RAISERROR ('Запрет на добавление товаров данной ФИРМЫ', 9,2)
		ROLLBACK
	end
go

--создаем триггер, который При продаже проверяет количество товара в наличии. 
--Если осталась одна единица товара, внесит информацию об этом товаре в таблицу «Последняя Единица».
create trigger sports.trCheckLastUnit
on sports.table_product
for insert, update
as
	IF exists(SELECT * FROM inserted 
				WHERE quantity_in_stock = 1)
	begin
		insert into sports.table_last_unit (product_id,product_name, type_product,
										manufacturer, cost_price, selling_price)
		values ((select id_prod from inserted),
				(select name_product from inserted),
				(select type_product from inserted),
				(select manufacturer from inserted),
				 (select cost_price from inserted),
				 (select selling_price from inserted))
	end
	else
	begin
		DECLARE @key AS int
		SELECT @key = MIN(id_prod) FROM inserted
		WHILE @key IS NOT NULL
		BEGIN
			IF exists(SELECT * FROM sports.table_last_unit
				WHERE product_id =  @key)
			begin
				delete FROM sports.table_last_unit WHERE product_id = (select id_prod from inserted)
			end
  
		SELECT @key = MIN(id_prod) FROM inserted
		 WHERE id_prod > @key
		END
	end
	
go
--создаем триггер, который при удалении продукта очищает и табл последняя единица с этим id
create trigger sports.trCheckLastUnitDel
on sports.table_product
for delete
as 
	if exists (select * from sports.table_last_unit,deleted
		where sports.table_last_unit.product_id = deleted.id_prod)
		delete from sports.table_last_unit where product_id = (select id_prod from deleted)

go