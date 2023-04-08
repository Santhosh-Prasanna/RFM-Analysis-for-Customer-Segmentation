------------------------------Queries-------------------------------

------------------1.1---------------------

--grand total by year
SELECT extract(year from (to_date(invoicedate, 'MM/DD/YYYY HH24:MI'))) year,
                SUM(price*quantity) AS sales_total 
FROM tableRetail
GROUP BY ROLLUP(extract(year from (to_date(invoicedate, 'MM/DD/YYYY HH24:MI'))));

------------------1.2---------------------

--most selling product
--without analytical
SELECT stockcode, sum(quantity) frequent_buy
from tableRetail
group by stockcode
order by frequent_buy desc;
--with analytical
select stockcode, sum(quantity) over (partition by stockcode) as frequent_buy
from tableRetail
order by frequent_buy desc;

------------------1.3---------------------

--top 5 paying customers
--sql
select customer_id, SUM(quantity * price) as paid
from tableRetail
group by customer_id
order by paid desc;

--analytical
select customer_id, SUM(quantity * price) over (partition by customer_id) as paid
from tableRetail
order by paid desc;

--ranking
select *
from
(
SELECT customer_id, 
              SUM(quantity * price) as paid,
              row_number() OVER (ORDER BY (SUM(quantity * price)) DESC) AS rnk
              FROM tableRetail
             GROUP BY customer_id
) rnk_paid
WHERE rnk_paid.rnk <=5;

------------------1.4---------------------

--Group Data by Year and Quarter
SELECT EXTRACT(year FROM (to_date(invoicedate, 'MM/DD/YYYY HH24:MI'))) as year,
            TO_CHAR((TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI')), 'Q') as quarter,
            ROUND(SUM(price * quantity)) as sales,
            RANK() OVER(ORDER BY SUM(quantity * price)) as  rnk
FROM tableRetail
GROUP BY EXTRACT(year FROM (to_date(invoicedate, 'MM/DD/YYYY HH24:MI'))),
            TO_CHAR((TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI')), 'Q') 
ORDER BY rnk DESC;

------------------1.5---------------------

--rush hour
select  to_char(to_date(invoicedate, 'MM/DD/YYYY HH24:MI'), 'DAY HH24') rush_hr, 
           max(count(distinct(invoice))) over (partition by  to_char(to_date(invoicedate, 'MM/DD/YYYY HH24:MI'), 'DAY HH24')) as countt,
           rank() over(order by count(distinct invoice) desc) as rankk
from TableRetail
group by  to_char(to_date(invoicedate, 'MM/DD/YYYY HH24:MI'), 'DAY HH24');

------------------1.6---------------------

--running totals in 2010
SELECT  DISTINCT trunc(to_date(invoicedate, 'MM/DD/YYYY HH24:MI')) as dt,
             stockcode,
             SUM (price * quantity) OVER (PARTITION BY stockcode ORDER BY (to_date(invoicedate, 'MM/DD/YYYY HH24:MI')) ASC) AS running_tot
FROM tableRetail
WHERE extract(year from (to_date(invoicedate, 'MM/DD/YYYY HH24:MI')))  = '2010'
ORDER BY stockcode;

--checking
select * from tableretail
where stockcode ='10002' and extract(year from (to_date(invoicedate, 'MM/DD/YYYY HH24:MI')))  = '2010';

------------------1.7---------------------

--Time series Analysis

ALTER SESSION SET NLS_DATE_fORMAT = 'MM-DD-YYYY';

SELECT trunc(to_date(invoicedate, 'MM/DD/YYYY HH24:MI')) dt,
        SUM(price*quantity) AS daily_sum,
        (SUM(price*quantity)-LAG(SUM(price*quantity)) OVER (ORDER BY trunc(to_date(invoicedate, 'MM/DD/YYYY HH24:MI')) ASC)) AS daily_diff
FROM tableRetail
WHERE  trunc(to_date(invoicedate, 'MM/DD/YYYY HH24:MI')) > '09/30/2011' AND  trunc(to_date(invoicedate, 'MM/DD/YYYY HH24:MI')) <= '10/31/2011'
GROUP BY trunc(to_date(invoicedate, 'MM/DD/YYYY HH24:MI'));

------------------2.1---------------------

WITH rfm AS (SELECT customer_id,  
                            (SELECT MAX(TO_DATE(invoicedate, 'MM/DD/YYYY hh24:mi')) from tableRetail) - (MAX(TO_DATE(invoicedate, 'MM/DD/YYYY hh24:mi'))) as recency, 
                            COUNT(DISTINCT(invoice)) as frequency, 
                            SUM((price * quantity)) as monetary
                            FROM tableRetail
                            GROUP BY customer_id),
        rfm_calc AS(SELECT rfm.*,
                            NTILE(5) OVER (ORDER BY recency desc) as r_score,
                            ROUND(((NTILE(5) OVER (ORDER BY frequency)) + (NTILE(5) OVER(ORDER BY monetary)))/2) as fm_score
                            FROM rfm)
            
SELECT rfm.*,    
       (CASE WHEN (r_score = 5 AND fm_score = 5) OR (r_score = 5 AND fm_score = 4) OR (r_score = 4 AND fm_score = 5)
             THEN 'Champions'
             WHEN (r_score = 5 AND fm_score = 2) OR (r_score = 4 AND fm_score = 2) OR (r_score = 3 AND fm_score = 3) OR (r_score = 4 AND fm_score = 3)
             THEN 'Potential Loyalists'
             WHEN (r_score = 5 AND fm_score = 3) OR (r_score = 4 AND fm_score = 4) OR (r_score = 3 AND fm_score = 5) OR (r_score = 3 AND fm_score = 4)
             THEN 'Loyal Customers'
             WHEN (r_score = 5 AND fm_score = 1) 
             THEN 'Recent Customers'
             WHEN (r_score = 4 AND fm_score = 1) OR (r_score = 3 AND fm_score = 1)
             THEN 'Promising'
            WHEN (r_score = 3 AND fm_score = 2) OR (r_score = 2 AND fm_score = 3) OR (r_score = 2 AND fm_score = 2) 
             THEN 'Customers Needing Attention'
             WHEN (r_score = 2 AND fm_score = 5) OR (r_score = 2 AND fm_score = 4) OR (r_score = 1 AND fm_score = 3) OR (r_score = 2 AND fm_score = 1)
             THEN 'At Risk'
             WHEN (r_score = 1 AND fm_score = 5) OR (r_score = 1 AND fm_score = 4) 
             THEN 'Cant Lose them'
             WHEN (r_score = 1 AND fm_score = 2)
             THEN 'Hibernating' 
             WHEN (r_score = 1 AND fm_score = 1)
             THEN 'Lost' 
        END) as cust_segment
FROM rfm_calc rfm;


------------------2.2---------------------
WITH rfm AS (SELECT customer_id,  
                            (SELECT MAX(TO_DATE(invoicedate, 'MM/DD/YYYY hh24:mi')) from tableRetail) - (MAX(TO_DATE(invoicedate, 'MM/DD/YYYY hh24:mi'))) as recency, 
                            COUNT(DISTINCT(invoice)) as frequency, 
                            SUM((price * quantity)) as monetary
                            FROM tableRetail
                            GROUP BY customer_id),
        rfm_calc AS(SELECT rfm.*,
                            NTILE(5) OVER (ORDER BY recency desc) as r_score,
                            ROUND(((NTILE(5) OVER (ORDER BY frequency)) + (NTILE(5) OVER(ORDER BY monetary)))/2) as fm_score
                            FROM rfm)
            
SELECT rfm.*,
       (CASE WHEN r_score = 1 AND fm_score >= 4 
             THEN 'Cant Lose them'        
             WHEN r_score = 1 AND fm_score = 2
             THEN 'Hibernating' 
             WHEN r_score = 1 AND fm_score = 1
             THEN 'Lost' 
             WHEN r_score = 5 AND fm_score = 1 
             THEN 'Recent Customers'
             WHEN r_score = 5 AND fm_score = 3 
             THEN 'Loyal Customers'   
             WHEN r_score = 3 AND fm_score = 2
             THEN 'Customers Needing Attention'   
             WHEN r_score >= 4 AND fm_score >= 4 
             THEN 'Champions'           
             WHEN r_score >= 3 AND fm_score BETWEEN 2 AND 3
             THEN 'Potential Loyalists'    
             WHEN r_score >= 3 AND fm_score >= 3 
             THEN 'Loyal Customers'     
             WHEN r_score >= 3 AND fm_score = 1 
             THEN 'Promising'
             WHEN r_score >= 2 AND fm_score BETWEEN 2 AND 3 
             THEN 'Customers Needing Attention'        
             WHEN r_score >= 1 AND fm_score >=3
             THEN 'At Risk'
        END) as cust_segment
FROM rfm_calc rfm;
