DROP TABLE IF EXISTS #Agg_Forecast;
SELECT
MAX(S.FileDate) AS VanguardDate
, S.Module 
, DATEADD(MONTH, DATEDIFF(MONTH, 0, S.FileDate), 0) AS SubmitMonthYear 
, DATEADD(MONTH, DATEDIFF(MONTH, 0, DemandDate), 0) AS ForecastMonthYear 
, H.CalendarSeason 
, H.Material 
, K.MaterialDescription 
, SUM(Quantity) AS Forecast  
INTO #Agg_Forecast FROM KEEN_Analytics.dbo.vwVanguardForecast_History H  
INNER JOIN KEEN_Analytics.dbo.vwVanguardForecast_SelectedSnapshots S 
ON H.FileDate = S.FileDate AND H.Module = S.Module AND H.SalesGroup = S.SalesGroup  
INNER JOIN (SELECT DISTINCT Material, MaterialDescription FROM vwKA_Material) K 
ON K.Material = H.Material  
where CAST(S.FileDate AS date) BETWEEN '20190601' 
AND GETDATE() 
AND S.SalesGroup = 'US KEEN ONLINE' 
AND SalesOrgName = 'US'
AND Category IN ('Boulevard', 'Trailhead', 'Uneek', 'Waterfront', 'Kids') 
AND S.Module = 'Demand'   
GROUP BY S.Module , H.DemandDate , H.CalendarSeason , H.Material , K.MaterialDescription , S.FileDate 
; 

DROP TABLE IF EXISTS #Forecast;  
SELECT  VanguardDate 
, Module 
, MONTH(ForecastMonthYear) AS ForecastMonth 
, YEAR(ForecastMonthYear) AS ForecastYear 
, CalendarSeason 
, Material 
, MaterialDescription 
, SUM(Forecast) AS Forecast  
INTO #Forecast FROM #Agg_forecast  
where ForecastMonthYear = DATEADD(MONTH, 6, SubmitMonthYear) 
GROUP BY VanguardDate, Module, ForecastMonthYear, ForecastMonthYear, CalendarSeason, Material, MaterialDescription 
;  

DROP TABLE IF EXISTS #Sales;
SELECT  
TransactionCalendarYear 
, TransactionCalendarMonthNumber 
, Material 
, MaterialDescription 
, SUM(ShipQty) AS Sales 
, SUM(ShipAmt) AS Revenue  
INTO #Sales 
FROM KEEN_Analytics.dbo.vwBetaMask 
WHERE OrderType NOT IN ('FREE OF CHARGE', 'CONS. RETURN', 'ADJUST/RETURN', 'SAMPLES') 
AND SalesOrgName = ('US') 
AND ForecastGroup = 'US KEEN ONLINE' 
AND CAST(TransactionDt AS date) BETWEEN '20200101' AND GETDATE()
AND Category IN ('Boulevard', 'Trailhead', 'Uneek', 'Waterfront', 'Kids') 
AND ShipQty > 0  
GROUP BY TransactionCalendarYear , TransactionCalendarMonthNumber , Material , MaterialDescription 
;  

DROP TABLE IF EXISTS #MaterialLevel;
SELECT  
COALESCE(F.Material, S.Material) AS Material 
, COALESCE(F.MaterialDescription, S.MaterialDescription) AS MaterialDescription 
, COALESCE(ForecastMonth, TransactionCalendarMonthNumber) AS [Month] 
, COALESCE(ForecastYear, TransactionCalendarYear) AS [Year] 
, Forecast 
, ISNULL(Sales,0) AS Actual_Sales  
INTO #MaterialLevel
FROM #Forecast F 
FULL OUTER JOIN #Sales S 
ON S.Material = F.Material 
AND S.TransactionCalendarMonthNumber = F.ForecastMonth 
AND S.TransactionCalendarYear = F.ForecastYear  
WHERE (ForecastYear >= 2020 OR TransactionCalendarYear >= 2020)  
AND Forecast IS NOT NULL 
;

SELECT  
[Model]
, Gender
, [Month] 
, [Year] 
, SUM(Forecast) AS Forecast
, SUM(Actual_Sales) AS Actual_Sales  

FROM #MaterialLevel M
JOIN vwStyleMaster S
ON M.Material = S.Material

GROUP BY 
[Model]
, Gender
, [Month] 
, [Year]