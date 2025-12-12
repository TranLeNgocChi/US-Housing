ALTER TABLE Thao_2_Zillow_table_backup
ADD House_ID NVARCHAR(20);

CREATE PROCEDURE UpHID
AS
BEGIN
    DECLARE @base_url VARCHAR(100) = 'https://www.zillow.com/homedetails/';
    
    -- House ID
    UPDATE Thao_2_Zillow_table_backup
    SET House_ID = SUBSTRING(Links, 
                              CHARINDEX('/', Links, LEN(@base_url) + 1) + 1,
                              CHARINDEX('_zpid', Links) - CHARINDEX('/', Links, LEN(@base_url) + 1) - 1)
    WHERE CHARINDEX('_zpid', Links) > 0;
END;

EXEC UpHID;

--delete duplicate
CREATE PROCEDURE RemoveDupHID1
AS
BEGIN
    SELECT House_ID, COUNT(*) as count
    FROM Thao_2_Zillow_table_backup
    GROUP BY House_ID
    HAVING COUNT(*) > 1;

    SELECT 
        COUNT(*) as total_rows,
        COUNT(DISTINCT House_ID) as house_ids,
        (SELECT SUM(duplicate_count - 1)
         FROM (
             SELECT COUNT(*) as duplicate_count
             FROM Thao_2_Zillow_table_backup
             GROUP BY House_ID
             HAVING COUNT(*) > 1
         ) t) as extra_duplicates
    FROM Thao_2_Zillow_table_backup;

    WITH DuplicateCTE AS (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY House_ID ORDER BY House_ID) as row_num
        FROM Thao_2_Zillow_table_backup
    )
    DELETE FROM DuplicateCTE 
    WHERE row_num > 1;

----Retype
    ALTER TABLE Thao_2_Zillow_table_backup
    ALTER COLUMN House_ID varchar(20) NOT NULL;
END;
EXEC RemoveDupHID1;


--split
ALTER TABLE Thao_2_Zillow_table_backup
    ADD House_address VARCHAR(255), 
        City VARCHAR(100), 
        House_state CHAR(2), 
        Zipcode CHAR(5),
        Bedrooms NVARCHAR(50),
        Bathrooms NVARCHAR(50),
        Area NVARCHAR(50);

CREATE PROCEDURE SplitAandR
AS
BEGIN
    
---address
    UPDATE Thao_2_Zillow_table_backup
    SET 
        House_address = CASE 
            WHEN CHARINDEX(',', [Address]) > 0 
            THEN SUBSTRING([Address], 1, CHARINDEX(',', [Address]) - 1) 
            ELSE NULL 
        END,
        
        City = CASE 
            WHEN LEN([Address]) - LEN(REPLACE([Address], ',', '')) >= 2 
            THEN SUBSTRING([Address], CHARINDEX(',', [Address]) + 2, 
                           CHARINDEX(',', [Address], CHARINDEX(',', [Address]) + 1) - CHARINDEX(',', [Address]) - 2) 
            ELSE NULL 
        END,
        
        House_state = CASE 
            WHEN LEN([Address]) - LEN(REPLACE([Address], ',', '')) >= 2 
            THEN SUBSTRING([Address], CHARINDEX(',', [Address], CHARINDEX(',', [Address]) + 1) + 2, 2) 
            ELSE NULL 
        END,
        
        Zipcode = CASE 
            WHEN LEN([Address]) >= 5 
            THEN RIGHT([Address], 5) 
            ELSE NULL 
        END;

---room
    UPDATE Thao_2_Zillow_table_backup
    SET 
        Bedrooms = CASE 
            WHEN CHARINDEX('bds', [Details]) > 0 
            THEN LEFT([Details], CHARINDEX('bds', [Details]) - 1) 
            ELSE NULL 
        END,
        
        Bathrooms = CASE 
            WHEN CHARINDEX('ba', [Details]) > 0 AND CHARINDEX('bds', [Details]) > 0 
            THEN SUBSTRING([Details], CHARINDEX('bds', [Details]) + 3, 
                           CHARINDEX('ba', [Details]) - CHARINDEX('bds', [Details]) - 3) 
            ELSE NULL 
        END,
        
        Area = CASE 
            WHEN CHARINDEX('sqft', [Details]) > 0 AND CHARINDEX('ba', [Details]) > 0 
            THEN REPLACE(SUBSTRING([Details], 
                     CHARINDEX('ba', [Details]) + 2, 
                     CHARINDEX('sqft', [Details]) - CHARINDEX('ba', [Details]) - 2), ',', ' ')
            ELSE NULL 
        END;
END;

EXEC SplitAandR;

--delete $
CREATE PROCEDURE Remove$
AS
BEGIN
    -- Cập nhật cột Price để xóa ký tự $ và dấu phẩy ,
    UPDATE Thao_2_Zillow_table_backup
    SET Price = REPLACE(REPLACE(Price, '$', ''), ',', '');
END;

EXEC Remove$;

CREATE PROCEDURE Clean
AS
BEGIN
--- delete null
    DECLARE @nnull NVARCHAR(MAX);
    SELECT @nnull = ISNULL(@nnull + ' OR ', '') + '[' + COLUMN_NAME + '] IS NULL'
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'Thao_2_Zillow_table_backup'; 
    
    SET @nnull = 'DELETE FROM [dbo].[Thao_2_Zillow_table_backup] WHERE ' + @nnull;
    EXEC sp_executesql @nnull;

 --- delete '--'
    DECLARE @nnull2 NVARCHAR(MAX);
    SELECT @nnull2 = ISNULL(@nnull2 + ' OR ', '') + '[' + COLUMN_NAME + '] LIKE ''%--%'''
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'Thao_2_Zillow_table_backup'; 
    
    SET @nnull2 = 'DELETE FROM [dbo].[Thao_2_Zillow_table_backup] WHERE ' + @nnull2;
    EXEC sp_executesql @nnull2;

 --- Not int
    DELETE FROM [dbo].[Thao_2_Zillow_table_backup]  
    WHERE 
        TRY_CAST(Bedrooms AS INT) IS NULL OR 
        TRY_CAST(Bathrooms AS INT) IS NULL OR 
        TRY_CAST(Price AS INT) IS NULL;  
END;
EXEC Clean;
--
CREATE PROCEDURE DataColumn1
AS
BEGIN
    ALTER TABLE [dbo].[Thao_2_Zillow_table_backup]
    DROP COLUMN [Address], [Details], [Links];

    -- data type
    ALTER TABLE [dbo].[Thao_2_Zillow_table_backup]
    ALTER COLUMN [Bedrooms] INT;

    ALTER TABLE [dbo].[Thao_2_Zillow_table_backup]
    ALTER COLUMN [Bathrooms] INT;

    ALTER TABLE [dbo].[Thao_2_Zillow_table_backup]
    ALTER COLUMN [Price] INT;
END;

EXEC DataColumn1;
