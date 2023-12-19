DROP TABLE IF EXISTS #PreTable;
SELECT SAPMaterialNo, Season
, RIGHT(Season,4) AS [Year]
, CASE WHEN Season LIKE '%Spring%' THEN 1 ELSE 2 END AS Ordering
, INLorSMU
, SMUIntent
, [model]
, MSRP
, WHSL
INTO #PreTable
FROM vwCentricLineList 
-- where Category IN ('Service', 'Utility', 'Industrial') AND 
WHERE SAPMaterialNo LIKE '1%'
;
DROP TABLE IF EXISTS #OrderTable;
SELECT SAPMaterialNo, Season, CONCAT([Year], Ordering) AS HistoricSeason 
, [Year]
, CASE WHEN Season LIKE '%Spring%' THEN 'Spring-Summer' ELSE 'Fall-Winter' END AS CalendarSeason
, INLorSMU, SMUIntent, [model]
, MSRP
, WHSL
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
, SMUIntent, [model]
, MSRP
, WHSL
INTO #FinalOrder
FROM #OrderTable ORDER BY SAPMaterialNo ASC
;
DROP TABLE IF EXISTS #Seasons;
SELECT 
SAPMaterialNo
, MIN(YEAR(RIGHT(Season, 4))) AS Earliest_Year
, MAX(YEAR(RIGHT(Season, 4))) AS Latest_Year
, COUNT(DISTINCT Season) AS Total_Seasons
INTO #Seasons
FROM #PreTable
WHERE SAPMaterialNo LIKE '1%'
GROUP BY SAPMaterialNo
;
DROP TABLE IF EXISTS #Classification0;
SELECT 
F.SAPMaterialNo AS Material
, CalendarSeason
, [Year]
, Earliest_Year
, Latest_Year
, SeasonNumber
, SMUIntent, [model]
, INLorSMU
, MSRP
, WHSL
INTO #Classification0
FROM #FinalOrder F
JOIN #Seasons S ON S.SAPMaterialNo = F.SAPMaterialNo
;
DROP TABLE IF EXISTS #Classification;
SELECT 
Material
, CalendarSeason
, [Year]
, 
CASE WHEN ([model] LIKE '%K-%' OR [model] LIKE '%Crew%') THEN 'Accessories' ELSE
		CASE WHEN SeasonNumber = 1 THEN 'New' ELSE
			CASE WHEN SMUIntent IS NULL THEN
				CASE WHEN [Year] >= Latest_Year THEN 'Discontinued' ELSE
					CASE WHEN [YEAR] <= Earliest_Year THEN 'Early Release' ELSE 'Leap-Style'
					END
				END
			ELSE 'Inline' END
		END
	END AS [Classification]
, SMUIntent
, INLorSMU
, SeasonNumber
, MSRP
, WHSL
INTO #Classification
FROM #Classification0
;

SELECT 
C.Material
, MaterialDescription
, [Year]
, CalendarSeason
, Category
, [Classification]
, INLorSMU
, SMUIntent
, 
CASE WHEN INLorSMU = 'UTY' THEN 
	CASE WHEN (
	SMUIntent = 'US' 
	OR SMUIntent = 'US, Canada' 
	OR SMUIntent IS NULL 
	OR DATALENGTH(SMUIntent)=0
	OR SMUIntent = 'Canada'  
	) THEN 'No' ELSE 'Yes' END
	ELSE
		CASE WHEN INLorSMU = 'INL' 
		THEN 'No' 
		ELSE 'Yes' END
	END
AS Exclusive
, MSRP
, WHSL
FROM #Classification C
JOIN vwStyleMaster S
ON S.Material = C.Material