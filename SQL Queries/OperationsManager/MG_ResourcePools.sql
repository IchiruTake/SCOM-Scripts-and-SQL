﻿SET NOCOUNT ON
DECLARE 
       @Statement nvarchar(max)
      ,@MicrosoftSystemCenterManagementService nvarchar(255)
      ,@ManagementService_HealthServiceId nvarchar(255)
      ,@BaseManagedEntityDisplayName nvarchar(255)
      
    SELECT @MicrosoftSystemCenterManagementService = ManagedTypeViewName
    FROM dbo.ManagedType
    WHERE (ManagedTypeId = dbo.fn_ManagedTypeId_MicrosoftSystemCenterManagementService())
    PRINT @MicrosoftSystemCenterManagementService
    
    SELECT @ManagementService_HealthServiceId = ColumnName
    FROM dbo.ManagedTypeProperty
    WHERE (ManagedTypeId = dbo.fn_ManagedTypeId_MicrosoftSystemCenterManagementService())
    AND (ManagedTypePropertyId = dbo.fn_ManagedTypePropertyId_MicrosoftSystemCenterManagementService_HealthServiceId())
    PRINT @ManagementService_HealthServiceId
   
    SELECT @BaseManagedEntityDisplayName = S.COLUMN_NAME 
    FROM INFORMATION_SCHEMA.COLUMNS AS S
    WHERE S.TABLE_NAME COLLATE DATABASE_DEFAULT IN
    (SELECT ManagedTypeViewName AS [TABLE_NAME] FROM dbo.ManagedType) 
    AND  S.TABLE_NAME = @MicrosoftSystemCenterManagementService
    AND S.COLUMN_NAME like 'DisplayName%'
    PRINT @BaseManagedEntityDisplayName 
 
    IF (OBJECT_ID('tempdb..#PoolMember') IS NOT NULL)
    DROP TABLE #PoolMember
    CREATE TABLE #PoolMember (
      
ManagementServiceId       uniqueidentifier  NOT NULL
      ,HealthServiceId          uniqueidentifier  NULL
      ,ResourcePool             varchar(255) 
      ,Member                   varchar(255) 
    )
      
    set  @Statement = '
      INSERT #PoolMember (
        ManagementServiceId
        ,HealthServiceId
        ,ResourcePool
        ,Member
      )
      SELECT 
        TargetEntityId
        ,' + QUOTENAME(@ManagementService_HealthServiceId) + '
        ,BME.DisplayName AS ResourcePool
        ,[MS].' + QUOTENAME(@BaseManagedEntityDisplayName) + ' AS Member 
      FROM dbo.Relationship R
              JOIN ' + QUOTENAME(@MicrosoftSystemCenterManagementService) + ' MS ON (R.TargetEntityId = MS.BaseManagedEntityId)
              JOIN BaseManagedEntity BME ON BME.BaseManagedEntityId = R.SourceEntityId 
      WHERE (RelationshipTypeId = dbo.fn_ManagedTypeId_MicrosoftSystemCenterManagementServicePoolContainsManagementService())
        AND (R.IsDeleted = 0) AND (BME.IsDeleted = 0)'
    
  Print @Statement    
  Exec (@Statement)

Select 
  ResourcePool, 
  Member 
  from #PoolMember
  Order By ResourcePool ASC