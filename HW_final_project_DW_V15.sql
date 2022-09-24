CREATE OR REPLACE VIEW dw_v4 AS
SELECT Orders.OrderID, STR_TO_DATE(Orders.OrderDate,"%m/%d/%Y") AS OrderDate, Orders.EmployeeID, 
	STR_TO_DATE(Orders.RequiredDate,"%m/%d/%Y") AS RequiredDate, 
	STR_TO_DATE(Orders.ShippedDate,"%m/%d/%Y") AS ShippedDate, 
	IF(STR_TO_DATE(Orders.ShippedDate,"%m/%d/%Y") IS NULL, NULL,
	IF (STR_TO_DATE(Orders.RequiredDate,"%m/%d/%Y")-STR_TO_DATE(Orders.ShippedDate,"%m/%d/%Y")<0,'delayed','on_time')) as 'delayed_order',
	Shippers.CompanyName AS ShipperName, Orders.ShipCountry, Orders.CustomerID, Customers.CompanyName AS CustomerName, Customers.Country AS CustomerCountry, 
    Suppliers.SupplierID,
    COUNT(DISTINCT Suppliers.SupplierID) AS "#Number_Supplier",
	IFNULL(SUM(CASE WHEN Categories.CategoryID = 1 THEN Order_Details.Quantity END),0) AS "Quantity_Beverage",
    IFNULL(SUM(CASE WHEN Categories.CategoryID = 2 THEN Order_Details.Quantity END),0) AS "Quantity_Condiments",
	IFNULL(SUM(CASE WHEN Categories.CategoryID = 3 THEN Order_Details.Quantity END),0) AS "Quantity_Confections",
    IFNULL(SUM(CASE WHEN Categories.CategoryID = 4 THEN Order_Details.Quantity END),0) AS "Quantity_Dairy_Products",
    IFNULL(SUM(CASE WHEN Categories.CategoryID = 5 THEN Order_Details.Quantity END),0) AS "Quantity_Grains/Cereals",
    IFNULL(SUM(CASE WHEN Categories.CategoryID = 6 THEN Order_Details.Quantity END),0) AS "Quantity_Meat/Poultry",
    IFNULL(SUM(CASE WHEN Categories.CategoryID = 7 THEN Order_Details.Quantity END),0) AS "Quantity_Produce",
    IFNULL(SUM(CASE WHEN Categories.CategoryID = 8 THEN Order_Details.Quantity END),0) AS "Quantity_Seafood",
    IFNULL(ROUND(SUM(CASE WHEN Categories.CategoryID = 1 THEN ROUND((Order_Details.UnitPrice* Order_Details.Quantity*(1-Order_Details.Discount)/100)*100,2) END),2),0) AS "SubtotalBeverages",
	IFNULL(ROUND(SUM(CASE WHEN Categories.CategoryID = 2 THEN ROUND((Order_Details.UnitPrice* Order_Details.Quantity*(1-Order_Details.Discount)/100)*100,2) END),2),0) AS "SubtotalCondiments",
    IFNULL(ROUND(SUM(CASE WHEN Categories.CategoryID = 3 THEN ROUND((Order_Details.UnitPrice* Order_Details.Quantity*(1-Order_Details.Discount)/100)*100,2) END),2),0) AS "SubtotalConfections",
    IFNULL(ROUND(SUM(CASE WHEN Categories.CategoryID = 4 THEN ROUND((Order_Details.UnitPrice* Order_Details.Quantity*(1-Order_Details.Discount)/100)*100,2) END),2),0) AS "SubtotalDairy_Products",
    IFNULL(ROUND(SUM(CASE WHEN Categories.CategoryID = 5 THEN ROUND((Order_Details.UnitPrice* Order_Details.Quantity*(1-Order_Details.Discount)/100)*100,2) END),2),0) AS "SubtotalGrains/Cereals",
    IFNULL(ROUND(SUM(CASE WHEN Categories.CategoryID = 6 THEN ROUND((Order_Details.UnitPrice* Order_Details.Quantity*(1-Order_Details.Discount)/100)*100,2) END),2),0) AS "SubtotalMeat/Poultry",
    IFNULL(ROUND(SUM(CASE WHEN Categories.CategoryID = 7 THEN ROUND((Order_Details.UnitPrice* Order_Details.Quantity*(1-Order_Details.Discount)/100)*100,2) END),2),0) AS "SubtotalProduce",
    IFNULL(ROUND(SUM(CASE WHEN Categories.CategoryID = 8 THEN ROUND((Order_Details.UnitPrice* Order_Details.Quantity*(1-Order_Details.Discount)/100)*100,2) END),2),0) AS "SubtotalSeafood",
    ROUND(SUM(ROUND((Order_Details.UnitPrice* Order_Details.Quantity*(1-Order_Details.Discount)/100)*100,2)),2) AS OrderAmount,
    ROUND(SUM(Order_Details.UnitPrice* Order_Details.Quantity),2) AS BookAmount,
    ROUND(1 - ROUND(SUM(ROUND((Order_Details.UnitPrice* Order_Details.Quantity*(1-Order_Details.Discount)/100)*100,2)),2)/ROUND(SUM(Order_Details.UnitPrice* Order_Details.Quantity),2),2) AS OrderDiscount, 
    Orders.Freight

FROM  Categories JOIN
   (Suppliers JOIN
    (Shippers JOIN 
      (Products  JOIN 
       ((Employees  JOIN 
         (Customers  JOIN Orders 
			ON Customers.CustomerID = Orders.CustomerID) 
          ON Employees.EmployeeID = Orders.EmployeeID) 
        JOIN Order_Details ON Orders.OrderID = Order_Details.OrderID) 
      ON Products.ProductID = Order_Details.ProductID) 
     ON Shippers.ShipperID = Orders.ShipVia)
    ON Suppliers.SupplierID = Products.SupplierID)
   ON Categories.CategoryID = Products.CategoryID
GROUP BY OrderID
ORDER BY OrderID;

SELECT * FROM dw_v4;


-- Query 1:checked
-- From order value, which salesman should we give higher compensation?
SELECT  YEAR(OrderDate),CONCAT(FirstName, ' ', LastName) AS Salesperson, ROUND(SUM(OrderAmount),2) AS orderValuebySalesperson
FROM dw_v4 d
JOIN Employees e
ON d.EmployeeID = e.EmployeeID
GROUP BY YEAR(OrderDate),Salesperson
ORDER BY YEAR(OrderDate),orderValuebySalesperson DESC;
-- finding: Margaret Peacock is best salesman for year 1996 and 1997 but she was a little bit left behind for year 1998.
-- The management team could probably communicate with her to ask why.

-- Query 2: checked
-- Which country has order numbers over average?
SELECT ShipCountry, COUNT(OrderID) AS numberOforders
FROM dw_v4
GROUP BY ShipCountry
HAVING COUNT(OrderID) > (SELECT COUNT(*)/COUNT(DISTINCT ShipCountry) FROM dw_v4)
ORDER BY numberOforders DESC;
-- finding:  seven countries have order numbers over average


-- Query 3:checked
-- order delay rates by country 
SELECT  ShipCountry,
	COUNT(IF (delayed_order = "delayed",1,null))/COUNT(ShippedDate) AS delayRates
FROM dw_v4 
GROUP BY ShipCountry
ORDER BY  delayRates DESC;
-- finding: orders shipped to Ireland has the highest delay rates; orders shipped to switzerland, mexico, canada,denmark, poland and norway
-- never delay.


-- Query 4:checked
-- one dollar cost in freight will generate how much revenue? used to judge which shipper is more valuable to us
SELECT ShipCountry, ShipperName, Round(SUM(OrderAmount)/SUM(Freight),3) AS RevenueGeneratedPerDollarFreightCost, Round(SUM(OrderAmount),2) AS total_revenue_by_shipper
FROM dw_v4
GROUP BY ShipCountry,ShipperName
ORDER BY ShipCountry DESC, RevenueGeneratedPerDollarFreightCost DESC;
-- finding: The value of the shipper varies in different destination country, 
-- for example, for destination to USA we probably could use more Speedy Express since for every dollar freight, it could generate more revenue for us.
-- But at the same time, we should investigate more since we are not sure whether the company tend to give smaller weight but higher value order to Speedy Express or not, this might introduce some bias.


-- Query 5:
-- Find customers with higher spending per order than average, their total_spending in our company and divide them into 5 groups with rank
SELECT CustomerName, CustomerCountry, ROUND(SUM(OrderAmount)/COUNT(DISTINCT(OrderID)),2) AS amount_per_order, 
		ROUND(SUM(OrderAmount),2) AS total_spending,
        NTILE(5) OVER(ORDER BY ROUND(SUM(OrderAmount),2)DESC) AS customerRanking
FROM dw_v4
GROUP BY CustomerName, CustomerCountry
HAVING amount_per_order > (SELECT SUM(OrderAmount)/COUNT(DISTINCT(OrderID)) FROM dw_v4)
ORDER BY customerRanking;
-- Finding: maintain the relationship with those top-quality buyers, such as in rank 1 and rank 2

-- Query 6:
-- Analyse year-month level revenue in our company to observe the seasonality and the top 3 sales countries in this month
WITH monthly_revenue AS(
    SELECT 
        OrderDate,YEAR(OrderDate) AS orderYear, MONTH(OrderDate)AS orderMonth,ShipCountry,
        ROUND(SUM(OrderAmount),2) AS monthly_revenue,
        RANK() OVER (
            PARTITION BY YEAR(OrderDate), MONTH(OrderDate)
            ORDER BY ROUND(SUM(OrderAmount),2) DESC
        ) revenueRank
    FROM dw_v4  
	GROUP BY YEAR(OrderDate), MONTH(OrderDate),ShipCountry
)
SELECT  orderYear,orderMonth,ShipCountry,monthly_revenue,revenueRank
FROM monthly_revenue
WHERE revenueRank <=3
ORDER BY YEAR(OrderDate),MONTH(OrderDate) ASC; 
-- findings: year-month revenue rank by country(top3 reveneue countries,used for visualization)
-- Germany and USA have most times on the top3, so they are very big market

-- Query 7:
-- Analyse clients spending style in each country, whether there are potential market in some country, 
-- could also analyse the average_order_spending_style
SELECT CustomerCountry, ROUND(sum(OrderAmount),2) AS total_spending_by_country, 
		ROUND(SUM(OrderAmount)/COUNT(DISTINCT(OrderID)),2) AS amount_per_order 
FROM dw_v4
GROUP BY CustomerCountry
ORDER BY total_spending_by_country DESC;
-- Finding: USA and Germany are the greatest main market, while Austria has the highest amount_per_order. Austria might be a great potential market.

-- Query 8:
-- Analyse the delay of the shippment after the order date by month to observe the seasonal impact
SELECT DATE_FORMAT(OrderDate,"%b") AS Order_month, 
		ROUND(AVG(DATEDIFF(ShippedDate,OrderDate)),2) AS shipment_delay
FROM dw_v4
GROUP BY Order_month
ORDER BY shipment_delay DESC;
-- Findings: shipment in Sep and Jan are most delayed, probably because people are on vacation during these months
