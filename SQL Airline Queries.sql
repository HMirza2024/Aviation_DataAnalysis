create database airliness;
select * from airliness.flights;
select * from airliness.airlines;
select * from airliness.airports;
select * from airliness.cancellation_codes;

#Which airports are "bottlenecks" that cause the most delays for everyone else?

SELECT 
    o.AIRPORT AS Origin_Airport,
    AVG(f.DEPARTURE_DELAY) AS Avg_Dep_Delay,
    COUNT(*) AS Total_Flights
FROM flights f
JOIN airports o ON f.ORIGIN_AIRPORT = o.IATA_CODE
GROUP BY o.AIRPORT
HAVING COUNT(*) > 100
ORDER BY Avg_Dep_Delay DESC;

/*Albuquerque International Sunport and Dallas/Fort Worth International Airport emerge as major bottlenecks, 
showing the highest average departure delays despite having substantial flight volumes*/



#Business Problem: What is the overall health of our operations?
#SQL Goal: Calculate the percentage of flights that arrived on time (delay <= 15 min).

SELECT 
    ROUND(SUM(CASE WHEN ARRIVAL_DELAY <= 15 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS OTP_Percentage
FROM flights
WHERE CANCELLED = 0;
#77.67% of flights arrived on time whose delay was less than equal to 15 minutes



#Calculate the total minutes lost to each specific delay category.

SELECT 
    SUM(AIRLINE_DELAY) AS Carrier_Minutes,
    SUM(WEATHER_DELAY) AS Weather_Minutes,
    SUM(AIR_SYSTEM_DELAY) AS Air_Traffic_Control_Minutes,
    SUM(SECURITY_DELAY) AS Security_Minutes,
    SUM(LATE_AIRCRAFT_DELAY) AS Late_Arrival_Propagation_Minutes
FROM flights
WHERE ARRIVAL_DELAY > 0;



#Business Problem: At what time of day does our system become most congested? 
#SQL Goal: Find the average delay per hour of scheduled departure.

SELECT 
    FLOOR(SCHEDULED_DEPARTURE / 100) AS Departure_Hour,
    AVG(DEPARTURE_DELAY) AS Avg_Delay
FROM flights
GROUP BY Departure_Hour
ORDER BY Departure_Hour;

/*System congestion steadily increases through the morning, 
with average departure delays rising from early hours and peaking around mid-morning onward, 
indicating compounding delays as the day progresses.*/



#Business Problem: Which major hubs are causing the most significant "bottleneck" effects for the entire network? 
#SQL Goal: Rank airports with over 10,000 flights by their average departure delay.

SELECT 
    ORIGIN_AIRPORT,
    COUNT(*) AS Flight_Volume,
    AVG(DEPARTURE_DELAY) AS Avg_Departure_Delay
FROM flights
GROUP BY ORIGIN_AIRPORT
HAVING COUNT(*) > 1000
ORDER BY Avg_Departure_Delay DESC;

/*Among high-volume hubs, Dallas/Fort Worth (DFW) and Denver (DEN) create the strongest network-wide bottlenecks, 
combining heavy traffic with the highest average departure delays*/



#Business Problem: Which airline is the most reliable partner for code-sharing? 
#SQL Goal: Rank airlines by their "Cancellation Rate".

SELECT 
    a.AIRLINE,
    ROUND(SUM(f.CANCELLED) * 100.0 / COUNT(*), 2) AS Cancellation_Rate
FROM flights f
JOIN airlines a ON f.AIRLINE = a.IATA_CODE
GROUP BY a.AIRLINE
ORDER BY Cancellation_Rate ASC;

/*ALmost all airlines have zero cancellation rate*/



#Business Problem: Does a late start in the morning inevitably ruin the rest of the day for that specific aircraft? 
#SQL Goal: Compare the average delay of an aircraft's first flight of the day versus its second flight.

WITH Daily_Flights AS (
    SELECT 
        TAIL_NUMBER,
        DATE(CONCAT(YEAR, '-', MONTH, '-', DAY)) AS FLIGHT_DATE,
        DEPARTURE_DELAY,
        ROW_NUMBER() OVER (
            PARTITION BY 
                TAIL_NUMBER,
                DATE(CONCAT(YEAR, '-', MONTH, '-', DAY))
            ORDER BY SCHEDULED_DEPARTURE
        ) AS Flight_Sequence
    FROM flights
)
SELECT 
    Flight_Sequence,
    AVG(DEPARTURE_DELAY) AS Avg_Delay
FROM Daily_Flights
WHERE Flight_Sequence <= 2
GROUP BY Flight_Sequence;
/*Aircraft that start the day with a delay tend to fall further behind, as the second flight shows a significantly higher average departure delay than the first.*/




#Business Problem: Are ground operations (taxiing) a hidden source of delay? 
#SQL Goal: Find airports where actual taxi-out time significantly exceeds the national average.

SELECT 
    ORIGIN_AIRPORT,
    AVG(TAXI_OUT) AS Avg_Taxi_Out_Time
FROM flights
GROUP BY ORIGIN_AIRPORT
ORDER BY Avg_Taxi_Out_Time DESC
LIMIT 10;

/*Several airports—led by GFK—show unusually long average taxi-out times, 
indicating ground operations are a significant hidden contributor to overall departure delays.*/



#Business Problem: Which specific routes are "high-risk" (frequent delays > 60 minutes)? 
#SQL Goal: Identify routes where more than 10% of flights are severely delayed.

SELECT 
    ORIGIN_AIRPORT, DESTINATION_AIRPORT,
    SUM(CASE WHEN ARRIVAL_DELAY > 60 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS Severe_Delay_Risk_Pct
FROM flights
GROUP BY ORIGIN_AIRPORT, DESTINATION_AIRPORT
HAVING COUNT(*) > 50
ORDER BY Severe_Delay_Risk_Pct DESC;

/*The LAS–LAX and LAX–LAS routes stand out as high-risk corridors, 
with the highest share of flights experiencing severe (>60-minute) delays compared to other major routes.*/



#Business Problem: Which aircraft (Tail Numbers) are flying the most distance, and are they more prone to maintenance delays? 
#SQL Goal: Calculate total distance flown and average AIRLINE_DELAY (maintenance) per aircraft.

SELECT 
    TAIL_NUMBER,
    SUM(DISTANCE) AS Total_Distance,
    AVG(AIRLINE_DELAY) AS Avg_Maintenance_Delay
FROM flights
WHERE TAIL_NUMBER IS NOT NULL
GROUP BY TAIL_NUMBER
HAVING SUM(DISTANCE) > 10000
ORDER BY Total_Distance DESC;

/*High-utilization aircraft log the greatest total distance, but maintenance-related delays vary widely, 
indicating that heavy usage alone does not consistently translate into higher maintenance delay risk.*/
