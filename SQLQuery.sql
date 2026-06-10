
/* validate the importing and source data */

select Top 10 * from dbo.Booking_Source;
select Top 10 * from dbo.Customer_Source;
select Top 10 * from dbo.Market_Source;
select Top 10 * from dbo.Meal_Source;
select Top 10 * from dbo.Room_Source;

/* creating staging tables */

CREATE TABLE [dbo].[StgBooking_Source](
	[hotel] [nvarchar](50) ,
	[is_canceled] [bit] ,
	[lead_time] [smallint] ,
	[arrival_date_year] [smallint] ,
	[arrival_date_month] [nvarchar](50) ,
	[arrival_date_week_number] [tinyint] ,
	[arrival_date_day_of_month] [tinyint] ,
	[stays_in_weekend_nights] [tinyint] ,
	[stays_in_week_nights] [tinyint] ,
	[adr] [float] ,
	[reservation_status] [nvarchar](50) ,
	[reservation_status_date] [date] 
)

CREATE TABLE [dbo].[StgCustomer_Source](
	[adults] [tinyint] ,
	[children] [tinyint] ,
	[babies] [tinyint] ,
	[country] [nvarchar](50) ,
	[customer_type] [nvarchar](50) ,
	[is_repeated_guest] [tinyint] ,
	[previous_cancellations] [tinyint] ,
	[previous_bookings_not_canceled] [tinyint] 
)

CREATE TABLE [dbo].[StgMarket_Source](
	[market_segment] [nvarchar](50) ,
	[distribution_channel] [nvarchar](50) ,
	[agent] [smallint] ,
	[company] [nvarchar](50) 
) 

CREATE TABLE [dbo].[StgMeal_Source](
	[deposit_type] [nvarchar](50) ,
	[total_of_special_requests] [tinyint] ,
	[days_in_waiting_list] [smallint] 
)

CREATE TABLE [dbo].[StgRoom_Source](
	[reserved_room_type] [nvarchar](50),
	[assigned_room_type] [nvarchar](50),
	[booking_changes] [tinyint] ,
	[required_car_parking_spaces] [tinyint]
) 

/*Transfer data from source to staging*/

Insert into HotelReservation_Staging.dbo.StgBooking_Source
select * from HotelReservation_Source.dbo.Booking_Source

Insert into HotelReservation_Staging.dbo.StgCustomer_Source
select * from HotelReservation_Source.dbo.Customer_Source

Insert into HotelReservation_Staging.dbo.StgMarket_Source
select * from HotelReservation_Source.dbo.Market_Source

Insert into HotelReservation_Staging.dbo.StgMeal_Source
select * from HotelReservation_Source.dbo.Meal_Source

Insert into HotelReservation_Staging.dbo.StgRoom_Source
select * from HotelReservation_Source.dbo.Room_Source

/*Verify the data was moved */

select count(*) from HotelReservation_Staging.dbo.StgBooking_Source;
select count(*) from HotelReservation_Source.dbo.Booking_Source;

select count(*) from HotelReservation_Staging.dbo.StgCustomer_Source;
select count(*) from HotelReservation_Source.dbo.Customer_Source;

select count(*) from HotelReservation_Staging.dbo.StgMarket_Source;
select count(*) from HotelReservation_Source.dbo.Market_Source;

select count(*) from HotelReservation_Staging.dbo.StgMeal_Source;
select count(*) from HotelReservation_Source.dbo.Meal_Source;

select count(*) from HotelReservation_Staging.dbo.StgRoom_Source;
select count(*) from HotelReservation_Source.dbo.Room_Source;


USE HotelBookingDW;

/* CReating Dimensions and Fact Tabls */

/* Date Dim */

BEGIN TRY
	DROP TABLE [dbo].[Dim_Date]
END TRY

BEGIN CATCH
	/*No Action*/
END CATCH

/**********************************************************************************/

CREATE TABLE	[dbo].[Dim_Date]
	(	[DateKey] INT primary key, 
		[Date] DATETIME,
		[FullDateUK] CHAR(10), -- Date in dd-MM-yyyy format
		[FullDateUSA] CHAR(10),-- Date in MM-dd-yyyy format
		[DayOfMonth] VARCHAR(2), -- Field will hold day number of Month
		[DaySuffix] VARCHAR(4), -- Apply suffix as 1st, 2nd ,3rd etc
		[DayName] VARCHAR(9), -- Contains name of the day, Sunday, Monday 
		[DayOfWeekUSA] CHAR(1),-- First Day Sunday=1 and Saturday=7
		[DayOfWeekUK] CHAR(1),-- First Day Monday=1 and Sunday=7
		[DayOfWeekInMonth] VARCHAR(2), --1st Monday or 2nd Monday in Month
		[DayOfWeekInYear] VARCHAR(2),
		[DayOfQuarter] VARCHAR(3),
		[DayOfYear] VARCHAR(3),
		[WeekOfMonth] VARCHAR(1),-- Week Number of Month 
		[WeekOfQuarter] VARCHAR(2), --Week Number of the Quarter
		[WeekOfYear] VARCHAR(2),--Week Number of the Year
		[Month] VARCHAR(2), --Number of the Month 1 to 12
		[MonthName] VARCHAR(9),--January, February etc
		[MonthOfQuarter] VARCHAR(2),-- Month Number belongs to Quarter
		[Quarter] CHAR(1),
		[QuarterName] VARCHAR(9),--First,Second..
		[Year] CHAR(4),-- Year value of Date stored in Row
		[YearName] CHAR(7), --CY 2012,CY 2013
		[MonthYear] CHAR(10), --Jan-2013,Feb-2013
		[MMYYYY] CHAR(6),
		[FirstDayOfMonth] DATE,
		[LastDayOfMonth] DATE,
		[FirstDayOfQuarter] DATE,
		[LastDayOfQuarter] DATE,
		[FirstDayOfYear] DATE,
		[LastDayOfYear] DATE,
		[IsHolidaySL] BIT,-- Flag 1=National Holiday, 0-No National Holiday
		[IsWeekday] BIT,-- 0=Week End ,1=Week Day
		[HolidaySL] VARCHAR(50),--Name of Holiday in US
		[isCurrentDay] int, -- Current day=1 else = 0
		[isDataAvailable] int, -- data available for the day = 1, no data available for the day = 0
		[isLatestDataAvailable] int
	)
GO


/********************************************************************************************/
--Specify Start Date and End date here
--Value of Start Date Must be Less than Your End Date 

DECLARE @StartDate DATETIME = '01/01/1990' --Starting value of Date Range
DECLARE @EndDate DATETIME = '01/01/2099' --End Value of Date Range

--Temporary Variables To Hold the Values During Processing of Each Date of Year
DECLARE
	@DayOfWeekInMonth INT,
	@DayOfWeekInYear INT,
	@DayOfQuarter INT,
	@WeekOfMonth INT,
	@CurrentYear INT,
	@CurrentMonth INT,
	@CurrentQuarter INT

/*Table Data type to store the day of week count for the month and year*/
DECLARE @DayOfWeek TABLE (DOW INT, MonthCount INT, QuarterCount INT, YearCount INT)

INSERT INTO @DayOfWeek VALUES (1, 0, 0, 0)
INSERT INTO @DayOfWeek VALUES (2, 0, 0, 0)
INSERT INTO @DayOfWeek VALUES (3, 0, 0, 0)
INSERT INTO @DayOfWeek VALUES (4, 0, 0, 0)
INSERT INTO @DayOfWeek VALUES (5, 0, 0, 0)
INSERT INTO @DayOfWeek VALUES (6, 0, 0, 0)
INSERT INTO @DayOfWeek VALUES (7, 0, 0, 0)

--Extract and assign various parts of Values from Current Date to Variable

DECLARE @CurrentDate AS DATETIME = @StartDate
SET @CurrentMonth = DATEPART(MM, @CurrentDate)
SET @CurrentYear = DATEPART(YY, @CurrentDate)
SET @CurrentQuarter = DATEPART(QQ, @CurrentDate)

/********************************************************************************************/
--Proceed only if Start Date(Current date ) is less than End date you specified above

WHILE @CurrentDate < @EndDate
BEGIN
 
/*Begin day of week logic*/

         /*Check for Change in Month of the Current date if Month changed then 
          Change variable value*/
	IF @CurrentMonth != DATEPART(MM, @CurrentDate) 
	BEGIN
		UPDATE @DayOfWeek
		SET MonthCount = 0
		SET @CurrentMonth = DATEPART(MM, @CurrentDate)
	END

        /* Check for Change in Quarter of the Current date if Quarter changed then change 
         Variable value*/

	IF @CurrentQuarter != DATEPART(QQ, @CurrentDate)
	BEGIN
		UPDATE @DayOfWeek
		SET QuarterCount = 0
		SET @CurrentQuarter = DATEPART(QQ, @CurrentDate)
	END
       
        /* Check for Change in Year of the Current date if Year changed then change 
         Variable value*/
	

	IF @CurrentYear != DATEPART(YY, @CurrentDate)
	BEGIN
		UPDATE @DayOfWeek
		SET YearCount = 0
		SET @CurrentYear = DATEPART(YY, @CurrentDate)
	END
	
        -- Set values in table data type created above from variables 

	UPDATE @DayOfWeek
	SET 
		MonthCount = MonthCount + 1,
		QuarterCount = QuarterCount + 1,
		YearCount = YearCount + 1
	WHERE DOW = DATEPART(DW, @CurrentDate)

	SELECT
		@DayOfWeekInMonth = MonthCount,
		@DayOfQuarter = QuarterCount,
		@DayOfWeekInYear = YearCount
	FROM @DayOfWeek
	WHERE DOW = DATEPART(DW, @CurrentDate)
	
/*End day of week logic*/


/* Populate Your Dimension Table with values*/
	
	INSERT INTO [dbo].[Dim_Date]
	SELECT
		
		CONVERT (char(8),@CurrentDate,112) as DateKey,
		@CurrentDate AS Date,
		CONVERT (char(10),@CurrentDate,103) as FullDateUK,
		CONVERT (char(10),@CurrentDate,101) as FullDateUSA,
		DATEPART(DD, @CurrentDate) AS DayOfMonth,
		--Apply Suffix values like 1st, 2nd 3rd etc..
		CASE 
			WHEN DATEPART(DD,@CurrentDate) IN (11,12,13) 
			THEN CAST(DATEPART(DD,@CurrentDate) AS VARCHAR) + 'th'
			WHEN RIGHT(DATEPART(DD,@CurrentDate),1) = 1 
			THEN CAST(DATEPART(DD,@CurrentDate) AS VARCHAR) + 'st'
			WHEN RIGHT(DATEPART(DD,@CurrentDate),1) = 2 
			THEN CAST(DATEPART(DD,@CurrentDate) AS VARCHAR) + 'nd'
			WHEN RIGHT(DATEPART(DD,@CurrentDate),1) = 3 
			THEN CAST(DATEPART(DD,@CurrentDate) AS VARCHAR) + 'rd'
			ELSE CAST(DATEPART(DD,@CurrentDate) AS VARCHAR) + 'th' 
			END AS DaySuffix,
		
		DATENAME(DW, @CurrentDate) AS DayName,
		DATEPART(DW, @CurrentDate) AS DayOfWeekUSA,

		-- check for day of week as Per US and change it as per UK format 
		CASE DATEPART(DW, @CurrentDate)
			WHEN 1 THEN 7
			WHEN 2 THEN 1
			WHEN 3 THEN 2
			WHEN 4 THEN 3
			WHEN 5 THEN 4
			WHEN 6 THEN 5
			WHEN 7 THEN 6
			END 
			AS DayOfWeekUK,
		
		@DayOfWeekInMonth AS DayOfWeekInMonth,
		@DayOfWeekInYear AS DayOfWeekInYear,
		@DayOfQuarter AS DayOfQuarter,
		DATEPART(DY, @CurrentDate) AS DayOfYear,
		DATEPART(WW, @CurrentDate) + 1 - DATEPART(WW, CONVERT(VARCHAR, 
		DATEPART(MM, @CurrentDate)) + '/1/' + CONVERT(VARCHAR, 
		DATEPART(YY, @CurrentDate))) AS WeekOfMonth,
		(DATEDIFF(DD, DATEADD(QQ, DATEDIFF(QQ, 0, @CurrentDate), 0), 
		@CurrentDate) / 7) + 1 AS WeekOfQuarter,
		DATEPART(WW, @CurrentDate) AS WeekOfYear,
		DATEPART(MM, @CurrentDate) AS Month,
		DATENAME(MM, @CurrentDate) AS MonthName,
		CASE
			WHEN DATEPART(MM, @CurrentDate) IN (1, 4, 7, 10) THEN 1
			WHEN DATEPART(MM, @CurrentDate) IN (2, 5, 8, 11) THEN 2
			WHEN DATEPART(MM, @CurrentDate) IN (3, 6, 9, 12) THEN 3
			END AS MonthOfQuarter,
		DATEPART(QQ, @CurrentDate) AS Quarter,
		CASE DATEPART(QQ, @CurrentDate)
			WHEN 1 THEN 'First'
			WHEN 2 THEN 'Second'
			WHEN 3 THEN 'Third'
			WHEN 4 THEN 'Fourth'
			END AS QuarterName,
		DATEPART(YEAR, @CurrentDate) AS Year,
		'CY ' + CONVERT(VARCHAR, DATEPART(YEAR, @CurrentDate)) AS YearName,
		LEFT(DATENAME(MM, @CurrentDate), 3) + '-' + CONVERT(VARCHAR, 
		DATEPART(YY, @CurrentDate)) AS MonthYear,
		RIGHT('0' + CONVERT(VARCHAR, DATEPART(MM, @CurrentDate)),2) + 
		CONVERT(VARCHAR, DATEPART(YY, @CurrentDate)) AS MMYYYY,
		CONVERT(DATETIME, CONVERT(DATE, DATEADD(DD, - (DATEPART(DD, 
		@CurrentDate) - 1), @CurrentDate))) AS FirstDayOfMonth,
		CONVERT(DATETIME, CONVERT(DATE, DATEADD(DD, - (DATEPART(DD, 
		(DATEADD(MM, 1, @CurrentDate)))), DATEADD(MM, 1, 
		@CurrentDate)))) AS LastDayOfMonth,
		DATEADD(QQ, DATEDIFF(QQ, 0, @CurrentDate), 0) AS FirstDayOfQuarter,
		DATEADD(QQ, DATEDIFF(QQ, -1, @CurrentDate), -1) AS LastDayOfQuarter,
		CONVERT(DATETIME, '01/01/' + CONVERT(VARCHAR, DATEPART(YY, 
		@CurrentDate))) AS FirstDayOfYear,
		CONVERT(DATETIME, '12/31/' + CONVERT(VARCHAR, DATEPART(YY, 
		@CurrentDate))) AS LastDayOfYear,
		NULL AS IsHolidaySL,
		CASE DATEPART(DW, @CurrentDate)
			WHEN 1 THEN 0
			WHEN 2 THEN 1
			WHEN 3 THEN 1
			WHEN 4 THEN 1
			WHEN 5 THEN 1
			WHEN 6 THEN 1
			WHEN 7 THEN 0
			END AS IsWeekday,
		NULL AS HolidaySL, (case when @CurrentDate = convert(date, sysdatetime()) then 1 else 0 end), 0, 0

	SET @CurrentDate = DATEADD(DD, 1, @CurrentDate)
END

/********************************************************************************************/
 
/*****************************************************************************************/

SELECT COUNT(*) FROM [dbo].[Dim_Date]

drop table Dim_Date


/* Dim Customer */

CREATE TABLE Dim_Customer (
    customer_key INT IDENTITY(1,1) PRIMARY KEY,
    customer_id INT,

    adults INT,
    children INT,
    babies INT,
    country VARCHAR(10),
    is_repeated_guest BIT,
    customer_type VARCHAR(50),

    -- SCD Type 2 columns
    start_date DATE,
    end_date DATE,
    is_current BIT
);



/* Dim Hotel */

CREATE TABLE Dim_Hotel (
    hotel_key INT IDENTITY(1,1) PRIMARY KEY,
    hotel_name VARCHAR(50)
);


/* Dim Market */
CREATE TABLE Dim_Market (
    market_key INT IDENTITY(1,1) PRIMARY KEY,
    market_id INT,

    market_segment VARCHAR(50),
    distribution_channel VARCHAR(50),
    agent INT,
    company INT,

    -- SCD Type 2
    start_date DATE,
    end_date DATE,
    is_current BIT
);


/*Dim Meal */

CREATE TABLE Dim_Meal (
    meal_key INT IDENTITY(1,1) PRIMARY KEY,
    meal_id INT,

    meal VARCHAR(50),
    deposit_type VARCHAR(50)
);

/* Dim Room */
CREATE TABLE Dim_Room (
    room_key INT IDENTITY(1,1) PRIMARY KEY,
    room_id INT,

    reserved_room_type VARCHAR(10),
    assigned_room_type VARCHAR(10),

    -- SCD Type 2
    start_date DATE,
    end_date DATE,
    is_current BIT
);


/* Reservation Status*/

CREATE TABLE Dim_Reservation_Status (
    status_key INT IDENTITY(1,1) PRIMARY KEY,
    reservation_status VARCHAR(50),
    is_canceled BIT
);


/* Fact Booking */

CREATE TABLE Fact_Booking (
    booking_key INT IDENTITY(1,1) PRIMARY KEY,

    DateKey INT,
    customer_key INT,
    hotel_key INT,
    market_key INT,
    meal_key INT,
    room_key INT,
    status_key INT,

    -- Measures
    lead_time INT,
    total_nights INT,
    adr DECIMAL(10,2),
    booking_changes INT,
    special_requests INT,

    -- Foreign Keys
    FOREIGN KEY (DateKey) REFERENCES Dim_Date(DateKey),
    FOREIGN KEY (customer_key) REFERENCES Dim_Customer(customer_key),
    FOREIGN KEY (hotel_key) REFERENCES Dim_Hotel(hotel_key),
    FOREIGN KEY (market_key) REFERENCES Dim_Market(market_key),
    FOREIGN KEY (meal_key) REFERENCES Dim_Meal(meal_key),
    FOREIGN KEY (room_key) REFERENCES Dim_Room(room_key),
    FOREIGN KEY (status_key) REFERENCES Dim_Reservation_Status(status_key)
);


/* Fact Calculation */
CREATE TABLE Fact_Cancellation (
    cancel_key INT IDENTITY(1,1) PRIMARY KEY,

    DateKey INT,
    customer_key INT,
    hotel_key INT,

    cancellation_flag BIT,
    lead_time INT,

    FOREIGN KEY (DateKey) REFERENCES Dim_Date(DateKey),
    FOREIGN KEY (customer_key) REFERENCES Dim_Customer(customer_key),
    FOREIGN KEY (hotel_key) REFERENCES Dim_Hotel(hotel_key)
);

/*Truncate table */
TRUNCAtE TABLE dbo.StgBooking_Source;
TRUNCATE TABLE dbo.StgCustomer_Source;
TRUNCATE TABLE dbo.StgMarket_Source;
TRUNCATE TABLE dbo.StgMeal_Source;
TRUNCATE TABLE dbo.StgRoom_Source;

/*check if dim date loded*/
SELECT COUNT(*) FROM dbo.Dim_Date;



/* Transform and LOad DimCustomer */

CREATE PROCEDURE dbo.UpdateDimCustomer
    @customer_id INT,
    @adults INT,
    @children INT,
    @babies INT,
    @country VARCHAR(10),
    @customer_type VARCHAR(50),
    @is_repeated_guest BIT
AS
BEGIN

-- If same customer already exists and data is SAME → do nothing
IF EXISTS (
    SELECT 1 FROM Dim_Customer
    WHERE customer_id = @customer_id
    AND is_current = 1
    AND adults = @adults
    AND children = @children
    AND babies = @babies
    AND country = @country
    AND customer_type = @customer_type
    AND is_repeated_guest = @is_repeated_guest
)
RETURN;

-- If exists but data CHANGED → close old record
IF EXISTS (
    SELECT 1 FROM Dim_Customer
    WHERE customer_id = @customer_id
    AND is_current = 1
)
BEGIN
    UPDATE Dim_Customer
    SET end_date = GETDATE(),
        is_current = 0
    WHERE customer_id = @customer_id
    AND is_current = 1;
END

-- Insert new record
INSERT INTO Dim_Customer (
    customer_id,
    adults,
    children,
    babies,
    country,
    customer_type,
    is_repeated_guest,
    start_date,
    end_date,
    is_current
)
VALUES (
    @customer_id,
    @adults,
    @children,
    @babies,
    @country,
    @customer_type,
    @is_repeated_guest,
    GETDATE(),
    NULL,
    1
);

END;

/*Transform and load DimMarket*/

CREATE OR ALTER PROCEDURE dbo.UpdateDimMarket
    @market_id INT,
    @market_segment VARCHAR(50),
    @distribution_channel VARCHAR(50),
    @agent INT,
    @company INT
AS
BEGIN
    SET NOCOUNT ON;

    -- If exact current record already exists, do nothing
    IF EXISTS (
        SELECT 1
        FROM Dim_Market
        WHERE market_id = @market_id
          AND market_segment = @market_segment
          AND distribution_channel = @distribution_channel
          AND ISNULL(agent, 0) = ISNULL(@agent, 0)
          AND ISNULL(company, 0) = ISNULL(@company, 0)
          AND is_current = 1
    )
        RETURN;

    -- If same business key exists but attributes changed, expire current row
    IF EXISTS (
        SELECT 1
        FROM Dim_Market
        WHERE market_id = @market_id
          AND is_current = 1
    )
    BEGIN
        UPDATE Dim_Market
        SET end_date = GETDATE(),
            is_current = 0
        WHERE market_id = @market_id
          AND is_current = 1;
    END

    -- Insert new current row
    INSERT INTO Dim_Market
    (
        market_id,
        market_segment,
        distribution_channel,
        agent,
        company,
        start_date,
        end_date,
        is_current
    )
    VALUES
    (
        @market_id,
        @market_segment,
        @distribution_channel,
        @agent,
        @company,
        GETDATE(),
        NULL,
        1
    );
END;

/* Transform and load DimRoom*/

CREATE OR ALTER PROCEDURE dbo.UpdateDimRoom
    @room_id INT,
    @reserved_room_type VARCHAR(10),
    @assigned_room_type VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    -- If same current row already exists, do nothing
    IF EXISTS (
        SELECT 1
        FROM Dim_Room
        WHERE room_id = @room_id
          AND reserved_room_type = @reserved_room_type
          AND assigned_room_type = @assigned_room_type
          AND is_current = 1
    )
        RETURN;

    -- If same business key exists but changed, expire old row
    IF EXISTS (
        SELECT 1
        FROM Dim_Room
        WHERE room_id = @room_id
          AND is_current = 1
    )
    BEGIN
        UPDATE Dim_Room
        SET end_date = GETDATE(),
            is_current = 0
        WHERE room_id = @room_id
          AND is_current = 1;
    END

    -- Insert new row
    INSERT INTO Dim_Room
    (
        room_id,
        reserved_room_type,
        assigned_room_type,
        start_date,
        end_date,
        is_current
    )
    VALUES
    (
        @room_id,
        @reserved_room_type,
        @assigned_room_type,
        GETDATE(),
        NULL,
        1
    );
END;

/* Verify DimCustomer Transformation & loading */

SELECT * FROM Dim_Customer

/* Verify DimMeal Transformation & loading */

SELECT * FROM Dim_Meal

/* Verify DimMeal Transformation & loading */

SELECT * FROM Dim_Hotel

/* Verify DimMarket Transformation & loading */

SELECT * FROM Dim_Market


/* Verify DimRoom Transformation & loading */

SELECT * FROM Dim_Room

/* Verify DimReservation_Status Transformation & loading */

SELECT * FROM Dim_Reservation_Status;

/* Verify Fact_booking Transformation & loading */

SELECT TOP 20 * FROM Fact_Booking;

SELECT COUNT(*) AS FactBookingCount
FROM Fact_Booking;

/* Verify Fact_cancellation Transformation & loading */

SELECT TOP 20 * FROM Fact_Cancellation;


SELECT COUNT(*) AS FactCancellationCount
FROM Fact_Cancellation;


/*fix booking*/
WITH B AS
(
    SELECT 
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn,
        hotel,
        lead_time,
        arrival_date_year,
        arrival_date_month,
        arrival_date_day_of_month,
        stays_in_weekend_nights,
        stays_in_week_nights,
        adr,
        reservation_status,
        reservation_status_date,
        is_canceled
    FROM dbo.StgBooking_Source
),
C AS
(
    SELECT 
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn,
        CAST(adults AS INT) AS adults,
        CAST(children AS INT) AS children,
        CAST(babies AS INT) AS babies,
        country,
        customer_type,
        CAST(is_repeated_guest AS INT) AS is_repeated_guest
    FROM dbo.StgCustomer_Source
),
M AS
(
    SELECT 
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn,
        market_segment,
        distribution_channel,
        CAST(ISNULL(agent,0) AS INT) AS agent,
        CASE 
            WHEN company IS NULL OR LTRIM(RTRIM(company)) = '' THEN 0
            WHEN ISNUMERIC(company) = 1 THEN CAST(company AS INT)
            ELSE 0
        END AS company
    FROM dbo.StgMarket_Source
),
ME AS
(
    SELECT 
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn,
        deposit_type,
        CAST(total_of_special_requests AS INT) AS total_of_special_requests
    FROM dbo.StgMeal_Source
),
R AS
(
    SELECT 
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn,
        reserved_room_type,
        assigned_room_type,
        CAST(booking_changes AS INT) AS booking_changes
    FROM dbo.StgRoom_Source
)
SELECT
    CAST(CONVERT(CHAR(8), B.reservation_status_date, 112) AS INT) AS DateKey,
    B.hotel,
    CAST(B.lead_time AS INT) AS lead_time,
    CAST(ISNULL(B.stays_in_weekend_nights,0) + ISNULL(B.stays_in_week_nights,0) AS INT) AS total_nights,
    CAST(ISNULL(B.adr,0) AS DECIMAL(10,2)) AS adr,
    B.reservation_status,
    CAST(B.is_canceled AS INT) AS is_canceled,

    C.adults,
    C.children,
    C.babies,
    C.country,
    C.customer_type,
    C.is_repeated_guest,

    M.market_segment,
    M.distribution_channel,
    M.agent,
    M.company,

    'UNKNOWN' AS meal,
    ME.deposit_type,
    ME.total_of_special_requests,

    R.reserved_room_type,
    R.assigned_room_type,
    R.booking_changes

FROM B
LEFT JOIN C  ON B.rn = C.rn
LEFT JOIN M  ON B.rn = M.rn
LEFT JOIN ME ON B.rn = ME.rn
LEFT JOIN R  ON B.rn = R.rn;


/*Extend Fact Booking */
ALTER TABLE Fact_Booking
ADD booking_nk INT,
    accm_txn_create_time DATETIME NULL,
    accm_txn_complete_time DATETIME NULL,
    txn_process_time_hours INT NULL;

/*populate Booking_nk and create time */

UPDATE Fact_Booking
SET 
    booking_nk = booking_key,
    accm_txn_create_time = GETDATE()
WHERE booking_nk IS NULL;

/* verify the new columns */
SELECT TOP 20
    booking_key,
    booking_nk,
    accm_txn_create_time,
    accm_txn_complete_time,
    txn_process_time_hours
FROM Fact_Booking;





CREATE OR ALTER PROCEDURE dbo.UpdateFactBookingCompletion
    @accm_txn_complete_time DATETIME,
    @booking_nk INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Fact_Booking
    SET 
        accm_txn_complete_time = @accm_txn_complete_time,
        txn_process_time_hours = DATEDIFF(HOUR, accm_txn_create_time, @accm_txn_complete_time)
    WHERE booking_nk = @booking_nk;
END;



EXEC dbo.UpdateFactBookingCompletion '2026-03-30 10:00:00', 1;


/* Validation 1 */

SELECT TOP 20
    booking_key,
    booking_nk,
    accm_txn_create_time,
    accm_txn_complete_time,
    txn_process_time_hours
FROM Fact_Booking;


/* Validation 2 */

SELECT
    booking_nk,
    accm_txn_create_time,
    accm_txn_complete_time,
    txn_process_time_hours
FROM Fact_Booking
WHERE accm_txn_complete_time IS NOT NULL
ORDER BY booking_nk;


/* 3*/

SELECT
    booking_nk,
    accm_txn_create_time,
    accm_txn_complete_time,
    DATEDIFF(HOUR, accm_txn_create_time, accm_txn_complete_time) AS expected_hours,
    txn_process_time_hours
FROM Fact_Booking
WHERE accm_txn_complete_time IS NOT NULL;

/* 4 */

SELECT COUNT(*) AS UpdatedRows
FROM Fact_Booking
WHERE accm_txn_complete_time IS NOT NULL;


SELECT COUNT(*) AS RemainingIncompleteRows
FROM Fact_Booking
WHERE accm_txn_complete_time IS NULL;



select @@VERSION;