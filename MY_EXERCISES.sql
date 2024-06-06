/* First, query an alphabetical ordered list of all first names in sales.staffs table, immediately followed by first letter each last names and the manager id as a parenthetical (i.e.: enclosed in parentheses).
Next, query the number of ocurrences of each manager id in sales.staffs. Sort the occurrences in ascending order, and output them in the following format:
[Manager name] has total of [subordinate_count] subordinates.*/
SELECT first_name +  ' ' + SUBSTRING(last_name, 1, 1) + '. ' + ISNULL(QUOTENAME(manager_id, '()'), '(None)')
FROM sales.staffs;

SELECT name + 'has total of ' + CONVERT(VARCHAR(2), subordinate_count) + ' subordinates.'
FROM(
	SELECT s.first_name +  ' ' + SUBSTRING(s.last_name, 1, 1) + '. ' name, COUNT(*) subordinate_count
	FROM sales.staffs s
	JOIN sales.staffs s2
		ON s.staff_id = s2.manager_id AND s.staff_id != s2.staff_id
	GROUP BY s.first_name +  ' ' + SUBSTRING(s.last_name, 1, 1) + '. '
)t
ORDER BY subordinate_count;

SELECT *
FROM sales.staffs;

/* Pivot the manager name column in OCCUPATIONS so that each name of the subordinate is sorted alphabetically and displayed underneath its manager name. 
The output column headers should be Fabiola, Jannette, Venita, and Mireya, respectively.

Note: Print NULL when there are no more names corresponding to a subordinate name.*/
SELECT [Fabiola], [Jannette], [Venita], [Mireya]
FROM(
	SELECT 
		s.first_name manager,
		s1.first_name subordinate,  
		ROW_NUMBER() OVER(PARTITION BY s1.manager_id ORDER BY s.first_name) rownum
	FROM sales.staffs s
	JOIN sales.staffs s1
		ON s.staff_id = s1.manager_id AND s.staff_id != s1.staff_id
)t
PIVOT(
	MAX(subordinate)
	FOR manager IN([Fabiola], [Jannette], [Venita], [Mireya])
)pivot_table;

/*You are given a table, BST, containing two columns: N and P, where N represents the value of a node in Binary Tree, and P is the parent of N.

Write a query to find the node type of Binary Tree ordered by the value of the node. Output one of the following for each node:

Root: If node is root node.
Leaf: If node is leaf node.
Inner: If node is neither root nor leaf node.*/
CREATE TABLE BST(
	N INT,
	P INT
);
INSERT INTO BST
VALUES
	(1, 2),
	(3, 2),
	(5, 6),
	(7, 6),
	(2, 4),
	(6, 4),
	(4, 15),
	(8, 9),
	(10, 9),
	(12, 13),
	(14, 13),
	(9, 11),
	(13, 11),
	(11, 15),
	(15, NULL);

-- FIRST SOLUTION:
WITH cte AS(
    SELECT N, 1 level
    FROM BST
    WHERE P IS NULL 
UNION ALL
    SELECT BST.N, level + 1
    FROM BST
    JOIN cte
        ON BST.P = cte.N
)
SELECT
	N,
	CASE 
		WHEN level = 1 THEN 'Root'
		WHEN level = t.max_level THEN 'Leaf'
		ELSE 'Inner'
	END node_type
FROM cte
LEFT JOIN(
	SELECT MAX(level) max_level
	FROM cte
)t ON cte.level = t.max_level;

-- SECOND SIMPLIER SOLUTION:
SELECT 
    N,
    CASE 
        WHEN P IS NULL THEN 'Root'
        WHEN N NOT IN (SELECT DISTINCT P FROM BST WHERE P IS NOT NULL) THEN 'Leaf'
        ELSE 'Inner'
    END node_type
FROM 
    BST
ORDER BY 
    N;

/* Write a query to print the store_id, store_name, total number of managers and total number of employees.
Order your output by ascending stored_id.*/
SELECT s.store_id, store_name, COALESCE(managers, 0) managers, employees
FROM sales.stores s
LEFT JOIN(
	SELECT store_id, COUNT(*) managers
	FROM sales.staffs
	WHERE staff_id IN(
		SELECT manager_id
		FROM sales.staffs
	)
	GROUP BY store_id
)m ON s.store_id = m.store_id
LEFT JOIN(
	SELECT store_id, COUNT(*) employees
	FROM sales.staffs
	WHERE staff_id NOT IN(
		SELECT manager_id
		FROM sales.staffs
		WHERE manager_id IS NOT NULL
	)
	GROUP BY store_id
)e ON s.store_id = e.store_id;

-- Query the median of all list_prices in sales.order_items table.
BEGIN;
	DECLARE @m DEC(10,2);
	SELECT @m = CONVERT(DEC(10,2), COUNT(list_price)) /2.00
		FROM sales.order_items;

	DECLARE @varch VARCHAR(128) = CONVERT(VARCHAR(128), @m);

	IF SUBSTRING(@varch, CHARINDEX('.', @varch) - 1, LEN(@varch)) LIKE '%.0%'
	BEGIN
		DECLARE @n INT = @m + 1;
		DECLARE @median DECIMAL(10,2);
		SELECT @median = SUM(list_price) / 2.00
		FROM(
			SELECT rownum, list_price
			FROM(
				SELECT 
				list_price,
				ROW_NUMBER() OVER(
				ORDER BY list_price
				) rownum
				FROM sales.order_items
			) t
			WHERE rownum IN(@m, @n)
		) t;
		SELECT @median;
	END

	ELSE
	BEGIN
		DECLARE @median2 DEC(10,2);
		SELECT @median2 = list_price
		FROM(
			SELECT 
				list_price,
				ROW_NUMBER() OVER(
				ORDER BY list_price
			) rownum
			FROM sales.order_items
		) t
		WHERE rownum = CEILING(@m);
		SELECT @median2;
	END	
END;

-- Query the smallest list_price from sales.order_items that is greater than 449. Round your answer to 1 decimal place.
SELECT CONVERT(DEC(10,1), MIN(list_price)) 
FROM(
	SELECT list_price
	FROM sales.order_items
	WHERE list_price > 449
)t;

-- Find the customer whose order is the most expensive each day in 2016.
SELECT customer_id, customer, order_date, price
FROM(
	SELECT 
		c.customer_id,
		c.first_name + ' ' + c.last_name customer,
		o.order_date, 
		SUM(i.list_price * (i.quantity * (1 - i.discount))) price, 
		ROW_NUMBER() OVER(
			PARTITION BY o.order_date ORDER BY SUM(i.list_price * (i.quantity * (1 - i.discount))) DESC) rownum
	FROM sales.customers c
	JOIN sales.orders o
		ON o.customer_id = c.customer_id
	JOIN sales.order_items i
		ON i.order_id = o.order_id
	WHERE YEAR(o.order_date) = 2016
	GROUP BY c.customer_id, c.first_name + ' ' + c.last_name, o.order_date
)t
WHERE rownum = 1
ORDER BY order_date;

-- Find the days in 2016 in which no customers made an order.
DECLARE 
	@year INT = 2016,
	@month INT = 1;
DECLARE	@dates TABLE(day_of_year DATE);

WHILE @month <= 12
BEGIN
	WITH numbers AS(
		SELECT 1 num
		UNION ALL
		SELECT num + 1
		FROM numbers
		WHERE num < DAY(EOMONTH(DATEFROMPARTS(@year, @month, 1)))
	)
	INSERT INTO @dates
	SELECT DATEFROMPARTS(@year, @month, num)
	FROM numbers;

	SET @month += 1;
END;

SELECT day_of_year
FROM @dates
LEFT JOIN(
	SELECT order_date, COUNT(order_id) order_count
	FROM sales.orders	
	WHERE YEAR(order_date) = 2016
	GROUP BY order_date
) t ON t.order_date = day_of_year
WHERE order_count IS NULL
ORDER BY day_of_year;

-- Find all prime numbers up to 1000.
WITH cte AS(
	SELECT ROW_NUMBER() OVER(ORDER BY object_id) num
	FROM sys.all_objects
),
cte2 AS(
	SELECT a.num a, b.num b, a.num % b.num modulo
	FROM cte a
	CROSS JOIN cte b
	WHERE b.num != 1 AND a.num <= 1000 AND b.num <= 1000
),
cte3 AS(
	SELECT a, COUNT(modulo) m_count
	FROM cte2
	WHERE modulo = 0
	GROUP BY a
)
SELECT STRING_AGG(a, '&')
FROM cte3
WHERE m_count = 1;

