
-- Tìm ra 10 khách hàng có doanh thu mua hàng nhiều nhất năm 2016.
select * from (
	select c.CustomerKey, 
		FirstName, 
		LastName, 
		concat(FirstName, ' ', LastName) FullName,
		sum(Sales) TotalRevenue, 
		row_number() over (order by sum(Sales) desc) Ranking
	from Sales_2016 inner join AdventureWorks_Customers$ c
			on Sales_2016.CustomerKey=c.CustomerKey
	group by c.CustomerKey, FirstName, LastName) t
where Ranking between 1 and 10


--Thống kê số lượng đơn hàng, tổng số sản phẩm được đặt, tổng doanh thu qua từng tháng trong năm 2016.
select year(OrderDate) YearOrder, 
	month(OrderDate) MonthOrder, 
	count (distinct OrderNumber) NrOfOrder, 
	sum(OrderQuantity) TotalQuantity, 
	sum(Sales) TotalSales
from Sales_2016
group by year(OrderDate), month(OrderDate) 


--Phân tích hiệu suất hàng tháng của từng sản phẩm bằng việc so sánh tổng doanh thu mỗi tháng với tổng doanh thu của tháng trước đó và doanh thu trung bình qua các tháng.
with table1 as (
	select datepart(month, OrderDate) MonthOrder, 
		p.ProductKey, 
		p.ProductName, 
		sum(Sales) TotalSales
	from Sales_2016 inner join AdventureWorks_Products$ p 
			on Sales_2016.ProductKey = p.ProductKey
	group by datepart(month, OrderDate), p.ProductKey, p.ProductName
)
select *, 
	lag(TotalSales) over (partition by ProductKey order by MonthOrder) PreviousSales, 
	TotalSales - lag(TotalSales) over (partition by ProductKey order by MonthOrder) Diff_Sales, 
	case when TotalSales - lag(TotalSales) over (partition by ProductKey order by MonthOrder) > 0 then N'Tăng'
		 when TotalSales - lag(TotalSales) over (partition by ProductKey order by MonthOrder) < 0 then N'Giảm'
		 else N'Không đổi'
	end Status_Sales, 
	avg(TotalSales) over (partition by ProductKey) TotalAvgSales, 
	TotalSales - avg(TotalSales) over (partition by ProductKey) Diff_Avg_Sales,
	case when TotalSales - avg(TotalSales) over (partition by ProductKey) > 0 then N'Cao hơn trung bình'
		 when TotalSales - avg(TotalSales) over (partition by ProductKey) < 0 then N'Thấp hơn trung bình'
		 else N'Bằng trung bình'
	end Status_Avg_Sales
from table1
order by ProductKey, MonthOrder


-- Phân loại khách hàng dựa vào lịch sử mua sắm.
with table1 as (
select CustomerKey, 
	sum(Sales) TotalSales, 
	datediff(day, min(OrderDate), max(OrderDate)) Lifespan,
	case when datediff(day, min(OrderDate), max(OrderDate)) >= 30 and sum(Sales) > 100 then 'VIP'
		 when datediff(day, min(OrderDate), max(OrderDate)) >= 30 and sum(Sales) <= 100 then 'Regular'
		 else 'New'
	end CustomerSegment
from Sales_2016
group by CustomerKey )
select CustomerSegment, 
	count(CustomerKey) NumberofCustomer
from table1
group by CustomerSegment
order by count(CustomerKey) desc


--Top 3 nhóm sản phẩm đóng góp lớn nhất cho tổng doanh thu năm 2016
with table1 as (
	select p.ProductSubcategoryKey, 
		SubcategoryName, 
		sum(Sales) TotalSales
	from AdventureWorks_Products$ p 
		inner join Sales_2016 
			on p.ProductKey=Sales_2016.ProductKey
		inner join AdventureWorks_Product_Subcateg$ s 
			on p.ProductSubcategoryKey=s.ProductSubcategoryKey
	group by p.ProductSubcategoryKey, SubcategoryName
), table2 as (
	select ProductSubcategoryKey, 
		sum(TotalSales) over () OverallSales, 
		round((cast(TotalSales as float) / sum(TotalSales) over ()) * 100, 2) Percentage_of_total_sales
	from table1 ) 
select * from (
	select table1.ProductSubcategoryKey, 
		table1.SubcategoryName, 
		table1.TotalSales, 
		table2.OverallSales, 
		concat(table2.Percentage_of_total_sales, '%') Percentage_of_total_sales , 
		row_number() over (order by Percentage_of_total_sales desc) Ranking
	from table1 inner join table2 on table1.ProductSubcategoryKey=table2.ProductSubcategoryKey ) t
where Ranking between 1 and 3


--Tính tỉ lệ Return (Return Rate) của từng sản phẩm trong năm 2016 và 2017 (sắp xếp theo thứ tự tỉ lệ giảm dần)

--Đếm số lượng sản phẩm return trong cả 2 năm 2016 và 2017
with
	table1
	as
	(
		select ProductKey, sum(ReturnQuantity) Quantity
		from AdventureWorks_Returns$
		where year(ReturnDate) = 2016
		group by ProductKey
	Union
		select ProductKey, sum(ReturnQuantity) Quantity
		from AdventureWorks_Returns$
		where year(ReturnDate) = 2017
		group by ProductKey
	),

	table2
	as
	(
		select ProductKey, sum(Quantity) TotalReturnQuantity
		from table1
		group by ProductKey
	),

--Đếm số lượng sản phẩm bán được trong cả 2 năm 2016 và 2017
	table3
	as
	(
		select ProductKey, sum(OrderQuantity) SaleQuantity
		from AdventureWorks_Sales_2016$
		group by ProductKey
	Union
		select ProductKey, sum(OrderQuantity) SaleQuantity
		from AdventureWorks_Sales_2017$
		group by ProductKey
	),

	table4
	as
	(
		select ProductKey, sum(SaleQuantity) TotalSaleQuantity
		from table3
		group by ProductKey
	)

--Tính return rate (%) của từng sản phẩm
select P.ProductKey,
	ProductSKU,
	ProductName,
	case when TotalSaleQuantity = 0 then '0%'
		else concat(round((TotalReturnQuantity / TotalSaleQuantity) * 100, 2), '%')  
	end ReturnRate
from table4 inner join table2
				on table4.ProductKey = table2.ProductKey
			inner join AdventureWorks_Products$ P
				on table4.ProductKey = P.ProductKey
order by concat(round((TotalReturnQuantity / TotalSaleQuantity) * 100, 2), '%') desc






