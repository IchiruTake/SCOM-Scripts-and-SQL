SELECT 
  ManagedTypePropertyName, 
  SettingValue, 
  mtv.DisplayName, 
  gs.LastModified 
FROM 
  GlobalSettings gs 
  INNER JOIN ManagedTypeProperty mtp on gs.ManagedTypePropertyId = mtp.ManagedTypePropertyId 
  INNER JOIN ManagedTypeView mtv on mtp.ManagedTypeId = mtv.Id 
ORDER BY 
  mtv.DisplayName