DROP TABLE IF EXISTS #SALESTABLE;
SELECT DISTINCT 
SalesForecastGroup_Adjusted = CASE
WHEN ForecastGroup LIKE '%AMAZON%' THEN 'AMAZON'
WHEN (ForecastGroup = 'CABELAS' OR ForecastGroup = 'ANDREW HEWAT - CABELAS' OR ForecastGroup = 'BASS PRO SHOP') THEN 'CABELAS/BASS PRO'
WHEN ForecastGroup = 'ANDREW HEWAT - MARKS' THEN 'MARKS'
WHEN (ForecastGroup = 'PAO' OR ForecastGroup = 'PDX') THEN 'US KEEN RETAIL'
ELSE ForecastGroup END
, ForecastGroup
INTO #SALESTABLE
FROM vwBetaMask
;

DROP TABLE IF EXISTS #VANGUARDTABLE;
SELECT DISTINCT
 VanguardForecastGroup_Adjusted = CASE
	WHEN ForecastGroup = 'ALL_OTHER' THEN 'ALL OTHER'
	WHEN ForecastGroup LIKE '%AMAZON%' THEN 'AMAZON'
	WHEN (ForecastGroup = 'BASS_PRO_SHOP' OR ForecastGroup = 'CABELAS') THEN 'CABELAS/BASS PRO'
	WHEN ForecastGroup = 'BOOT_BARN' THEN 'BOOT BARN'
	WHEN ForecastGroup = 'DICKS_SPORTING_GOODS' THEN 'DICKS SPORTING GOODS'
	WHEN ForecastGroup = 'DSW_INC' THEN 'DSW INC'
	WHEN ForecastGroup = 'DULUTH_HOLDINGS_INC' THEN 'DULUTH HOLDINGS INC'
	WHEN ForecastGroup = 'FAMILY_FOOTWEAR' THEN 'FAMILY FOOTWEAR'
	WHEN (ForecastGroup = 'PAO GARAGE' OR ForecastGroup = 'PDX GARAGE') THEN 'US KEEN RETAIL' 
	WHEN ForecastGroup = 'SPORTSMAN''S_WAREHOUSE' THEN 'SPORTSMAN''S WAREHOUSE'
	WHEN ForecastGroup = 'LL_BEAN' THEN 'LL BEAN'
	ELSE ForecastGroup 
	END
, ForecastGroup
INTO #VANGUARDTABLE
FROM vwVanguardForecast
;

DROP TABLE IF EXISTS #RecentForecast0;
SELECT 
MAX(FileDate) AS RecentDate
, CASE WHEN Region = 'KEEN ONLINE' THEN 'US KEEN ONLINE' ELSE VanguardForecastGroup_Adjusted  END AS ForecastGroup
, CAST(Material as int) AS Material	
, CalendarYear
, CalendarSeason
, CalendarMonth
, MONTH(DemandDate) AS CalendarMonthNumber
, Quantity


INTO #RecentForecast0
FROM KEEN_Analytics.dbo.vwVanguardForecast V
JOIN #VANGUARDTABLE VT
ON VT.ForecastGroup = V.ForecastGroup

where Module = 'SalesForecast'
AND SalesOrgName = 'US'
AND CurrentFlag = 1
AND Material LIKE '1%'
AND CalendarYear >= YEAR(GETDATE()-720)

GROUP BY
VanguardForecastGroup_Adjusted
, Material
, CalendarYear
, CalendarSeason
, CalendarMonth
, Quantity
, DemandDate
, Region
;

DROP TABLE IF EXISTS #RecentForecast;
SELECT 
RecentDate
, ForecastGroup
, Material	
, CalendarYear
, CalendarSeason
, CalendarMonth
, CalendarMonthNumber
, SUM(Quantity) AS Quantity


INTO #RecentForecast
FROM #RecentForecast0

GROUP BY
RecentDate
, ForecastGroup
, Material	
, CalendarYear
, CalendarSeason
, CalendarMonth
, CalendarMonthNumber
;

DROP TABLE IF EXISTS #SoT;
SELECT
RecentDate
, ForecastGroup
, Material	
, P.CalendarYear
, P.CalendarSeason
, CalendarMonth
, CalendarMonthNumber
, Quantity
INTO #SoT
FROM #RecentForecast P
WHERE Material IS NOT NULL
AND Material LIKE '1%'
;

DROP TABLE IF EXISTS #Sales0;
SELECT 
TransactionCalendarYear
, TransactionCalendarMonthNumber
, TheSeasonName
, SalesForecastGroup_Adjusted AS ForecastGroup
, Region
, Material
, MaterialDescription
, Category
, OrderType
, ShipQty
, ShipAmt
, OpenQty
, OpenAmt
INTO #Sales0
FROM KEEN_Analytics.dbo.vwBetaMask B
JOIN vwKA_Calendar K
ON B.TransactionDt = K.TheDate
JOIN #SALESTABLE ST
ON ST.ForecastGroup = B.ForecastGroup
WHERE OrderType NOT IN ('FREE OF CHARGE', 'CONS. RETURN', 'ADJUST/RETURN', 'SAMPLES','KEEN ONLINE BULK', 'PRE-SEASON BULK', 'BULK AT ONCE')
AND SalesOrgName = ('US')
AND B.ForecastGroup NOT IN('EXCLUDE', 'INACTIVE', 'INTERNAL')
AND CAST(RequestShipDt AS date) > (GETDATE()-720)
AND Material LIKE '1%'
;

DROP TABLE IF EXISTS #Sales05;
SELECT 
TransactionCalendarYear
, TransactionCalendarMonthNumber
, TheSeasonName
, ForecastGroup
, Material
, MaterialDescription
, Category
, CASE WHEN OrderType = 'CLOSEOUT' THEN SUM(ShipQty) ELSE 0 END AS 'Closeout_SoldQuantity'
, CASE WHEN OrderType = 'CLOSEOUT' THEN SUM(ShipAmt) ELSE 0 END AS 'Closeout_SoldRevenue'
, CASE WHEN OrderType = 'PRE-SEASON' THEN SUM(ShipQty) ELSE 0 END AS 'PreSeason_SoldQuantity'
, CASE WHEN OrderType = 'PRE-SEASON' THEN SUM(ShipAmt) ELSE 0 END AS 'PreSeason_SoldRevenue'
, CASE WHEN OrderType = 'AT ONCE' THEN SUM(ShipQty) ELSE 0 END AS 'AtOnce_SoldQuantity'
, CASE WHEN OrderType = 'AT ONCE' THEN SUM(ShipAmt) ELSE 0 END AS 'AtOnce_SoldRevenue'
, CASE WHEN OrderType = 'CLOSEOUT' THEN SUM(OpenQty) ELSE 0 END AS 'Closeout_OpenQuantity'
, CASE WHEN OrderType = 'CLOSEOUT' THEN SUM(OpenAmt) ELSE 0 END AS 'Closeout_OpenRevenue'
, CASE WHEN OrderType = 'PRE-SEASON' THEN SUM(OpenQty) ELSE 0 END AS 'PreSeason_OpenQuantity'
, CASE WHEN OrderType = 'PRE-SEASON' THEN SUM(OpenAmt) ELSE 0 END AS 'PreSeason_OpenRevenue'
, CASE WHEN OrderType = 'AT ONCE' THEN SUM(OpenQty) ELSE 0 END AS 'AtOnce_OpenQuantity'
, CASE WHEN OrderType = 'AT ONCE' THEN SUM(OpenAmt) ELSE 0 END AS 'AtOnce_OpenRevenue'
, SUM(ShipQty) AS Units
, SUM(ShipAmt) AS Rev
, SUM(OpenQty) AS OpenUnits
, SUM(OpenAmt) AS OpenAmt
INTO #Sales05
FROM #Sales0 S


GROUP BY
TransactionCalendarYear
, TransactionCalendarMonthNumber
, ForecastGroup
, Material
, MaterialDescription
, TheSeasonName
, Category
, OrderType
;

DROP TABLE IF EXISTS #Sales;
SELECT 
TransactionCalendarYear
, TransactionCalendarMonthNumber
, TheSeasonName
, ForecastGroup
, Material
, MaterialDescription
, Category
, SUM(Closeout_SoldQuantity) AS Closeout_SoldQuantity
, SUM(Closeout_SoldRevenue) AS Closeout_SoldRevenue
, SUM(PreSeason_SoldQuantity) AS PreSeason_SoldQuantity
, SUM(PreSeason_SoldRevenue) AS PreSeason_SoldRevenue
, SUM(AtOnce_SoldQuantity) AS AtOnce_SoldQuantity
, SUM(AtOnce_SoldRevenue) AS AtOnce_SoldRevenue
, SUM(Closeout_OpenQuantity) AS Closeout_OpenQuantity
, SUM(Closeout_OpenRevenue) AS Closeout_OpenRevenue
, SUM(PreSeason_OpenQuantity) AS PreSeason_OpenQuantity
, SUM(PreSeason_OpenRevenue) AS PreSeason_OpenRevenue
, SUM(AtOnce_OpenQuantity) AS AtOnce_OpenQuantity
, SUM(AtOnce_OpenRevenue) AS AtOnce_OpenRevenue
, SUM(Units) AS Units
, SUM(Rev) AS Rev
, SUM(OpenUnits) AS OpenUnits
, SUM(OpenAmt) AS OpenAmt
INTO #Sales
FROM #Sales05 S


GROUP BY
TransactionCalendarYear
, TransactionCalendarMonthNumber
, ForecastGroup
, Material
, MaterialDescription
, TheSeasonName
, Category
;

DROP TABLE IF EXISTS #Seasons;
SELECT 
SAPMaterialNo
, MIN(YEAR(RIGHT(Season, 4))) AS Earliest_Year
, MAX(YEAR(RIGHT(Season, 4))) AS Latest_Year
, COUNT(DISTINCT Season) AS Total_Seasons
INTO #Seasons
FROM KEEN_Analytics.dbo.vwCentricLineList C
WHERE SAPMaterialNo LIKE '1%'
GROUP BY SAPMaterialNo
;

DROP TABLE IF EXISTS #Final0;
SELECT DISTINCT
COALESCE(SO.ForecastGroup, SA.ForecastGroup) AS ForecastGroup
, CAST(COALESCE(SO.Material, SE.SAPMaterialNo, SA.Material) as int) AS Material
, COALESCE(SA.MaterialDescription, SM.MaterialDescription) AS MaterialDescription
, CASE WHEN
	(COALESCE(SA.MaterialDescription, SM.MaterialDescription) LIKE '%K-%'
	OR 
	COALESCE(SA.MaterialDescription, SM.MaterialDescription) LIKE '% FB %') THEN 'Footbed'
	ELSE
		CASE WHEN COALESCE(SA.MaterialDescription, SM.MaterialDescription) LIKE '%CREW%' THEN 'Socks'
		ELSE COALESCE(SA.Category, SM.Category) 
		END
	END AS Category
, COALESCE(SO.CalendarYear, TransactionCalendarYear) AS [Year]
, COALESCE(SO.CalendarSeason, TheSeasonName) AS CalendarSeason
, FORMAT(COALESCE(CalendarMonthNumber, TransactionCalendarMonthNumber),'D2')AS [Month]
, ISNULL(Quantity,0) AS Forecasted_Quantity
, ISNULL(Units,0) AS Sold_Quantity
, ISNULL(Rev,0) AS Actual_Revenue
, ISNULL(OpenUnits, 0) AS Open_Quantity
, ISNULL(OpenAmt, 0) AS Open_Revenue
, ISNULL(Closeout_SoldQuantity, 0) AS Closeout_SoldQuantity
, ISNULL(Closeout_SoldRevenue, 0) AS Closeout_SoldRevenue
, ISNULL(PreSeason_SoldQuantity, 0) AS PreSeason_SoldQuantity
, ISNULL(PreSeason_SoldRevenue, 0) AS PreSeason_SoldRevenue
, ISNULL(AtOnce_SoldQuantity, 0) AS AtOnce_SoldQuantity
, ISNULL(AtOnce_SoldRevenue, 0) AS AtOnce_SoldRevenue
, ISNULL(Closeout_OpenQuantity, 0) AS Closeout_OpenQuantity
, ISNULL(Closeout_OpenRevenue, 0) AS Closeout_OpenRevenue
, ISNULL(PreSeason_OpenQuantity, 0) AS PreSeason_OpenQuantity
, ISNULL(PreSeason_OpenRevenue, 0) AS PreSeason_OpenRevenue
, ISNULL(AtOnce_OpenQuantity, 0) AS AtOnce_OpenQuantity
, ISNULL(AtOnce_OpenRevenue, 0) AS AtOnce_OpenRevenue
, Earliest_Year
, Latest_Year
, Total_Seasons
INTO #Final0
FROM #SoT SO
FULL OUTER JOIN #Sales SA
ON SA.Material = SO.Material
AND SO.ForecastGroup = SA.ForecastGroup
AND SA.TransactionCalendarYear = SO.CalendarYear
AND SA.TransactionCalendarMonthNumber = SO.CalendarMonthNumber
FULL OUTER JOIN #Seasons SE
ON SE.SAPMaterialNo = COALESCE(SO.Material, SA.Material)
FULL OUTER JOIN 
(SELECT Material, MaterialDescription, Category FROM vwStyleMaster WHERE Material LIKE '1%') SM
ON SM.Material = COALESCE(SO.Material, SA.Material)

WHERE 
(SO.CalendarYear IS NOT NULL
OR
TransactionCalendarYear IS NOT NULL)
;

DROP TABLE IF EXISTS #PreTable;
SELECT SAPMaterialNo, Season
, RIGHT(Season,4) AS [Year]
, CASE WHEN Season LIKE '%Spring%' THEN 1 ELSE 2 END AS Ordering
, INLorSMU
, SMUIntent
INTO #PreTable
FROM vwCentricLineList 
where  SAPMaterialNo LIKE '1%'
;

DROP TABLE IF EXISTS #OrderTable;
SELECT SAPMaterialNo, Season, CONCAT([Year], Ordering) AS HistoricSeason 
, [Year]
, CASE WHEN Season LIKE '%Spring%' THEN 'Spring-Summer' ELSE 'Fall-Winter' END AS CalendarSeason
, INLorSMU, SMUIntent
INTO #OrderTable
FROM #PreTable 
ORDER BY HistoricSeason ASC
;

DROP TABLE IF EXISTS #FinalOrder
SELECT SAPMaterialNo
, [Year]
, CalendarSeason
, ROW_NUMBER() OVER (PARTITION BY SAPMaterialNo ORDER BY HistoricSeason ASC) AS SeasonNumber
, Season 
, INLorSMU
, SMUIntent
INTO #FinalOrder
FROM #OrderTable ORDER BY SAPMaterialNo ASC
;

DROP TABLE IF EXISTS #Classification0;
SELECT 
Material
, MaterialDescription
, COALESCE(F0.CalendarSeason, FO.CalendarSeason) AS CalendarSeason
, COALESCE(F0.[Year], FO.[Year]) AS [Year]
, Earliest_Year
, Latest_Year
, SeasonNumber
, SMUIntent
, INLorSMU
INTO #Classification0
FROM #Final0 F0
LEFT JOIN #FinalOrder FO
ON FO.SAPMaterialNo = F0.Material
AND FO.[Year] = F0.[Year]
AND FO.CalendarSeason = F0.CalendarSeason
;

DROP TABLE IF EXISTS #Classification;
SELECT 
Material
, MaterialDescription
, CalendarSeason
, [Year]
, 
CASE WHEN (MaterialDescription LIKE '%K-%' OR MaterialDescription LIKE '% FB %') THEN 'Accessories' ELSE
	CASE WHEN MaterialDescription LIKE '%Crew%' THEN 'Accessories' ELSE
		CASE WHEN SeasonNumber = 1 THEN 'New' ELSE
			CASE WHEN SMUIntent IS NULL THEN
				CASE WHEN [Year] >= Latest_Year THEN 'Discontinued' ELSE
					CASE WHEN [YEAR] <= Earliest_Year THEN 'Early Release' ELSE 'Leap-Style'
					END
				END
			ELSE 'Inline' END
		END
	END 
END AS [Classification]
, CASE WHEN INLorSMU = 'SMU'
  THEN 'Yes'
  ELSE
	CASE WHEN (SMUIntent = 'US' OR SMUIntent = 'US, Canada' OR SMUIntent = 'Canada' OR SMUIntent IS NULL OR DATALENGTH(SMUIntent)=0) THEN 'No' ELSE 'Yes' END
  END AS Exclusive
, SMUIntent
, INLorSMU
, SeasonNumber

INTO #Classification
FROM #Classification0
;

DROP TABLE IF EXISTS #PresentDollars;
SELECT 
CASE WHEN Season LIKE '%Fall%' THEN 'Fall-Winter' ELSE 'Spring-Summer' END AS CalendarSeason
, RIGHT(Season, 4) AS CalendarYear
, SAPMaterialNo
, Gender
, MAX(WHSL) AS WHSL
, MAX(MSRP) AS MSRP
INTO #PresentDollars
FROM vwCentricLineList 
GROUP BY 
Season
, SAPMaterialNo
, Gender
;

DROP TABLE IF EXISTS #Final05;
SELECT
ForecastGroup
, Material
, MaterialDescription
, Category
, MSRP
, WHSL
, [Year]
, F.CalendarSeason
, [Month]
, Forecasted_Quantity
, Sold_Quantity
, Open_Quantity
, Actual_Revenue
, Open_Revenue
, Closeout_SoldQuantity
, Closeout_SoldRevenue
, PreSeason_SoldQuantity
, PreSeason_SoldRevenue
, AtOnce_SoldQuantity
, AtOnce_SoldRevenue
, Closeout_OpenQuantity
, Closeout_OpenRevenue
, PreSeason_OpenQuantity
, PreSeason_OpenRevenue
, AtOnce_OpenQuantity
, AtOnce_OpenRevenue
, Earliest_Year
, Latest_Year
, Total_Seasons
INTO #Final05
FROM #Final0 F
FULL OUTER JOIN #PresentDollars PD
ON PD.SAPMaterialNo = F.Material
AND PD.CalendarYear = F.[Year]
AND PD.CalendarSeason = F.CalendarSeason
WHERE F.Material IS NOT NULL
;

DROP TABLE IF EXISTS #Final;
SELECT
ForecastGroup
, F.Material
, F.MaterialDescription
, F.Category
, WHSL
, MSRP
, [Year]
, F.CalendarSeason
, [Month]
, Forecasted_Quantity
, Sold_Quantity
, Open_Quantity
, Actual_Revenue
, Open_Revenue
, Closeout_SoldQuantity
, Closeout_SoldRevenue
, PreSeason_SoldQuantity
, PreSeason_SoldRevenue
, AtOnce_SoldQuantity
, AtOnce_SoldRevenue
, Closeout_OpenQuantity
, Closeout_OpenRevenue
, PreSeason_OpenQuantity
, PreSeason_OpenRevenue
, AtOnce_OpenQuantity
, AtOnce_OpenRevenue
, Earliest_Year
, Latest_Year
, Total_Seasons
INTO #Final
FROM #Final05 F
WHERE F.Material IS NOT NULL
AND F.Material LIKE '1%'
;

DROP TABLE IF EXISTS #FinalFinal;
SELECT DISTINCT
F.ForecastGroup
, F.Material
, F.MaterialDescription
, F.[Year]
, F.CalendarSeason
, F.[MONTH]
, Forecasted_Quantity
, Sold_Quantity
, Open_Quantity
, Actual_Revenue
, Open_Revenue
, Closeout_SoldQuantity
, Closeout_SoldRevenue
, PreSeason_SoldQuantity
, PreSeason_SoldRevenue
, AtOnce_SoldQuantity
, AtOnce_SoldRevenue
, Closeout_OpenQuantity
, Closeout_OpenRevenue
, PreSeason_OpenQuantity
, PreSeason_OpenRevenue
, AtOnce_OpenQuantity
, AtOnce_OpenRevenue
, MSRP
, WHSL
, SeasonNumber
, [Classification]
, Exclusive
INTO #FinalFinal
FROM #Final F
JOIN #Classification FO
ON FO.Material = F.Material
AND FO.CalendarSeason = F.CalendarSeason
AND FO.[Year] = F.[Year]
;

DROP TABLE IF EXISTS #ProjectedSales0;
SELECT
Material
,ForecastGroup
, [Classification]
, Exclusive
,[MONTH]
,CalendarSeason
,[YEAR]
, WHSL
, MSRP
,Forecasted_Quantity
,Sold_Quantity
, Open_Quantity
, Actual_Revenue
, Open_Revenue
, Closeout_SoldQuantity
, Closeout_SoldRevenue
, PreSeason_SoldQuantity
, PreSeason_SoldRevenue
, AtOnce_SoldQuantity
, AtOnce_SoldRevenue
, Closeout_OpenQuantity
, Closeout_OpenRevenue
, PreSeason_OpenQuantity
, PreSeason_OpenRevenue
, AtOnce_OpenQuantity
, AtOnce_OpenRevenue
, CASE WHEN CAST(CONCAT([YEAR],[MONTH], '01') as date) < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0) 
THEN SUM(Sold_Quantity) ELSE SUM(Forecasted_Quantity) END AS ProjectedSales
, 0 AS Discount

INTO #ProjectedSales0
FROM #FinalFinal
GROUP BY Material
, ForecastGroup
, [MONTH]
, CalendarSeason
, [YEAR]
, Forecasted_Quantity
, Sold_Quantity
, Actual_Revenue
, Exclusive
, [Classification]
, Exclusive
, WHSL
, Open_Quantity
, MSRP
, Open_Revenue
, Closeout_SoldQuantity
, Closeout_SoldRevenue
, PreSeason_SoldQuantity
, PreSeason_SoldRevenue
, AtOnce_SoldQuantity
, AtOnce_SoldRevenue
, Closeout_OpenQuantity
, Closeout_OpenRevenue
, PreSeason_OpenQuantity
, PreSeason_OpenRevenue
, AtOnce_OpenQuantity
, AtOnce_OpenRevenue
;

SELECT
PS.Material
, MaterialDescription
, Category
, Division
, PlaybookDivision
, Gender
, [Classification]
, Exclusive
, ForecastGroup
, [MONTH]
, CalendarSeason
, [YEAR]
, Forecasted_Quantity
, SUM(Sold_Quantity) AS Sold_Quantity
, SUM(Open_Quantity) AS Open_Quantity
, SUM(Actual_Revenue) AS Actual_Revenue
, SUM(Open_Revenue) AS Open_Revenue
, SUM(Closeout_SoldQuantity) AS Closeout_SoldQuantity
, SUM(Closeout_SoldRevenue) AS Closeout_SoldRevenue
, SUM(PreSeason_SoldQuantity) AS PreSeason_SoldQuantity
, SUM(PreSeason_SoldRevenue) AS PreSeason_SoldRevenue
, SUM(AtOnce_SoldQuantity) AS AtOnce_SoldQuantity
, SUM(AtOnce_SoldRevenue) AS AtOnce_SoldRevenue
, SUM(Closeout_OpenQuantity) AS Closeout_OpenQuantity
, SUM(Closeout_OpenRevenue) AS Closeout_OpenRevenue
, SUM(PreSeason_OpenQuantity) AS PreSeason_OpenQuantity
, SUM(PreSeason_OpenRevenue) AS PreSeason_OpenRevenue
, SUM(AtOnce_OpenQuantity) AS AtOnce_OpenQuantity
, SUM(AtOnce_OpenRevenue) AS AtOnce_OpenRevenue
, ProjectedSales
, CASE WHEN PS.MSRP IS NULL 
	THEN (SM.Price*2) 
	ELSE PS.MSRP
	END AS MSRP
, CASE WHEN PS.WHSL IS NULL 
	THEN (SM.Price)
	ELSE PS.WHSL
	END AS WHSL


FROM #ProjectedSales0 PS
JOIN vwStyleMaster SM
ON SM.Material = PS.Material


WHERE SM.Material LIKE '1%'

GROUP BY 
PS.Material
, MaterialDescription
, Category
, Division
, PlaybookDivision
, [Classification]
, Exclusive
, ForecastGroup
, [MONTH]
, CalendarSeason
, [YEAR]
, Forecasted_Quantity
, ProjectedSales
, WHSL
, MSRP
, Gender
, Price
;