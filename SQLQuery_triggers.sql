use Sports_Shop
go

--������� �������, ������� ��� ������� ������, ������� ���������� � ������� � ������� ��������� 
create trigger sports.trHistoryEntry
on sports.table_sale
for insert, update
as
begin
	  IF @@ROWCOUNT = 0
	  RETURN
	  SET NOCOUNT ON
	   
	  IF exists (select * from sports.table_sale where (status_sale = '��������') or (status_sale = '������'))				  
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
	
		DELETE FROM sports.table_sale where (status_sale = '��������') or (status_sale = '������')
end
go

--������� �������, �������
--���� ����� ������� ������ �� �������� �� ����� ������� ������� ������, ��������� ���������� 
--� ��������� ��������� ������ � ������� ������
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

--������� �������, ������� �������� ���������� ���������� ������
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
			RAISERROR ('������ ���������� ���������', 12,1)
			ROLLBACK
			RETURN
		end

	update sports.table_product
	set quantity_in_stock = quantity_in_stock - i.quantity_sale
	from inserted i 
	where id_prod = i.id_product
end
go
--������� �������, ������� �������� ���������� ���������� ������ ��� update
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
			RAISERROR ('������ ���������� ���������', 12,1)
			ROLLBACK
			RETURN
		end

	update sports.table_product
	set quantity_in_stock = quantity_in_stock - i.quantity_sale + d.quantity_sale
	from inserted i, deleted d
	where id_prod = i.id_product
end
go
--������� �������, ������� ��� �������� �� ���������� ������� ���������� �������� ���������� �������
create trigger sports.trDeleteString
on sports.table_sale
for delete
as
	update sports.table_product
	set quantity_in_stock = quantity_in_stock + d.quantity_sale
	from deleted d 
	where (id_prod = d.id_product) and (d.status_sale <> ('��������'))
	--�������� ������� � ������� ����� � ����� ������ (��� ��� ���� ����� ��� �������� 0  ������ ������� � �����)
	update sports.table_product
	set quantity_in_stock = quantity_in_stock
	from deleted d 
	where (id_prod = d.id_product) and (d.status_sale = ('��������'))
go
--������� �������, ������� �� ��������� �������������� ��� ������������� �������.
--��� ������� ��������� ������� ������� �� email (��� ����� �����������)
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
			RAISERROR ('������������ � ����� email ��� ����������', 10,2)
			ROLLBACK
		end
end
go

--������� �������, ������� ��������� �������� ������������ ��������
create trigger sports.trProhibitDel
on sports.table_clients 
for delete
as
begin
	RAISERROR ('������ �� �������� ������������', 5,1)
	ROLLBACK
end
go

--������� �������, ������� ��������� �������� �����������, �������� �� ������ �� 2015 ����

create trigger sports.trProhibitDelEmployee
on sports.table_employee
for delete
as

	IF exists(SELECT * FROM deleted 
				WHERE deleted.date_of_employment < '01-01-2015')
	begin
		RAISERROR ('������ �� �������� ����������, ��������� �� ������ �� 2015 ����', 5,1)
		ROLLBACK
	end
go