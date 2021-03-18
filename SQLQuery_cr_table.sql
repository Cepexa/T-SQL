create database Sports_Shop
go 

use Sports_Shop
go

create schema sports
go
--создаём таблицу О товарах
create table sports.table_product(
	id_prod int identity(1,1) primary key,
	name_product nvarchar(30) not null,
	type_product nvarchar(30) not null,
	quantity_in_stock int default(1) not null,
	last_unit bit not null,
	cost_price money not null,
	manufacturer nvarchar(30) not null,
	selling_price money not null
)
go
--создаём таблицу пол
create table sports.table_gender(
	gender varchar(10) primary key
)
go
truncate table sports.table_gender
go
insert into sports.table_gender
values 
('male'),
('female')
go

--создаём таблицу О сотрудниках
create table sports.table_employee(
	id_employee int identity(1,1) primary key,
	surname_employee nvarchar(40) not null,
	name_employee nvarchar(30) not null,
	patronymic nvarchar(40) null,
	post nvarchar(40) not null,
	date_of_employment date default(GETDATE()) not null,
	gender nvarchar(40) not null
)
go
--изменяем (добавляем связь) таблицу о сотрудниках
alter table sports.table_employee alter column gender varchar(10) null
go
alter table sports.table_employee with check add constraint FK_table_employee_table_gender 
foreign key(gender)
references sports.table_gender(gender)
ON UPDATE NO action
ON DELETE SET NULL
go
--создаём таблицу О клиентах
create table sports.table_clients(
	id_client int identity(1,1) primary key,
	surname_client nvarchar(40) not null,
	name_client nvarchar(30) not null,
	patronymic nvarchar(40) null,
	email nvarchar(40) not null,
	phone_number varchar(20) null,
	discount_percentage int default(0) not null,
	subscribe_news bit default(0) not null,
	gender nvarchar(40) not null
)
go
--изменяем (добавляем связь) таблицу о клиентах
alter table sports.table_clients alter column gender varchar(10) null
go
alter table sports.table_clients with check add constraint FK_table_clients_table_gender 
foreign key(gender)
references sports.table_gender(gender)
ON UPDATE NO action
ON DELETE SET NULL
go

--создаём таблицу О продажах
create table sports.table_sale(
	id_sale int identity(1,1) primary key,
	id_product int not null references sports.table_product(id_prod)
	on update cascade on delete cascade,
	date_of_sale date default(GETDATE()) not null,
	quantity_sale int default(1) not null,
	sale_price int not null,
	id_seller int not null references sports.table_employee(id_employee)
	on update no action on delete no action,
	id_client int not null references sports.table_clients(id_client)
	on update no action on delete no action
)
go

--перед изменением удаляем поле
ALTER TABLE sports.table_sale DROP COLUMN sale_price
GO
--функция возвращет ценник товара
create function sports.Price(@id int)
returns money
as
begin
declare @price money

select @price = a.selling_price from sports.table_product a where a.id_prod = @id

return @price
end
go
--функция возвращет процент скидки
create function sports.Discount(@id real)
returns real
as
begin
declare @discount real

select @discount = a.discount_percentage from sports.table_clients a where a.id_client = @id

return @discount
end
go
--добавляем поле вычисляемое по формуле
ALTER TABLE sports.table_sale ADD sale_price AS quantity_sale * sports.Price(id_product) * (100 - sports.Discount(id_client))/100  
go

--изменяем (добавляем поле статус) таблицу О продажах
alter table sports.table_sale
	add status_sale nvarchar(20) default('В обработке') null
go

--добавлем условие заполнения поля
Alter Table sports.table_sale
ADD CONSTRAINT ck_status_sale Check (status_sale IN ('В обработке', 'Выполнен', 'Отменён'))
go

--создаём таблицу Об истории продаж
create table sports.table_history_sale(
	id_history_sale int identity(1,1) primary key,
	product_id int default(0) not null,
	date_of_sale date default(GETDATE()) not null,
	quantity_sale int default(0) not null,
	sale_price int default(0) not null,
	id_seller int default(0) not null,
	id_client int default(0) not null,
	status_sale nvarchar(20) default('Выполнен') null
)
go


--создаём таблицу Архив
create table sports.table_archive(
	id_archive int identity(1,1) primary key,
	product_name nvarchar(30) null,
	type_product nvarchar(30) null,
	manufacturer nvarchar(30) null,
	cost_price int null,
	date_of_transfer date default(GETDATE()) not null
)
go


insert into sports.table_product(name_product,type_product,
								quantity_in_stock,last_unit,
								cost_price,selling_price,manufacturer) 
values
('Кроссовки','Обувь', 10,0,1000,3000,'adidas'),
('Бейсболка','Одежда',20,0,700, 2500,'nike'),
('Носки',    'Одежда',25,0,550, 1500,'GUCCI'),
('Футболка', 'Одежда',19,0,1200,3200,'reebok'),
('Бутсы',    'Обувь', 31,0,600, 2800,'puma')
go

update sports.table_product
set quantity_in_stock = 23
where id_prod = 3
go

insert into sports.table_employee(surname_employee,name_employee,patronymic,
								post,date_of_employment,gender) 
values
('Безликов','Андрей','Геннадьевич', 'Продавец','12-05-2019','male'),
('Карликов','Гном','Гномович', 'Продавец','03-12-2019','male'),
('Угрюмова','Изольда','Карловна', 'Продавец','13-01-2020','female'),
('Домоседов','Петр','Аркадьевич', 'Продавец','11-05-2017','male'),
('Высокова','Виктория','Андреевна', 'Старший менеджер','10-10-2013','female')
go

insert into sports.table_clients(surname_client,name_client,patronymic,
								email,phone_number,discount_percentage,
								subscribe_news,gender) 
values
('Абрамович','Роман','Аркадьевич', 'Abram@mail.ru','+7(999)999-99-99',default,1,'male'),
('Аршавин','Андрей','Сергеевич', 'Arsha@mail.ru','+7(666)666-66-66',default,1,'male'),
('Бузова','Ольга','Игоревна', 'Obuza@mail.ru','+7(987)654-32-10',default,1,'female'),
('Архангел','Михаил','Богович', 'AAA@mail.ru','+7(777)777-77-77',default,1,'male')
go

insert into sports.table_sale(id_product,quantity_sale,
								id_seller,id_client) 
values
(17,5,3,2)
go




truncate table sports.table_histiry_sale
go

delete from sports.table_product
go

drop table sports.table_gender
go


drop table sports.table_product
 go

drop table sports.table_sale
 go

drop table sports.table_employee
 go

drop table sports.table_clients
go

drop table sports.table_history_sale
 go

 drop table sports.table_archive
 go


drop schema sports
go

drop database Sports_Shop
go
