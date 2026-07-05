SELECT 
    vc.category_name,
    CAST(STRFTIME('%Y', vw.whsle_date) AS INTEGER) AS year,
    ROUND(AVG(vw.whsle_px_rmb_kg), 2) AS avg_wholesale_price,
    ROUND(MAX(vw.whsle_px_rmb_kg), 2) AS max_wholesale_price,
    ROUND(MIN(vw.whsle_px_rmb_kg), 2) AS min_wholesale_price,
    ROUND(MAX(vw.whsle_px_rmb_kg) - MIN(vw.whsle_px_rmb_kg), 2) AS wholesale_price_difference,
    ROUND(SUM(vw.whsle_px_rmb_kg), 2) AS total_wholesale_price,
    ROUND(SUM(vw.whsle_px_rmb_kg) * 1.2, 2) AS total_selling_price,
    ROUND(AVG((vw.whsle_px_rmb_kg * 0.05) / vw.whsle_px_rmb_kg) * 100, 2) AS avg_loss_rate,
    ROUND(SUM(vw.whsle_px_rmb_kg * 0.05), 2) AS total_loss,
    ROUND(SUM(vw.whsle_px_rmb_kg * 1.2) - SUM(vw.whsle_px_rmb_kg), 2) AS profit
FROM veg_whsle_df vw
JOIN veg_cat vc ON vw.item_code = vc.item_code
WHERE STRFTIME('%Y', vw.whsle_date) BETWEEN '2020' AND '2023'
GROUP BY vc.category_name, year
ORDER BY vc.category_name, year