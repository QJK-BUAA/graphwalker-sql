WITH artist_sales AS (
    SELECT 
        ar.ArtistId,
        ar.Name,
        SUM(ii.UnitPrice * ii.Quantity) AS total_sales
    FROM artists ar
    JOIN albums al ON ar.ArtistId = al.ArtistId
    JOIN tracks t ON al.AlbumId = t.AlbumId
    JOIN invoice_items ii ON t.TrackId = ii.TrackId
    GROUP BY ar.ArtistId, ar.Name
),
top_bottom_artists AS (
    SELECT 
        ArtistId,
        Name,
        total_sales,
        ROW_NUMBER() OVER (ORDER BY total_sales DESC, Name ASC) AS rn_desc,
        ROW_NUMBER() OVER (ORDER BY total_sales ASC, Name ASC) AS rn_asc
    FROM artist_sales
),
top_artist AS (
    SELECT ArtistId, Name FROM top_bottom_artists WHERE rn_desc = 1
),
bottom_artist AS (
    SELECT ArtistId, Name FROM top_bottom_artists WHERE rn_asc = 1
),
customer_spending AS (
    SELECT 
        c.CustomerId,
        c.FirstName || ' ' || c.LastName AS CustomerName,
        ta.Name AS artist_name,
        SUM(ii.UnitPrice * ii.Quantity) AS amount_spent
    FROM customers c
    JOIN invoices i ON c.CustomerId = i.CustomerId
    JOIN invoice_items ii ON i.InvoiceId = ii.InvoiceId
    JOIN tracks t ON ii.TrackId = t.TrackId
    JOIN albums al ON t.AlbumId = al.AlbumId
    JOIN artists a ON al.ArtistId = a.ArtistId
    CROSS JOIN top_artist ta
    CROSS JOIN bottom_artist ba
    WHERE a.ArtistId IN (ta.ArtistId, ba.ArtistId)
    GROUP BY c.CustomerId, c.FirstName, c.LastName, ta.Name, ba.Name
),
top_customer_spending AS (
    SELECT 
        CustomerId,
        CustomerName,
        amount_spent
    FROM customer_spending
    WHERE artist_name = (SELECT Name FROM top_artist)
),
bottom_customer_spending AS (
    SELECT 
        CustomerId,
        CustomerName,
        amount_spent
    FROM customer_spending
    WHERE artist_name = (SELECT Name FROM bottom_artist)
),
avg_spending AS (
    SELECT
        (SELECT AVG(amount_spent) FROM top_customer_spending) AS avg_top,
        (SELECT AVG(amount_spent) FROM bottom_customer_spending) AS avg_bottom
)
SELECT ROUND(ABS(avg_top - avg_bottom), 4) AS difference
FROM avg_spending