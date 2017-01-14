param
(
	[Parameter(Mandatory=$false)]
	[string]$AzureConnectionAssetName = 'AzureRunAsConnection',
	[Parameter(Mandatory=$false)]
	[string]$ResourceGroupName = 'lp-rg-prod-ne-001',
	[Parameter(Mandatory=$false)]
	[string]$StorageAccountName = 'sqlbackups795620standard',
	[Parameter(Mandatory=$false)]
	[string]$ContainerName = 'sqlbackups-lp-az-sql-001',
	[Parameter(Mandatory=$false)]
	[int]$Retention = 30,
	[Parameter(Mandatory=$false)]
	[bool]$Delete = $false
)

try
{
	$ErrorActionPreference = 'Stop';
	$Error.Clear();
	
	$AutomationConnection = Get-AutomationConnection -Name $AzureConnectionAssetName;
	$AzureAccount = Add-AzureRmAccount -ServicePrincipal -TenantId $AutomationConnection.TenantId -ApplicationId $AutomationConnection.ApplicationId -CertificateThumbprint $AutomationConnection.CertificateThumbprint;	
}
catch
{
	if (!($AutomationConnection))
	{
		throw "Azure Automation Connection $($AzureConnectionAssetName) not found.";
	}
	else
	{
		throw $Error.Exception;
	}
}

$StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName;
$Backups = $StorageAccount |Get-AzureStorageBlob -Container $ContainerName;
$RetentionDate = (Get-Date).AddDays(-($Retention));

foreach ($Backup in $Backups)
{
	if (($Backup.LastModified) -lt $RetentionDate)
	{
		if ($Delete)
		{
			Remove-AzureStorageBlob -CloudBlob $Backup.ICloudBlob -Context $StorageAccount.Context;
		}
		else
		{
			Write-Output -InputObject $Backup;
		}
	}
}