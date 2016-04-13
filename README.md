# rsDBEntryDSC

A DSC resource that governs SQL database entries

Example:
```powershell
Configuration DBConfig {
  Node "localhost" {
    rsDBEntry WebServer01 {
      KeyColumn = "ServerName"
      Ensure = "Present"
      ConnectionString = "Server=SQLSERVER\INSTANCE;Database=DB01;Trusted_Connection=True;"
      Table = "Servers"
      Data = @{"IP"="0.0.0.0";"Port"=80} # "ServerName" = "WebServer01" will be added automatically
    }
  }
}
```
