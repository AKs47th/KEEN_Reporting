DROP TABLE IF EXISTS #BULK0;
SELECT SAPOrderId INTO #BULK0
FROM KEEN_Analytics.dbo.vwBetaMask
where ForecastGroup LIKE '%AMAZON%'
AND SalesOrgName = 'US'
AND OrderType NOT IN ('FREE OF CHARGE', 'CONS. RETURN', 'ADJUST/RETURN', 'SAMPLES')
AND OrderType IN ('KEEN ONLINE BULK', 'PRE-SEASON BULK' )
;
DROP TABLE IF EXISTS #BULK1;
SELECT
Material
, CustPOId
, SchedLinReqDt AS Delivery_Date
, AFSOrdCancelDt AS BulkMonth
, CASE WHEN DATEDIFF(MONTH,(GETDATE()),(AFSOrdCancelDt)) < 1
  THEN
        CASE WHEN DATEDIFF(MONTH,CAST(AFSOrdCancelDt AS Date),(DATEADD(day, 7,SchedLinReqDt))) < 1
        THEN SUM(OpenQty)
        ELSE 0 END
  ELSE 0 END AS Current_Month_Bulk
, CASE WHEN DATEDIFF(MONTH,(GETDATE()),(AFSOrdCancelDt)) < 1
  THEN
        CASE WHEN DATEDIFF(MONTH,CAST(AFSOrdCancelDt AS Date),(DATEADD(day, 7,SchedLinReqDt))) = 1
        THEN SUM(OpenQty)
        ELSE 0 END
  ELSE 0 END AS Current_Month_Bulk_LandingNextMonth
, CASE WHEN DATEDIFF(MONTH,(GETDATE()),(AFSOrdCancelDt)) < 1
  THEN SUM(OpenQty)
  ELSE 0 END AS Current_Month_TotalBulk
, CASE WHEN DATEDIFF(MONTH,(GETDATE()),(AFSOrdCancelDt)) = 1
  THEN
        CASE WHEN DATEDIFF(MONTH,CAST(AFSOrdCancelDt AS Date),(DATEADD(day, 7,SchedLinReqDt))) < 1
        THEN SUM(OpenQty)
        ELSE 0 END
  ELSE 0 END AS Next_Month_Bulk
, CASE WHEN DATEDIFF(MONTH,(GETDATE()),(AFSOrdCancelDt)) = 1
  THEN 
        CASE WHEN DATEDIFF(MONTH,CAST(AFSOrdCancelDt AS Date),(DATEADD(day, 7,SchedLinReqDt))) = 1
        THEN SUM(OpenQty)
        ELSE 0 END
  ELSE 0 END AS Next_Month_Bulk_LandingMonthAfter
, CASE WHEN DATEDIFF(MONTH,(GETDATE()),(AFSOrdCancelDt)) = 1
  THEN SUM(OpenQty)
  ELSE 0 END AS Next_Month_TotalBulk
, SUM(OpenQty)  AS OpenAmt
INTO #BULK1
FROM KEEN_Analytics.dbo.vwSalesOrdersBySize
WHERE SAPOrderId IN (SELECT SAPOrderID FROM #BULK0)
AND Plant = '1010'
AND OpenQty > 0
AND DATEDIFF(MONTH,(GETDATE()),(AFSOrdCancelDt)) < 2
AND DATEDIFF(MONTH,(GETDATE()),(AFSOrdCancelDt)) > -1
GROUP BY
Material
, CustPOId
, AFSReqDt
, SchedLinReqDt
, ReqDelivDt
, AFSOrdCancelDt
;
DROP TABLE IF EXISTS #BULK2;
SELECT
Material
, BulkMonth
, SUM(Current_Month_bulk) AS Current_Month_bulk
, SUM(Current_Month_Bulk_LandingNextMonth) AS Current_Month_Bulk_LandingNextMonth
, SUM(Current_Month_TotalBulk) AS Current_Month_TotalBulk
, SUM(Next_Month_Bulk) AS Next_Month_Bulk
, SUM(Next_Month_Bulk_LandingMonthAfter) AS Next_Month_Bulk_LandingMonthAfter
, SUM(Next_Month_TotalBulk) AS Next_Month_TotalBulk
INTO #BULK2
FROM #BULK1
GROUP BY
Material
, BulkMonth
;
DROP TABLE IF EXISTS #FinalBulk;
SELECT
Material
, MAX(Current_Month_bulk) as CurrentBulk
, MAX(Current_Month_Bulk_LandingNextMonth) AS CurrentBulk_LandingNextMonth
, MAX(Current_Month_TotalBulk) AS CurrentBulk_Total
, MAX(Next_Month_Bulk) AS NextBulk
, MAX(Next_Month_Bulk_LandingMonthAfter) AS NextBulk_LandingMonthAfter
, MAX(Next_month_totalbulk) AS NextBulk_Total
INTO #FinalBulk
FROM #BULK2
GROUP BY
Material
;
DROP TABLE IF EXISTS #ATS1;
SELECT
Plant
, Material
, MaterialDescription
, Category
, CASE WHEN CAST(MaterialAvailDate AS Date) <= GETDATE()
  THEN SUM(Quantity)
  ELSE 0 END AS CURRENTAVAILABLE
, CASE WHEN CAST(MaterialAvailDate AS Date) BETWEEN GETDATE() AND (GETDATE()+7)
  THEN SUM(Quantity)
  ELSE 0 END AS ONEWEEK_INBOUND
, CASE WHEN CAST(MaterialAvailDate AS Date) BETWEEN GETDATE() AND (GETDATE()+14)
  THEN SUM(Quantity)
  ELSE 0 END AS TWOWEEK_INBOUND
, CASE WHEN CAST(MaterialAvailDate AS Date) BETWEEN GETDATE() AND (GETDATE()+28)
  THEN SUM(Quantity)
  ELSE  0 END AS FOURWEEK_INBOUND
, CASE WHEN CAST(MaterialAvailDate AS Date) BETWEEN GETDATE() AND (GETDATE()+56)
  THEN SUM(Quantity)
  ELSE  0 END AS EIGHTWEEK_INBOUND
, CASE WHEN CAST(MaterialAvailDate AS Date) BETWEEN GETDATE() AND (GETDATE()+112)
  THEN SUM(Quantity)
  ELSE  0 END AS SIXTEENWEEK_INBOUND
INTO #ATS1
FROM KEEN_Analytics.dbo.vwATSBySize A
WHERE Plant = '1010'
GROUP BY
Plant
, Material
, Category
, MaterialDescription
, MaterialAvailDate
;
DROP TABLE IF EXISTS #FINAL_ATS;
SELECT
Material
, MaterialDescription
, Category
, SUM(CurrentAvailable) AS CURRENT_INV
, SUM(ONEWEEK_INBOUND) AS [1W_INBOUND]
, SUM(TWOWEEK_INBOUND) AS [2W_INBOUND]
, SUM(FOURWEEK_INBOUND) AS [4W_INBOUND]
, SUM(EIGHTWEEK_INBOUND) AS [8W_INBOUND]
, SUM(SIXTEENWEEK_INBOUND) AS [16W_INBOUND]
INTO #FINAL_ATS
FROM #ATS1
GROUP BY
Material
, Category
, MaterialDescription
;
DROP TABLE IF EXISTS #SELLIN1;
SELECT
Material
, MaterialDescription
, Category
, SUM(ShipQty) AS T4W_SellIN_Units
, SUM(ShipAmt) AS T4W_SellIN_Rev
INTO #SELLIN1
FROM KEEN_Analytics.dbo.vwBetaMask
WHERE OrderType NOT IN ('FREE OF CHARGE', 'CONS. RETURN', 'ADJUST/RETURN', 'SAMPLES')
AND SalesOrgName = ('US')
AND ForecastGroup LIKE '%AMAZON%'
AND CAST(TransactionDt AS date) > GETDATE()-29
AND ShipQty > 0
GROUP BY
Material
, Category
, MaterialDescription
;
DROP TABLE IF EXISTS #SELLOPEN0;
SELECT
Material
, MaterialDescription
, Category
, CASE WHEN DATEDIFF(MONTH, GETDATE(), RequestshipDt) = 0
  THEN SUM(ShipOpenQty)
  ELSE 0 END AS Current_Month_Open
, CASE WHEN DATEDIFF(MONTH, GETDATE(), RequestshipDt) = 1
  THEN SUM(ShipOpenQty)
  ELSE 0 END AS [1M_Open]
, CASE WHEN DATEDIFF(MONTH, GETDATE(), RequestshipDt) = 2
  THEN SUM(ShipOpenQty)
  ELSE 0 END AS [2M_Open]
INTO #SELLOPEN0
FROM KEEN_Analytics.dbo.vwBetaMask
WHERE OrderType NOT IN ('FREE OF CHARGE', 'CONS. RETURN', 'ADJUST/RETURN', 'SAMPLES')
AND SalesOrgName = ('US')
AND ForecastGroup LIKE '%AMAZON%'
AND PastOriginalShipDt = 0
AND OrderStatus = 'OPEN'
AND OrderType NOT IN ('BULK AT ONCE', 'PRE-SEASON BULK')
GROUP BY
Material
, Category
, MaterialDescription
, RequestShipDt
;
DROP TABLE IF EXISTS #SELLOPEN1;
SELECT
Material
, MaterialDescription
, Category
, SUM(Current_Month_Open) AS Current_Month_Open
, SUM([1M_Open]) AS [1M_Open]
, SUM([2M_Open]) AS [2M_Open]
INTO #SELLOPEN1
FROM #SELLOPEN0
GROUP BY
Material
, MaterialDescription
, Category
;
DROP TABLE IF EXISTS #SELLTHRU0;
SELECT
material_no
, Material_Description
, CAST([Week] AS date) AS [week]
, ty_units_sls
, ty_eow_units_oh
INTO #SELLTHRU0
FROM KEEN_Analytics.dbo.vwSps_Sell_Through_Data
where Retailer LIKE '%AMAZON%'
AND CAST([Week] AS date) > GETDATE()-35
;
DROP TABLE IF EXISTS #SELLTHRU07;
SELECT
material_no
, Material_Description
, SUM(ty_units_sls) AS T4W_Sellthru_units
INTO #SELLTHRU07
FROM #SELLTHRU0
GROUP BY material_no, Material_Description
;
DROP TABLE IF EXISTS #SELLTHRU1;
SELECT
s.material_no
, s.material_description
, T4W_Sellthru_units
, O.ty_eow_units_oh AS T4W_retaileravg_onhand
INTO #SELLTHRU1
FROM #SELLTHRU0 s
JOIN(SELECT material_no, ty_eow_units_oh, [week] FROM #SELLTHRU0 where [week] = (SELECT MAX([week]) FROM #SELLTHRU0)) O
ON O.material_no = s.material_no
AND O.[week] = S.[week]
JOIN #SELLTHRU07 SS
ON SS.material_no = s.material_no
;
DROP TABLE IF EXISTS #VANGUARD;
SELECT
CAST(FileDate AS Date) AS VanguardDate
, Module
, DATEADD(MONTH, DATEDIFF(MONTH, 0, FileDate), 0) AS SubmitMonthYear
, DATEADD(MONTH, DATEDIFF(MONTH, 0, DemandDate), 0) AS ForecastMonthYear
, CalendarSeason
, Material
, SUM(Quantity) AS Forecast
INTO #VANGUARD
FROM KEEN_Analytics.dbo.vwVanguardForecast
where ForecastGroup LIKE '%AMAZON%'
AND Module = 'SalesForecast'
GROUP BY Module
, DemandDate
, CalendarSeason
, Material
, FileDate
;
DROP TABLE IF EXISTS #VANGUARD0;
SELECT
MAX(VanguardDate) AS VanguardDate
, CAST(SubmitMonthYear AS date) AS SubmittedDate
, CAST(ForecastMonthYear as date) AS ForecastedDate
, CalendarSeason
, Material
, Forecast
INTO #VANGUARD0
FROM #VANGUARD
GROUP BY
SubmitMonthYear
, ForecastMonthYear
, CalendarSeason
, Material
, Forecast
;
DROP TABLE IF EXISTS #VANGUARD05;
SELECT
Material
, CASE WHEN DATEDIFF(MONTH, GETDATE(), ForecastedDate) = 0
  THEN SUM(Forecast)
  ELSE 0 END AS Current_Month_Forecast
, CASE WHEN DATEDIFF(MONTH, GETDATE(), ForecastedDate) = 1
  THEN SUM(Forecast)
  ELSE 0 END AS [1M_Forecast]
, CASE WHEN DATEDIFF(MONTH, GETDATE(), ForecastedDate) = 2
  THEN SUM(Forecast)
  ELSE 0 END AS [2M_Forecast]
INTO #VANGUARD05
FROM #VANGUARD0
GROUP BY
Material
, ForecastedDate
;
DROP TABLE IF EXISTS #VANGUARD1;
SELECT
Material
, MAX(Current_Month_Forecast) AS Current_Month_Forecast
, MAX([1M_Forecast]) AS [1M_Forecast]
, MAX([2M_Forecast]) AS [2M_Forecast]
INTO #VANGUARD1
FROM #VANGUARD05
GROUP BY Material
;
DROP TABLE IF EXISTS #FINAL1
SELECT
COALESCE(B.Material, A.Material, I.Material, O.Material, T.Material_No, V.Material) AS Material
, C.MaterialDescription AS MaterialDescription
, COALESCE(A.Category, C.Category) AS Category
, Model
, Gender
, ISNULL(T4W_Sellthru_units,0) AS T4W_Sellthru_units
, ISNULL(T4W_SellIN_Units, 0) AS T4W_SellIN_Units
, ISNULL(T4W_retaileravg_onhand, 0) AS T4W_retaileravg_onhand
, ISNULL(Current_Month_Open, 0) AS Current_Month_Open
, ISNULL([1M_Open], 0) AS [1M_Open]
, ISNULL([2M_Open], 0) AS [2M_Open]
, ISNULL(CURRENT_INV, 0) AS CURRENT_INV
, ISNULL(CURRENTBULK, 0) AS CURRENTBULK
, ISNULL(CurrentBulk_LandingNextMonth, 0) AS CurrentBulk_LandingNextMonth
, ISNULL(CurrentBulk_Total, 0) AS CurrentBulk_Total
, ISNULL(NextBulk, 0) AS NextBulk
, ISNULL(NextBulk_LandingMonthAfter, 0) AS NextBulk_LandingMonthAfter
, ISNULL(NextBulk_Total, 0) AS NextBulk_Total
, ISNULL([1W_INBOUND], 0) AS [1W_INBOUND]
, ISNULL([2W_INBOUND], 0) AS [2W_INBOUND]
, ISNULL([4W_INBOUND], 0) AS [4W_INBOUND]
, ISNULL([8W_INBOUND], 0) AS [8W_INBOUND]
, ISNULL([16W_INBOUND], 0) AS [16W_INBOUND]
, ISNULL(Current_Month_Forecast, 0) AS Current_Month_Forecast
, ISNULL([1M_Forecast], 0) AS [1M_Forecast]
, ISNULL([2M_Forecast], 0) AS [2M_Forecast]
INTO #FINAL1
FROM #FinalBulk B
FULL OUTER JOIN #FINAL_ATS A 
ON B.Material = A.Material
FULL OUTER JOIN #SELLIN1 I 
ON I.Material = B.Material
FULL OUTER JOIN #SELLOPEN1 O
ON O.Material = B.Material
FULL OUTER JOIN #SELLTHRU1 T
ON T.material_no = B.Material
FULL OUTER JOIN #VANGUARD1 V
ON V.Material = B.Material
FULL OUTER JOIN (SELECT DISTINCT Material, MaterialDescription, category, Model, Gender FROM KEEN_Analytics.dbo.vwStyleMaster) AS C
ON  COALESCE(B.Material, A.Material, I.Material, O.Material, T.Material_No, V.Material) = C.Material
WHERE COALESCE(B.Material, A.Material, I.Material, O.Material, T.Material_No, V.Material) IS NOT NULL
;
SELECT
CAST(Material as int) AS Material
, MaterialDescription
, Category
, Model
, Gender
, MAX(T4W_SellIN_Units) AS T4W_SellIN
, MAX(Current_Month_Open) AS Current_Month_Open
, MAX([1M_Open]) AS [1M_Open]
, MAX([2M_Open]) AS [2M_Open]
, MAX(Current_Month_Forecast) AS Current_Month_Forecast
, MAX([1M_Forecast]) AS [1M_Forecast]
, MAX([2M_Forecast]) AS [2M_Forecast]
, MAX(T4W_Sellthru_units) AS T4W_SellTHRU
, MAX(T4W_retaileravg_onhand) AS Retailer_Onhand
, MAX(CURRENT_INV) AS CURRENT_ATS
, MAX([1W_INBOUND]) AS [1W_INBOUND]
, MAX([2W_INBOUND]) AS [2W_INBOUND]
, MAX([4W_INBOUND]) AS [4W_INBOUND]
, MAX([8W_INBOUND]) AS [8W_INBOUND]
, MAX([16W_INBOUND]) AS [16W_INBOUND]
, MAX(CURRENTBULK) AS CURRENT_BULK
, MAX(CurrentBulk_LandingNextMonth) AS CurrentBulk_LandingNextMonth
, MAX(CurrentBulk_Total) AS CurrentBulk_Total
, MAX(NextBulk) AS NextBulk
, MAX(NextBulk_LandingMonthAfter) AS NextBulk_LandingMonthAfter
, MAX(NextBulk_Total) AS NextBulk_Total
FROM #FINAL1
where
Material <> 'Other'
AND
(T4W_SellIN_Units
 +T4W_Sellthru_units
 +T4W_retaileravg_onhand
 +CURRENT_INV
 +CURRENTBULK
 +CurrentBulk_LandingNextMonth
 +CurrentBulk_Total
 +NextBulk
 +NextBulk_LandingMonthAfter
 +NextBulk_Total
 +[1W_INBOUND]
 +[2W_INBOUND]
 +[4W_INBOUND]
 +[8W_INBOUND]
 +[16W_INBOUND]
 +Current_Month_Open
 +[1M_Open]
 +[2M_Open]
 +Current_Month_Forecast
 +[1M_Forecast]
 +[2M_Forecast]) > 0
 GROUP BY Material, MaterialDescription, Category, Model, Gender

 