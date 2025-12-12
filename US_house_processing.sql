--House_ID
CREATE PROCEDURE Add_House_ID
AS
BEGIN
    ALTER TABLE [dbo].[Zillow_table]
    ADD House_ID VARCHAR(50);
END

EXEC Add_House_ID

CREATE PROCEDURE Update_House_ID
AS
BEGIN
    UPDATE [dbo].[Zillow_table]
    SET House_ID =	RIGHT(
						LEFT(Links, CHARINDEX('_zpid', Links) - 1), 
						CHARINDEX('/', 
							REVERSE(
								LEFT(Links, CHARINDEX('_zpid', Links) - 1)
							)
						) - 1
					);
END

EXEC Update_House_ID

--duplicate
CREATE PROCEDURE Delete_Duplicates
AS
BEGIN
    WITH CTE_Duplicates AS (
        SELECT *, 
			   ROW_NUMBER() OVER (
					PARTITION BY House_ID
					ORDER BY (SELECT NULL)
				) AS rn
        FROM [dbo].[Zillow_table]
    )
    DELETE FROM CTE_Duplicates 
    WHERE rn > 1;
END

EXEC Delete_Duplicates


--Address
CREATE PROCEDURE Create_Adr
AS
BEGIN
	ALTER TABLE [dbo].[Zillow_table]
	ADD Street_adr	NVARCHAR(255),
		City_adr	NVARCHAR(255),
		State_adr	NVARCHAR(50),
		Zip_Code	NVARCHAR(10);
END

EXEC Create_Adr

CREATE PROCEDURE Update_adr
AS
BEGIN
    UPDATE [dbo].[Zillow_table]
    SET 
        -- Street
        Street_adr = CASE 
						WHEN CHARINDEX(',', Address) > 0 
						THEN LEFT(Address, CHARINDEX(',', Address) - 1) 
						ELSE Address 
					 END,

        -- City
        City_adr =	CASE 
						WHEN CHARINDEX(',', Address) > 0 
							 AND CHARINDEX(',', Address, CHARINDEX(',', Address) + 1) > 0 
						THEN LTRIM(
								SUBSTRING(
									Address, 
									CHARINDEX(',', Address) + 1, 
									CHARINDEX(',', Address, CHARINDEX(',', Address) + 1) - CHARINDEX(',', Address) - 1
								)
							 ) 
						ELSE NULL 
					END,

        -- State
        State_adr = CASE 
						WHEN CHARINDEX(',', Address, CHARINDEX(',', Address) + 1) > 0 
						THEN LTRIM(
								SUBSTRING(
									Address, 
									CHARINDEX(',', Address, CHARINDEX(',', Address) + 1) + 1,
									3
								)
							 ) 
						ELSE NULL 
					END,

        --  Zip Code
        Zip_Code = CASE 
                      WHEN LEN(Address) >= 5 
                      THEN RIGHT(Address, 5) 
                      ELSE NULL 
                   END;
END;

EXEC Update_adr

--Detail
--
CREATE PROCEDURE Create_details
AS
BEGIN
    ALTER TABLE [dbo].[Zillow_table]
    ADD Bedrooms		INT,
        Bathrooms		INT,
        Square_Footage	INT;
END

EXEC Create_details

--
CREATE PROCEDURE Update_Details
AS
BEGIN
    UPDATE [dbo].[Zillow_table]
    SET 
        --Bedrooms
        Bedrooms =	CASE 
						WHEN (CHARINDEX(' bds', Details) > 0 OR CHARINDEX(' bd', Details) > 0) 
							 AND ISNUMERIC(LEFT(Details, CHARINDEX(' ', Details) - 1)) = 1
						THEN TRY_CAST(
								LTRIM(RTRIM(
										LEFT(Details, CHARINDEX(' ', Details) - 1)
									  )
								) AS INT
							 )
						ELSE 
							CASE 
								WHEN CHARINDEX(' ba', Details) > 0 
										AND LEFT(Details, CHARINDEX(' ba', Details) - 1) LIKE '%Studio%' 
								THEN 0
								ELSE NULL
							END
						END,

        -- Bathrooms
        Bathrooms = CASE 
						WHEN CHARINDEX(' ba', Details) > 0 
						THEN TRY_CAST(
								SUBSTRING(
									Details, 
									CHARINDEX(' ba', Details) - 1, 
									1
								) AS INT
							 )
						ELSE NULL 
					END,

        -- Square Footage
        Square_Footage = CASE 
							WHEN CHARINDEX('sqft', Details) > 0 
								 AND CHARINDEX(' ba', Details) > 0 
							THEN 
								CASE 
									WHEN SUBSTRING(
											Details, 
											CHARINDEX(' ba', Details) + 3, 
											LEN(Details)
										 ) LIKE '%--%' 
									THEN NULL
									ELSE TRY_CAST(
											REPLACE(	
												LTRIM(RTRIM(
														SUBSTRING(
															Details, 
															CHARINDEX(' ba', Details) + 3, 
															CHARINDEX('sqft', Details) - CHARINDEX(' ba', Details) - 3
														)
												)),
												',', 
												''
											) AS INT
										 )
								END
							ELSE NULL 
						 END
    WHERE 
        Details IS NOT NULL;
END;

EXEC Update_Details


--Price
CREATE PROCEDURE Update_Price
AS
BEGIN
    UPDATE [dbo].[Zillow_table]
    SET Price = CASE
					WHEN CHARINDEX('.', Price) > 0 
						 OR CHARINDEX('--', Price) > 0 
					THEN NULL                            
					ELSE REPLACE(
							REPLACE(
								REPLACE(
									REPLACE(
										REPLACE(
											Price, 
											'$', ''
										),
										',', ''
									),
									'K', '000'
								),
								'+', ''
							),
							'--', ''
						)								
				END;

    ALTER TABLE [dbo].[Zillow_table]
    ALTER COLUMN Price INT;
END;

EXEC Update_Price

--Null
CREATE PROCEDURE Delete_Null
AS
BEGIN
    DELETE FROM [dbo].[Zillow_table]
    WHERE Price			  IS NULL
	   OR House_ID		 IS NULL
       OR Street_adr	 IS NULL
       OR City_adr		 IS NULL
       OR State_adr		 IS NULL
       OR Zip_Code		 IS NULL
       OR Bedrooms		 IS NULL
       OR Bathrooms		 IS NULL
       OR Square_Footage IS NULL; 
END;

EXEC Delete_Null