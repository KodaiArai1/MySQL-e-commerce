use mavenfuzzyfactory;
select * from website_sessions;

-- Nov 27
-- 1. 
-- Gsearch seems to be the biggest driver of our business. 
-- Could you pull monthly trends for gsearch sessions and orders so that we can showcase the growth there?
SELECT
	YEAR(website_sessions.created_at) AS yr,
    MONTH(website_sessions.created_at) AS mon,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.order_id) AS orders,
    COUNT(DISTINCT orders.order_id) / COUNT(DISTINCT website_sessions.website_session_id) AS orders_from_sessions
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id 
WHERE website_sessions.created_at < '2012-11-27'
	AND website_sessions.utm_source = 'gsearch'
GROUP BY 1,2
;

-- 2. 
-- Next, it would be great to see a similar monthly trend for gsearch, but this time splitting out nonbrand and brand campaings separately.alter
-- I am wondering if brand is picking up at all. 
SELECT
	YEAR(website_sessions.created_at) AS yr,
    MONTH(website_sessions.created_at) AS mon,
    COUNT(DISTINCT CASE WHEN utm_campaign = 'nonbrand' THEN website_sessions.website_session_id ELSE NULL END) AS nonbrand_sessions,
    COUNT(DISTINCT CASE WHEN utm_campaign = 'nonbrand' THEN orders.order_id ELSE NULL END) AS nonbrand_orders,
    COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN website_sessions.website_session_id ELSE NULL END) AS brand_sessions,
    COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN orders.order_id ELSE NULL END) AS brand_orders
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id 
WHERE website_sessions.created_at < '2012-11-27'
	AND website_sessions.utm_source = 'gsearch'
GROUP BY 1,2
;


-- 3. 
-- While we're on gsearch, could you dive into nonbrand and pull monthly sessions and orders split by device type? 
SELECT
	YEAR(website_sessions.created_at) AS yr,
    MONTH(website_sessions.created_at) AS mon,
    COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN website_sessions.website_session_id ELSE NULL END) AS mobile_sessions,
    COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN orders.order_id ELSE NULL END) AS mobile_orders,
    COUNT(DISTINCT CASE WHEN device_type = 'desktop' THEN website_sessions.website_session_id ELSE NULL END) AS desktop_sessions,
    COUNT(DISTINCT CASE WHEN device_type = 'desktop' THEN orders.order_id ELSE NULL END) AS desktop_orders
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id 
WHERE website_sessions.created_at < '2012-11-27'
	AND website_sessions.utm_source = 'gsearch'
    AND website_sessions.utm_campaign = 'nonbrand'
GROUP BY 1,2
;


-- 4. 
-- I'm worried one of our board members may be concerned about the large % of traffic from gsearch. 
-- Can you pull monthly trends for gsearch, alongside monthly trends for each of our other channels? 
SELECT DISTINCT
	utm_source,
    utm_campaign, 
    http_referer
FROM website_sessions
WHERE website_sessions.created_at < '2012-11-27'
;

SELECT 
	YEAR(created_at) AS yr,
    MONTH(created_at) AS mon,
    COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' THEN website_session_id ELSE NULL END) AS gsearch_paid_sesisons,
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' THEN website_session_id ELSE NULL END) AS bsearch_paid_sesisons,
    COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN website_session_id ELSE NULL END) AS organic_search_sessions, -- no paid tracking parameter
	COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN website_session_id ELSE NULL END) AS direct_type_in_sessions
FROM website_sessions
WHERE website_sessions.created_at < '2012-11-27'
GROUP BY 1,2
;


-- 5. 
-- Like to tell the story of the website performance improvements during first 8 months
-- Please pull sussion to order converstion rates by month
SELECT 
	YEAR(website_sessions.created_at) AS yr,
    MONTH(website_sessions.created_at) AS mon, 
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.order_id) AS orders,
    COUNT(DISTINCT orders.order_id) / COUNT(DISTINCT website_sessions.website_session_id) * 100 AS CVR
FROM website_sessions
	LEFT JOIN orders
		ON orders.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at < '2012-11-27'
GROUP BY 1,2
; 


-- 6. 
-- For the gsearch lander test, please estimate the revenue that test earned us.
SELECT 
MIN(website_pageview_id) AS first_test_pageview -- 23504
FROM website_pageviews
WHERE pageview_url = '/lander-1'
;

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

select * from first_test_pageviews;

CREATE TEMPORARY TABLE testsessions_w_landing_page
SELECT 
	first_test_pageviews.website_session_id,
    website_pageviews.pageview_url AS landing_page
FROM first_test_pageviews
	LEFT JOIN website_pageviews
		ON website_pageviews.website_pageview_id = first_test_pageviews.min_pageview_id
WHERE website_pageviews.pageview_url  IN ('/home','/lander-1')
;

CREATE TEMPORARY TABLE test_sessions_with_orders
SELECT 
	testsessions_w_landing_page.website_session_id,
    testsessions_w_landing_page.landing_page,
    orders.order_id
FROM testsessions_w_landing_page
	LEFT JOIN orders
		ON testsessions_w_landing_page.website_session_id = orders.website_session_id
;

SELECT 
	landing_page,
	COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT order_id) / COUNT(DISTINCT website_session_id) AS conv_rate
FROM test_sessions_with_orders
GROUP BY landing_page
;
-- /home 0.0318
-- /lander-1 0.0406
-- lander has 0.0088 higher conv rate than home

SELECT
	MAX(website_sessions.website_session_id)
FROM website_sessions
	LEFT JOIN website_pageviews
		ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE website_pageviews.created_at < '2012-11-27'
	AND pageview_url = '/home'
    AND website_sessions.utm_source = 'gsearch'
	AND website_sessions.utm_campaign = 'nonbrand'
;
-- last home page session id is 17145

SELECT 
	COUNT(website_session_id)
FROM website_sessions
WHERE created_at < '2012-11-27'
	AND website_session_id > 17145
    AND website_sessions.utm_source = 'gsearch'
	AND website_sessions.utm_campaign = 'nonbrand'
;
-- 22972 website sessions
-- 22972 x 0.0088 = 202 additional orders














