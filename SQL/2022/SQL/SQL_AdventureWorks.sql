-- Nguồn data: https://drive.google.com/file/d/1JLinOZgfeBYsEGXeRlky9b8Tw50X3wZT/view?usp=sharing

use AdventureWorks
go

-- Tạo khóa ngoại
alter table sales_2015
add foreign key (productkey) references products(productkey)
alter table sales_2015
add foreign key (customerkey) references customers(customerkey)
alter table sales_2015
add foreign key (territorykey) references territories(salesterritorykey)

alter table sales_2016
add foreign key (productkey) references products(productkey)
alter table sales_2016
add foreign key (customerkey) references customers(customerkey)
alter table sales_2016
add foreign key (territorykey) references territories(salesterritorykey)

alter table sales_2017
add foreign key (productkey) references products(productkey)
alter table sales_2017
add foreign key (customerkey) references customers(customerkey)
alter table sales_2017
add foreign key (territorykey) references territories(salesterritorykey)

alter table products
add foreign key (productsubcategorykey) references subcategories(productsubcategorykey)
alter table subcategories
add foreign key (productcategorykey) references categories(productcategorykey)
alter table Returns
add foreign key (territorykey) references territories(salesterritorykey)
alter table Returns
add foreign key (productkey) references products(productkey)

-----------
select * from Categories
select * from Customers
select * from Products
select * from Returns
select * from Sales_2015
select * from Subcategories
select * from Territories
------------

-- Truy vấn
-- Câu 1. Doanh thu, Chi phí, Lợi nhuận, Biên lợi nhuận gộp năm 2015, 2016, 2017
with Sales as (
	select * from Sales_2015
	union all
	select * from Sales_2016
	union all
	select * from Sales_2017
)

select datepart(YEAR, S.OrderDate) [Year]
	, round(sum(S.OrderQuantity*P.ProductCost), 2) [COGS]
	, round(sum(S.OrderQuantity*P.ProductPrice), 2) [Revenue]
	, round(sum(S.OrderQuantity*P.ProductPrice - S.OrderQuantity*P.ProductCost), 2) [Profit]
	, round(sum(S.OrderQuantity*P.ProductPrice - S.OrderQuantity*P.ProductCost)/sum(S.OrderQuantity*P.ProductPrice), 2) [Groѕѕ Profit Margin]
from Sales S join Products P
on S.ProductKey = P.ProductKey
group by datepart(YEAR, S.OrderDate)
order by datepart(YEAR, S.OrderDate)

-- Câu 2. Top 3 sản phẩm có số lượng bán cao nhất của mỗi danh mục trong năm 2016
select CategoryName, ProductName, TotalOrderQuantity from (
	select A.CategoryName, A.ProductName, A.TotalOrderQuantity
		, rank() over(partition by A.CategoryName order by A.TotalOrderQuantity desc) [Rank]
	from (
		select C.CategoryName, P.ProductName, sum(S.OrderQuantity) TotalOrderQuantity
		from Sales_2016 S join Products P on S.ProductKey = P.ProductKey
			join Subcategories Sc on P.ProductSubcategoryKey = Sc.ProductSubcategoryKey
			join Categories C on Sc.ProductCategoryKey = C.ProductCategoryKey
		group by C.CategoryName, P.ProductName
	) as A
) as B
where [Rank] between 1 and 3
order by CategoryName

-- Câu 3. Top 3 sản phẩm bán tốt nhất tại từng khu vực năm 2016
select Region, ProductName, TotalOrderQuantity from (
	select A.Region, A.ProductName, A.TotalOrderQuantity,
		rank() over(partition by A.Region order by A.TotalOrderQuantity desc) [Rank]
	from (
		select T.Region, P.ProductName, sum(S.OrderQuantity) TotalOrderQuantity
		from Sales_2016 S join Products P on S.ProductKey = P.ProductKey
			join Territories T on S.TerritoryKey = T.SalesTerritoryKey
		group by T.Region, P.ProductName
	) as A
) as B
where [Rank] between 1 and 3
order by Region

-- Câu 4. Lợi nhuận bán hàng của công ty chủ yếu do những mặt hàng nào? (80/20)
declare @TotalProfit as float

select @TotalProfit = sum(S.OrderQuantity*(P.ProductPrice - P.ProductCost))
from Sales_2017 S join Products P on S.ProductKey = P.ProductKey
	join Subcategories Sc on P.ProductSubcategoryKey = Sc.ProductSubcategoryKey
	join Categories C on Sc.ProductCategoryKey = C.ProductCategoryKey

select CategoryName, ProductName, [Profit], [CumSum], [CumFre]
from (
	select CategoryName, ProductName, [Profit], 
		round(sum([Profit]) over(order by [Profit] desc),2) as [CumSum],
		round((sum([Profit]) over(order by [Profit] desc))*100/@TotalProfit,2) as [CumFre]
	from (
		select C.CategoryName, P.ProductName, sum(S.OrderQuantity*(P.ProductPrice - P.ProductCost)) [Profit] 
		from Sales_2017 S join Products P on S.ProductKey = P.ProductKey
			join Subcategories Sc on P.ProductSubcategoryKey = Sc.ProductSubcategoryKey
			join Categories C on Sc.ProductCategoryKey = C.ProductCategoryKey
		group by P.ProductName, C.CategoryName
	) as A
) as B
where [CumFre] <= 80

-- Câu 5. Top 3 sản phẩm bị trả lại nhiều nhất ở mỗi danh mục trong năm 2016
select CategoryName, ProductName, TotalReturnQuantity from (
	select A.CategoryName, A.ProductName, A.TotalReturnQuantity
		, rank() over(partition by A.CategoryName order by A.TotalReturnQuantity desc) [Rank]
	from (
		select C.CategoryName, P.ProductName, sum(R.ReturnQuantity) TotalReturnQuantity
		from Returns R join Products P on R.ProductKey = P.ProductKey
			join Subcategories Sc on P.ProductSubcategoryKey = Sc.ProductSubcategoryKey
			join Categories C on Sc.ProductCategoryKey = C.ProductCategoryKey
		where year(R.ReturnDate) = 2016
		group by C.CategoryName, P.ProductName
	) as A
) as B
where [Rank] between 1 and 3
order by CategoryName

-- Câu 6. Nhu cầu mua sản phẩm từng danh mục theo từng tháng trong năm 2016
select datepart(month, S.OrderDate) [Month]
	, count(case when C.CategoryName = 'Bikes' then S.OrderNumber end) [Bikes]
	, count(case when C.CategoryName = 'Components' then S.OrderNumber end) [Components]
	, count(case when C.CategoryName = 'Clothing' then S.OrderNumber end) [Clothing]
	, count(case when C.CategoryName = 'Accessories' then S.OrderNumber end) [Accessories]
from Sales_2016 S join Products P on S.ProductKey = P.ProductKey
	join Subcategories Sc on P.ProductSubcategoryKey = Sc.ProductSubcategoryKey
	join Categories C on Sc.ProductCategoryKey = C.ProductCategoryKey
group by datepart(month, S.OrderDate)
order by datepart(month, S.OrderDate)

-- Câu 7. Xác định ngày đặt hàng đầu tiên và cuối cùng của từng khách hàng
with F_Sales as (
		select * from Sales_2015
		union all
		select * from Sales_2016
		union all
		select * from Sales_2017
	)
	, FirstOrder as (
		select CustomerKey, FirstName, LastName, OrderDate [FirstOrderDate] from (
			select A.CustomerKey, A.FirstName, A.LastName, A.OrderDate
				, rank() over(partition by A.CustomerKey order by A.OrderDate) [Rank]
			from (
				select C.CustomerKey, C.FirstName, C.LastName, S.OrderDate
				from F_Sales S join Customers C on S.CustomerKey = C.CustomerKey
				group by C.CustomerKey, C.FirstName, C.LastName, S.OrderDate
			) as A
		) as B
		where [Rank] = 1
	)
	, L_Sales as (
		select * from Sales_2015
		union all
		select * from Sales_2016
		union all
		select * from Sales_2017
	)
	, LastOrder as (
		select CustomerKey, FirstName, LastName, OrderDate [LastOrderDate] from (
			select A.CustomerKey, A.FirstName, A.LastName, A.OrderDate
				, rank() over(partition by A.CustomerKey order by A.OrderDate desc) [Rank]
			from (
				select C.CustomerKey, C.FirstName, C.LastName, S.OrderDate
				from L_Sales S join Customers C on S.CustomerKey = C.CustomerKey
				group by C.CustomerKey, C.FirstName, C.LastName, S.OrderDate
			) as A
		) as B
		where [Rank] = 1
	)

select F.CustomerKey, F.FirstName, F.LastName, F.FirstOrderDate
	, case when F.FirstOrderDate = L.LastOrderDate then null else L.LastOrderDate end as LastOrderDate
from FirstOrder F left join LastOrder L on F.CustomerKey = L.CustomerKey
order by F.CustomerKey
