USE mavenfuzzyfactory;
-- tables
select * from website_sessions;
select * from website_pageviews;
select * from products;
select * from orders;
select * from order_items;
select * from order_item_refunds;

-- grouping session and orders by utm source
SELECT 
	website_sessions.utm_content, 
	COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.order_id) AS orders,
    COUNT(DISTINCT orders.order_id) / COUNT(DISTINCT website_sessions.website_session_id) * 100 AS session_to_order_convrt_rate -- convertion rate (% of orders from sessions)
FROM website_sessions
	LEFT JOIN orders
		ON orders.website_session_id = website_sessions.website_session_id
WHERE website_sessions.website_session_id BETWEEN 1000 AND 2000 -- selecting id between 1000 to 2000
GROUP BY utm_content
ORDER BY sessions DESC;

-- NOTES
-- database starts from March (product lauch date)
-- utm NULL suggests utm source tracker not put in place or not from utm source
-- I use created_at to simulate a timeline for a hypothetical company I am working at 



-- 2012 APR 12 SCENARIO: CEO wants to know where most of sessions are coming from
-- show breakdown of UTM source, campaign and referring domain. 
SELECT 
	COUNT(DISTINCT website_session_id) AS sessions,
	utm_source AS 'Session Source', 
	utm_campaign,
    http_referer AS 'Referring Domain'
FROM website_sessions
WHERE created_at < '2012-04-12' 
GROUP BY 
	utm_campaign,
    utm_source,
    http_referer
ORDER BY sessions DESC;


-- APR 14 SCENARIO: MK (Marketing Director) wants to know the conversion rate from sessions to order. 
SELECT 
	utm_source AS 'Session Source', 
    utm_campaign,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.order_id) AS orders,
    COUNT(DISTINCT orders.order_id) / COUNT(DISTINCT website_sessions.website_session_id) * 100 AS CVR
FROM website_sessions
	LEFT JOIN orders
		ON orders.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at < '2012-04-14' 
	AND utm_source = 'gsearch'
    AND utm_campaign = 'nonbrand'; 

-- May 10 SCENARIO: MK 'based on conversion rate, company decided to bid down gsearch nonbrand on APR 15th
-- show gsearch nonbrand trended session volume by week
SELECT 
	MIN(DATE(created_at)) AS week_start_date,
    COUNT(DISTINCT website_session_id) AS sessions
FROM website_sessions
WHERE created_at < '2012-05-10' 
AND utm_source = 'gsearch'
AND utm_campaign = 'nonbrand'
GROUP BY WEEK(created_at);

-- May 11 SCENARIO: MK wants to know convertion rates for the gsearch nonbrand results filtered by device type 
SELECT 
	device_type,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.order_id) AS orders,
    COUNT(DISTINCT orders.order_id) / COUNT(DISTINCT website_sessions.website_session_id) * 100 AS CVR
FROM website_sessions
	LEFT JOIN orders
		ON orders.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at < '2012-05-11' 
	AND utm_source = 'gsearch'
    AND utm_campaign = 'nonbrand'
GROUP BY device_type;

-- Jun 9 SCENARIO: desktop went up so MK bid higher on gsearch nonbrand desktop campaigns on May 19
-- MK wants to see weekly trends for both device type. Start date from Apri 15th till present
SELECT 
	MIN(DATE(created_at)) AS week_start_date,
	COUNT(DISTINCT CASE WHEN device_type =  'desktop' THEN website_session_id ELSE NULL END) AS dtop_sessions,
	COUNT(DISTINCT CASE WHEN device_type =  'mobile' THEN website_session_id ELSE NULL END) AS mob_sessions
FROM website_sessions
WHERE website_sessions.created_at > '2012-04-15' 
	AND website_sessions.created_at < '2012-06-09'
	AND utm_source = 'gsearch'
    AND utm_campaign = 'nonbrand'
GROUP BY WEEK(created_at)
;

-- Jun 09 SCENARIO: Website Manager wants to know which page urls are landing the most views
SELECT 
	pageview_url,
	COUNT(DISTINCT website_pageview_id) AS pageviews
FROM website_pageviews
WHERE created_at < '2012-06-09'
GROUP BY pageview_url
ORDER BY pageviews DESC
;

-- Jun 12 SCENARIO: WM wants to know top entry pages (customer lands on page for first time)
-- create temp table to filter by first entry pages
CREATE TEMPORARY TABLE first_pv_per_session
SELECT 
	website_session_id,
	MIN(website_pageview_id) AS first_pv
FROM website_pageviews
WHERE created_at < '2012-06-12'
GROUP BY website_session_id
;

-- count first entries by page
SELECT 
	pageview_url AS landing_page_url,
    COUNT(DISTINCT first_pv) AS sessions_hitting_page
FROM website_pageviews
	LEFT JOIN first_pv_per_session
		ON website_pageviews.website_session_id = first_pv_per_session.website_session_id
GROUP BY landing_page_url
ORDER BY 2 DESC
;

-- Jun 14 SCENARIO: WM wants to know the bounce rates for the home page
-- 1. find first website_pageviews_id for relevant sessions

CREATE TEMPORARY TABLE first_pageviews
SELECT 
	website_session_id,
	MIN(website_pageview_id) as min_pageview_id
FROM website_pageviews
WHERE created_at < '2012-06-14'
GROUP BY website_session_id 
;
SELECT * FROM first_pageviews;

-- 2. identify landing page of each session
CREATE TEMPORARY TABLE home_sessions
SELECT 
	first_pageviews.website_session_id,
    website_pageviews.pageview_url AS landing_page
FROM first_pageviews
	LEFT JOIN website_pageviews
		ON first_pageviews.min_pageview_id = website_pageviews.website_session_id
WHERE website_pageviews.pageview_url = '/home'
;
SELECT * FROM  home_sessions;

-- 3. count pageviews for each session (bounces)
CREATE TEMPORARY TABLE bounced_sessions
SELECT
	home_sessions.website_session_id,
    home_sessions.landing_page,
    COUNT(website_pageviews.website_pageview_id)
FROM home_sessions
	LEFT JOIN website_pageviews
		ON home_sessions.website_session_id = website_pageviews.website_session_id
GROUP BY 
	home_sessions.website_session_id,
    home_sessions.landing_page
HAVING 
	COUNT(website_pageviews.website_pageview_id) = 1
;
SELECT * FROM bounced_sessions;

-- 4. summarise by count total sessions and bounced sessions (cnvr)
SELECT 
	COUNT(DISTINCT home_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT bounced_sessions.website_session_id) AS bounced,
	COUNT(DISTINCT bounced_sessions.website_session_id) / COUNT(DISTINCT home_sessions.website_session_id) * 100 AS bounced_rate
FROM home_sessions
	LEFT JOIN bounced_sessions
		ON home_sessions.website_session_id = bounced_sessions.website_session_id
ORDER BY
	home_sessions.website_session_id
;

-- July 28 SCENARIO: Company launched a new landing page (/lander-1). 
-- MW wants to know the bounce rates comparisons between /lander-1 & home page
-- first search when /lander-1 launched to make fair comparison
SELECT 
	MIN(created_at) AS first_created_at,
	MIN(website_pageview_id) AS first_pageview_id
FROM website_pageviews
WHERE 
	pageview_url = '/lander-1' AND
    pageview_url IS NOT NULL
;
-- first_created_at = '2012-06-19 00:35:54' and first_pageview_id = '23504'

-- 1. find first website_pageviews_id for relevant sessions
CREATE TEMPORARY TABLE first_test_pageviews
SELECT 
	website_pageviews.website_session_id,
	MIN(website_pageviews.website_pageview_id) as min_pageview_id
FROM website_pageviews
	INNER JOIN website_sessions
		ON website_pageviews.website_session_id = website_sessions.website_session_id
		AND website_pageviews.created_at < '2012-07-28'
		AND website_pageviews.website_pageview_id > 23504
		AND website_sessions.utm_source = 'gsearch'
		AND website_sessions.utm_campaign = 'nonbrand'
GROUP BY website_pageviews.website_session_id 
;

-- 2. identify landing page of home and lander-1 sessions
CREATE TEMPORARY TABLE nonbrand_sessions
SELECT
	first_test_pageviews.website_session_id,
    website_pageviews.pageview_url AS landing_page
FROM first_test_pageviews
	LEFT JOIN website_pageviews
		ON first_test_pageviews.min_pageview_id = website_pageviews.website_pageview_id
WHERE website_pageviews.pageview_url IN ('/home','/lander-1')
;

-- 3. count pageviews for each session (bounces)
CREATE TEMPORARY TABLE nonbrand_bounce_sessions
SELECT 
	nonbrand_sessions.website_session_id,
    nonbrand_sessions.landing_page,
	COUNT(website_pageview_id) AS page_view_count
FROM nonbrand_sessions
	LEFT JOIN website_pageviews
		ON nonbrand_sessions.website_session_id = website_pageviews.website_session_id
GROUP BY 1,2
HAVING 
	COUNT(website_pageviews.website_pageview_id) = 1
;

-- 4. summarise by count of total sessions and bounced sessions (cnvr)
SELECT
    nonbrand_sessions.landing_page,
	COUNT(DISTINCT nonbrand_sessions.website_session_id) AS sessions_not_bounced,
	COUNT(DISTINCT nonbrand_bounce_sessions.website_session_id) AS sessions_bounced,
    COUNT(DISTINCT nonbrand_bounce_sessions.website_session_id)/ COUNT(DISTINCT nonbrand_sessions.website_session_id) * 100 AS bounce_rate
FROM nonbrand_sessions
	LEFT JOIN nonbrand_bounce_sessions
		ON  nonbrand_sessions.website_session_id = nonbrand_bounce_sessions.website_session_id
GROUP BY
	nonbrand_sessions.landing_page
;

-- AUG 31 SCENARIO: WM wants to see the volume of nonbrand gsearch traffic landing on /home and /lander-1 along with the boucne rate from Jun 1st by week 
-- 1. find first website_pageviews_id for relevant sessions & counting pageviews
CREATE TEMPORARY TABLE session_w_min_pv_and_view_count
SELECT
	website_sessions.website_session_id,
    MIN(website_pageviews.website_pageview_id) AS min_pageview_id,
    COUNT(website_pageviews.website_pageview_id) AS pageview_count
FROM website_sessions
	LEFT JOIN website_pageviews
		ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE
	website_pageviews.created_at > '2012-06-01'
		AND website_pageviews.created_at < '2012-08-31'
		AND website_sessions.utm_source = 'gsearch'
		AND website_sessions.utm_campaign = 'nonbrand'
GROUP BY 
	website_sessions.website_session_id
;
SELECT * FROM session_w_min_pv_and_view_count;

-- 2. indentifying landing page of each session
CREATE TEMPORARY TABLE sessions_w_landing_page_and_created_at
SELECT
	session_w_min_pv_and_view_count.website_session_id,
    session_w_min_pv_and_view_count.min_pageview_id,
    session_w_min_pv_and_view_count.pageview_count,
    website_pageviews.pageview_url AS landing_page,
    website_pageviews.created_at AS session_created_at
FROM session_w_min_pv_and_view_count
	LEFT JOIN website_pageviews
		ON session_w_min_pv_and_view_count.min_pageview_id = website_pageviews.website_pageview_id
;
SELECT * FROM sessions_w_landing_page_and_created_at;

-- 3. Counting bounces and non-boucnes, can work out bounce rate and volume of session going to home and lander
SELECT
	YEARWEEK(session_created_at) AS year_week,
    MIN(DATE(session_created_at)) AS week_start_date,
    COUNT(DISTINCT CASE WHEN pageview_count=1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT website_session_id) * 100 AS bounce_rate,
    COUNT(DISTINCT CASE WHEN landing_page='/home' THEN website_session_id ELSE NULL END) AS home_sessions,
    COUNT(DISTINCT CASE WHEN landing_page='/lander-1' THEN website_session_id ELSE NULL END) AS lander_sessions
FROM sessions_w_landing_page_and_created_at
GROUP BY YEARWEEK(session_created_at) 
;

-- Sep 5th SCENARIO: WM wants a conversion funnel from /lander-1 page to thank you page using data from Aug 5th
-- 1. collecting data on users and how far they get from the lander page to the thank you page
CREATE TEMPORARY TABLE funnel_temp_table
SELECT 
	website_session_id,
    MAX(products_page) AS products_made_it,
    MAX(mrfuzzy_page) AS mrfuzzy_made_it,
    MAX(cart_page) AS cart_made_it,
    MAX(shipping_page) AS shipping_made_it,
    MAX(billing_page) AS billing_made_it,
    MAX(thankyou_page) AS thankyou_made_it
FROM(
	SELECT 
		website_sessions.website_session_id,
		website_pageviews.pageview_url,
		CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS products_page,
		CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page,
		CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
		CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
		CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_page,
		CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
	FROM website_sessions
		LEFT JOIN website_pageviews
			ON website_sessions.website_session_id = website_pageviews.website_session_id
	WHERE website_sessions.utm_source = 'gsearch'
		AND website_sessions.utm_campaign = 'nonbrand'
		AND website_pageviews.created_at > '2012-08-05'
		AND website_pageviews.created_at < '2012-09-05'
	ORDER BY 
		website_sessions.website_session_id,
		website_pageviews.created_at
	) AS pageview_level
GROUP BY
	website_session_id 
;
SELECT * FROM funnel_temp_table;

-- 2. Visualising clickthrough conversion rate 
SELECT 
    COUNT(DISTINCT CASE WHEN products_made_it = 1 THEN website_session_id ELSE NULL END)
		/ COUNT(DISTINCT website_session_id) AS lander_click_rate,
	COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END)
		/ COUNT(DISTINCT CASE WHEN products_made_it = 1 THEN website_session_id ELSE NULL END) AS products_click_rate,
	COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END)
		/ COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) AS mrfuzzy_click_rate,
	COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END)
		/ COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS cart_click_rate, 
	COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END)
		/ COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) AS shipping_click_rate,
	COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE NULL END)
		/ COUNT(DISTINCT website_session_id) AS billing_click_rate
FROM funnel_temp_table
;


-- Nov 10 SCENARIO: WM tested a new billing page (/billing-2). They want to see how it compares to the original billing page. 
-- What % of sessions end up placing an order
-- finding out when /billing-2 went up
SELECT 
	MIN(created_at) AS first_created_at,
	MIN(website_pageview_id) AS first_pageview_id
FROM website_pageviews
WHERE 
	pageview_url = '/billing-2'
;
-- 2012-09-10 00:13:05, 53550

-- show a funnel for the conversion rate from sessino to order for old and new billing sites
SELECT 
	billing_version_seen,
    COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT order_id) / COUNT(DISTINCT website_session_id) * 100 AS billing_to_order
FROM(
	SELECT 
	website_pageviews.website_session_id,
	website_pageviews.pageview_url AS billing_version_seen,
	orders.order_id
FROM website_pageviews
	LEFT JOIN orders
		ON website_pageviews.website_session_id = orders.website_session_id
WHERE 
	website_pageview_id >= 53550
    AND website_pageviews.created_at < '2012-11-10'
    AND website_pageviews.pageview_url IN ('/billing', '/billing-2')
) AS billing_sessions_w_orders
GROUP BY billing_version_seen
;
 










