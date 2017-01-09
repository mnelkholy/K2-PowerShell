# Make sure account running has impersonate rights on the K2 server and also database permissions to the K2 database.
# SQL queries are for default database name of K2
$k2server = "localhost"
$k2serverport = 5555
$sqlConnectionString = "Server=dlx;Database=K2;Integrated Security=True"
 
 
Write-Host  "Expiring Identity Cache for Groups"
# Open SQL connection to K2 database
$sqlconn = New-Object System.Data.SqlClient.SqlConnection
$sqlconn.ConnectionString = $sqlConnectionString
$sqlconn.Open()
 
# Expire the cache for all groups.  Type = 3.
$script = "UPDATE [K2].[Identity].[Identity] SET [ExpireOn] = GETDATE() 
,[Resolved] = 0 
,[ContainersResolved] = 0 
,[ContainersExpireOn] = GETDATE() 
,[MembersResolved] = 0 
,[MembersExpireOn] = GETDATE() 
WHERE [Type] =3 AND [Enabled] = 1"
$cmd1 = $sqlconn.CreateCommand()
$cmd1.CommandText = $script
$cmd1.ExecuteNonQuery()
 
# Get the group count
$script = "SELECT COUNT(*)  FROM [K2].[Identity].[Identity] NOLOCK WHERE [Type] =3 AND Resolved = 0 AND [Enabled] = 1"
$cmd1.CommandText = $script
$GroupCount = $cmd1.ExecuteScalar()
Write-Host  "No of Groups to Process: " $GroupCount
 
# Loop through the groups and call the UMUser SmartObject to force the refresh
$script = "SELECT Label, [Name] FROM [K2].[Identity].[Identity] NOLOCK WHERE [Type] =3 AND Resolved = 0 AND [Enabled] = 1"
$cmd1.CommandText = $script
$sqlReader = $cmd1.ExecuteReader()
 
# Build up SO connection string
Add-Type -AssemblyName ('SourceCode.HostClientAPI, Version=4.0.0.0, Culture=neutral, PublicKeyToken=16a2c5aaaa1b130d')
Add-Type -AssemblyName ('SourceCode.SmartObjects.Client, Version=4.0.0.0, Culture=neutral, PublicKeyToken=16a2c5aaaa1b130d')
 
$scbuilder = New-Object -TypeName SourceCode.Hosting.Client.BaseAPI.SCConnectionStringBuilder
$scbuilder.Host = $k2server
$scbuilder.Port = $k2serverport
$scbuilder.Integrated = $true
$scbuilder.IsPrimaryLogin = $true
 
$smoServer = New-Object -TypeName SourceCode.SmartObjects.Client.SmartObjectClientServer
$smoServer.CreateConnection()
$smoServer.Connection.Open($scbuilder.ConnectionString)
 
# instantiate UMUser SmartObject
$umUser = $smoServer.GetSmartObject("UMUser")
$slm = $umUser.ListMethods["Get_Group_Users"]
$umUser.MethodToExecute = $slm.Name
 
$counter = 0
while($sqlReader.Read())
{
    $counter++
    # call UMUser SmartObject
    $slm.Parameters["LabelName"].Value = $sqlReader["Label"]
    $slm.Parameters["Group_name"].Value = $sqlReader["Name"]
    $startTime = Get-Date
    $dt = $smoServer.ExecuteListDataTable($umUser)
    $endTime = Get-Date
 
    Write-Host "Updated Group "$counter" of "$GroupCount". Group Name:" $sqlReader["Label"]":"$sqlReader["Name"]". Time taken "$(New-TimeSpan $startTime $endTime).TotalMilliseconds" ms."
}
 
$sqlconn.Close()
$smoServer.Connection.Close();
