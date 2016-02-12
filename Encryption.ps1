# Modified from script generated by SQL Server Management Studio at 10:27 PM on 2/5/2016
[cmdletbinding()]
param(
	[string] $ConnectionString = "Server=DESKTOP-LKK3AHC\CTP2016_33;Integrated Security=SSPI;Initial Catalog=AlwaysEncryptedSample",
	[string] $ExtensionsApplicationLocation = 'C:\Program Files (x86)\Microsoft SQL Server\130\Tools\Binn\ManagementStudio\Extensions\Application\',
	[string] $DacLocation = 'C:\Program Files (x86)\Microsoft SQL Server\130\DAC\bin\',
	[string] $AuthSchema = 'Authentication',
	[string] $AppSchema = 'Purchasing',
	[string] $LoggingSchema = 'Logging',
	[string] $MasterKeyDNSName = "CN=Always Encrypted Sample Cert",
	[switch] $RemoveExistingCerts,
	[string] $MasterKeySQLName = "AlwaysEncryptedSampleCMK",
	[string] $AuthColumnKeyName = "AuthColumnsKey",
	[string] $AppColumnKeyName = "AppColumnsKey",
	[string] $LogColumnKeyName = "LogColumnsKey"
)

Function New-ColumnEncryptionKey {	
	param(
		[string] $MasterKeyName,
		[string] $ColumnKeyName
	)
	# Thanks to justdaveinfo for thie piece
	# https://justdaveinfo.wordpress.com/2015/10/15/always-on-encrypted-generating-certificates-and-column-encryption-key-encrypted_value/
	$cmkprov = New-Object System.Data.SqlClient.SqlColumnEncryptionCertificateStoreProvider
	$InBytes = New-Object Byte[] 32
	$OutBytes = New-Object Byte[] 32
	$RNG = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
	$RNG.GetBytes($InBytes,0,8)

	$OutBytes = $cmkprov.EncryptColumnEncryptionKey($cmkPath, "RSA_OAEP", $InBytes)
	$EncryptedValue = "0x" + [System.BitConverter]::ToString($OutBytes) -Replace '[-]',''

	$sql = @"
CREATE COLUMN ENCRYPTION KEY $($ColumnKeyName)
	WITH VALUES (
		COLUMN_MASTER_KEY = $($MasterKeyName), 
		ALGORITHM = 'RSA_OAEP', 
		ENCRYPTED_VALUE = $EncryptedValue
	);
"@
	Write-Verbose "Executing SQL: `n\$sql"
	$smoDatabase.ExecuteNonQuery($sql)
}

# Load reflected assemblies
{
	[reflection.assembly]::LoadwithPartialName('System.Data.SqlClient')
	[reflection.assembly]::LoadwithPartialName('Microsoft.SQLServer.SMO')
	[reflection.assembly]::LoadwithPartialName('Microsoft.SqlServer.ConnectionInfo')
	[reflection.assembly]::LoadwithPartialName('System.Security.Cryptography.X509Certificates')
	[reflection.assembly]::LoadFile($DacLocation + 'Microsoft.SqlServer.Dac.dll')
	[reflection.assembly]::LoadFile($DacLocation + 'Microsoft.SqlServer.Dac.Extensions.dll')
	[reflection.assembly]::LoadFile($DacLocation + 'Microsoft.Data.Tools.Utilities.dll')
	[reflection.assembly]::LoadFile($DacLocation + 'Microsoft.Data.Tools.Schema.Sql.dll')
	[reflection.assembly]::LoadFile($ExtensionsApplicationLocation + 'Microsoft.IdentityModel.Clients.ActiveDirectory.dll')
	[reflection.assembly]::LoadFile($ExtensionsApplicationLocation + 'Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll')
	[reflection.assembly]::LoadFile($ExtensionsApplicationLocation + 'Microsoft.SqlServer.Management.AzureAuthenticationManagement.dll')
	[reflection.assembly]::LoadFile($ExtensionsApplicationLocation + 'Microsoft.SqlServer.Management.AlwaysEncrypted.Management.dll')
	[reflection.assembly]::LoadFile($ExtensionsApplicationLocation + 'Microsoft.SqlServer.Management.AlwaysEncrypted.AzureKeyVaultProvider.dll')
	[reflection.assembly]::LoadFile($ExtensionsApplicationLocation + 'Microsoft.SqlServer.Management.AlwaysEncrypted.Types.dll')
}.Invoke() | Out-Null
# Set up connection and database SMO objects

try {
	$sqlConnection  = New-Object 'System.Data.SqlClient.SqlConnection' $ConnectionString 
	$smoServerConnection = New-Object 'Microsoft.SqlServer.Management.Common.ServerConnection' $sqlConnection
	$smoServer = New-Object 'Microsoft.SqlServer.Management.Smo.Server' $smoServerConnection
	$smoDatabase = $smoServer.Databases[$sqlConnection.Database]
}
catch {
	Write-Error $_
	break
}
if ($RemoveExistingCerts) {
	Write-Debug "Removing All Existing Certificates Named $($MasterKeyDNSName)"
	ls Cert:\CurrentUser\My |  where subject -eq $MasterKeyDNSName | rm
}
$cert = New-SelfSignedCertificate `
	-Subject $MasterKeyDNSName `
	-CertStoreLocation Cert:\CurrentUser\My `
	-Provider 'Microsoft Strong Cryptographic Provider' `
	-KeyUsage KeyEncipherment -TextExtension @(
		"2.5.29.37={text}1.3.6.1.5.5.8.2.2,1.3.6.1.4.1.311.10.3.11"
	)
$cmkPath = "CurrentUser/My/$($cert.ThumbPrint)"
Write-Verbose "Certificate Master Key Path: $($cmkPath)"

$sql = @"
CREATE COLUMN MASTER KEY $($MasterKeySQLName) 
	WITH (
		KEY_STORE_PROVIDER_NAME = 'MSSQL_CERTIFICATE_STORE',
		KEY_PATH = N'$($cmkPath)'
	);
"@
Write-Debug "Executing SQL `n$sql"
$smoDatabase.ExecuteNonQuery($sql);

New-ColumnEncryptionKey -MasterKeyName $MasterKeySQLName -ColumnKeyName $AuthColumnKeyName
New-ColumnEncryptionKey -MasterKeyName $MasterKeySQLName -ColumnKeyName $AppColumnKeyName
New-ColumnEncryptionKey -MasterKeyName $MasterKeySQLName -ColumnKeyName $LogColumnKeyName

#TODO: wrap below into Cmdlets up at the top.

# Change encryption schema
$AEAD_AES_256_CBC_HMAC_SHA_256 = 'AEAD_AES_256_CBC_HMAC_SHA_256'

# Change table [Authentication].[AspNetUsers]
$smoTable = $smoDatabase.Tables['AspNetUsers', $AuthSchema]
$encryptionChanges = New-Object 'Collections.Generic.List[Microsoft.SqlServer.Management.AlwaysEncrypted.Types.ColumnInfo]'
$encryptionChanges.Add($(New-Object 'Microsoft.SqlServer.Management.AlwaysEncrypted.Types.ColumnInfo' 'SSN', $(New-Object 'Microsoft.SqlServer.Management.AlwaysEncrypted.Types.EncryptionInfo' $AuthColumnKeyName, ([Microsoft.SqlServer.Management.AlwaysEncrypted.Types.EncryptionType]::Randomized), $AEAD_AES_256_CBC_HMAC_SHA_256)))
[Microsoft.SqlServer.Management.AlwaysEncrypted.Management.AlwaysEncryptedManagement]::SetColumnEncryptionSchema($ConnectionString, $smoDatabase, $smoTable, $encryptionChanges)

# Change table [Purchasing].[CreditCards]
$smoTable = $smoDatabase.Tables['CreditCards', $AppSchema]
$encryptionChanges = New-Object 'Collections.Generic.List[Microsoft.SqlServer.Management.AlwaysEncrypted.Types.ColumnInfo]'
$encryptionChanges.Add($(New-Object 'Microsoft.SqlServer.Management.AlwaysEncrypted.Types.ColumnInfo' 'CardNumber', $(New-Object 'Microsoft.SqlServer.Management.AlwaysEncrypted.Types.EncryptionInfo' $AppColumnKeyName, ([Microsoft.SqlServer.Management.AlwaysEncrypted.Types.EncryptionType]::Randomized), $AEAD_AES_256_CBC_HMAC_SHA_256)))
$encryptionChanges.Add($(New-Object 'Microsoft.SqlServer.Management.AlwaysEncrypted.Types.ColumnInfo' 'CCV', $(New-Object 'Microsoft.SqlServer.Management.AlwaysEncrypted.Types.EncryptionInfo' $AppColumnKeyName, ([Microsoft.SqlServer.Management.AlwaysEncrypted.Types.EncryptionType]::Deterministic), $AEAD_AES_256_CBC_HMAC_SHA_256)))
[Microsoft.SqlServer.Management.AlwaysEncrypted.Management.AlwaysEncryptedManagement]::SetColumnEncryptionSchema($ConnectionString, $smoDatabase, $smoTable, $encryptionChanges)

# Change table [Logging].[Log]
$smoTable = $smoDatabase.Tables['Log', $LoggingSchema]
$encryptionChanges = New-Object 'Collections.Generic.List[Microsoft.SqlServer.Management.AlwaysEncrypted.Types.ColumnInfo]'
$encryptionChanges.Add($(New-Object 'Microsoft.SqlServer.Management.AlwaysEncrypted.Types.ColumnInfo' 'User', $(New-Object 'Microsoft.SqlServer.Management.AlwaysEncrypted.Types.EncryptionInfo' $LogColumnKeyName, ([Microsoft.SqlServer.Management.AlwaysEncrypted.Types.EncryptionType]::Deterministic), $AEAD_AES_256_CBC_HMAC_SHA_256)))
$encryptionChanges.Add($(New-Object 'Microsoft.SqlServer.Management.AlwaysEncrypted.Types.ColumnInfo' 'ClientIP', $(New-Object 'Microsoft.SqlServer.Management.AlwaysEncrypted.Types.EncryptionInfo' $LogColumnKeyName, ([Microsoft.SqlServer.Management.AlwaysEncrypted.Types.EncryptionType]::Deterministic), $AEAD_AES_256_CBC_HMAC_SHA_256)))
[Microsoft.SqlServer.Management.AlwaysEncrypted.Management.AlwaysEncryptedManagement]::SetColumnEncryptionSchema($ConnectionString, $smoDatabase, $smoTable, $encryptionChanges)
