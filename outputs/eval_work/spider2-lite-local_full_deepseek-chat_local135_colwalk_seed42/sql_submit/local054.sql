-- First, find the best-selling artist (artist with highest total sales)
-- Then find customers who spent less than $1 on albums by that artist
WITH best_selling_artist AS (
    SELECT artists.ArtistId
    FROM artists
    JOIN albums ON artists.ArtistId = albums.ArtistId
    JOIN tracks ON albums.AlbumId = tracks.AlbumId
    JOIN invoice_items ON tracks.TrackId = invoice_items.TrackId
    GROUP BY artists.ArtistId
    ORDER BY SUM(invoice_items.UnitPrice * invoice_items.Quantity) DESC
    LIMIT 1
),
customer_spending AS (
    SELECT customers.FirstName, 
           SUM(invoice_items.UnitPrice * invoice_items.Quantity) AS total_spent
    FROM customers
    JOIN invoices ON customers.CustomerId = invoices.CustomerId
    JOIN invoice_items ON invoices.InvoiceId = invoice_items.InvoiceId
    JOIN tracks ON invoice_items.TrackId = tracks.TrackId
    JOIN albums ON tracks.AlbumId = albums.AlbumId
    JOIN best_selling_artist ON albums.ArtistId = best_selling_artist.ArtistId
    GROUP BY customers.CustomerId, customers.FirstName
    HAVING total_spent < 1
)
SELECT FirstName, total_spent
FROM customer_spending