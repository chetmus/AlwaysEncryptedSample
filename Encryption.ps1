# Modified from script generated by SQL Server Management Studio at 10:27 PM on 2/5/2016
[cmdletbinding()]
param(
	[string] $ConnectionString = "Server=.;Integrated Security=SSPI;Initial Catalog=AlwaysEncryptedSample",
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

Import-Module SqlServer

# Load reflected assemblies
{
	[reflection.assembly]::LoadwithPartialName('System.Data.SqlClient')
	[reflection.assembly]::LoadwithPartialName('Microsoft.SQLServer.SMO')
	[reflection.assembly]::LoadwithPartialName('Microsoft.SqlServer.ConnectionInfo')
	[reflection.assembly]::LoadwithPartialName('System.Security.Cryptography.X509Certificates')
    [reflection.assembly]::LoadwithPartialName('Microsoft.SqlServer.TransactSql.ScriptDom')
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
    @($AuthColumnKeyName, $AppColumnKeyName, $LogColumnKeyName) | %{ 
        Remove-SqlColumnEncryptionKey -Name $_ -InputObject $smoDatabase
    }
    Remove-SqlColumnMasterKey -Name $MasterKeySQLName -InputObject $smoDatabase
	ls Cert:\CurrentUser\My |  where subject -eq $MasterKeyDNSName | rm
}

$cert = New-SelfSignedCertificate `
	-Subject $MasterKeyDNSName `
	-CertStoreLocation Cert:\CurrentUser\My `
	-KeyExportPolicy Exportable `
    -Type DocumentEncryptionCert `
    -KeyUsage DataEncipherment `
    -KeySpec KeyExchange
$cmkPath = "CurrentUser/My/$($cert.ThumbPrint)"
Write-Verbose "Certificate Master Key Path: $($cmkPath)"

# Create a SqlColumnMasterKeySettings object for your column master key. 
$cmkSettings = New-SqlCertificateStoreColumnMasterKeySettings `
    -CertificateStoreLocation "CurrentUser" `
    -Thumbprint $cert.Thumbprint

New-SqlColumnMasterKey -Name $MasterKeySQLName -InputObject $smoDatabase -ColumnMasterKeySettings $cmkSettings
$cmkSettings = New-SqlCertificateStoreColumnMasterKeySettings `
    -CertificateStoreLocation "CurrentUser" `
    -Thumbprint $cert.Thumbprint

New-SqlColumnEncryptionKey -InputObject $smoDatabase -ColumnMasterKey $MasterKeySQLName -Name $AuthColumnKeyName
New-SqlColumnEncryptionKey -InputObject $smoDatabase -ColumnMasterKey $MasterKeySQLName -Name $AppColumnKeyName
New-SqlColumnEncryptionKey -InputObject $smoDatabase -ColumnMasterKey $MasterKeySQLName -Name $LogColumnKeyName

#TODO: wrap below into Cmdlets up at the top.

# Change encryption schema
$AEAD_AES_256_CBC_HMAC_SHA_256 = 'AEAD_AES_256_CBC_HMAC_SHA_256'

$encryptionChanges = @()

# Change table [Authentication].[AspNetUsers]
$encryptionChanges += New-SqlColumnEncryptionSettings -ColumnName "$($AuthSchema).AspNetUsers.SSN" -EncryptionType Randomized -EncryptionKey $AuthColumnKeyName


# Change table [Purchasing].[CreditCards]
#$encryptionChanges += New-SqlColumnEncryptionSettings -ColumnName "$($AppSchema).CreditCards.CardNumber" -EncryptionType Randomized -EncryptionKey $AppColumnKeyName
$encryptionChanges += New-SqlColumnEncryptionSettings -ColumnName "$($AppSchema).CreditCards.CCV" -EncryptionType Randomized -EncryptionKey $AppColumnKeyName

# Change table [Logging].[Log]
$encryptionChanges += New-SqlColumnEncryptionSettings -ColumnName "$($LoggingSchema).Log.User" -EncryptionType Deterministic -EncryptionKey $LogColumnKeyName
$encryptionChanges += New-SqlColumnEncryptionSettings -ColumnName "$($LoggingSchema).Log.ClientIP" -EncryptionType Deterministic -EncryptionKey $LogColumnKeyName

Set-SqlColumnEncryption -ColumnEncryptionSettings $encryptionChanges -InputObject $smoDatabase