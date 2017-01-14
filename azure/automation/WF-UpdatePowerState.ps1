workflow Update-PowerState
{
	param
	(
		[Parameter(Mandatory=$false)]
		[string]$AzureConnectionAssetName = 'AzureRunAsConnection',
		[Parameter(Mandatory=$true)]
		[string]$ResourceGroupName,
		[Parameter(Mandatory=$true)]
		[ValidateSet('PowerState/running','PowerState/deallocated')]
		[string]$PowerState
	)

	try
	{
		$ErrorActionPreference = 'Stop';
	
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

	$VMs = Get-AzureRmVM -ResourceGroupName $ResourceGroupName;

	foreach -Parallel ($VM in $VMs)
	{
		#
		# Check PowerState
		#
		$VmStatus = Get-AzureRmVM -ResourceGroupname $VM.ResourceGroupname -Name $VM.Name -Status;
		#
		# Check if ProvisioningState -eq updating, if so check powerstate
		#   PowerState/deallocating vm is going down
		#   There is no PowerState on a vm that is off, as it's coming on there are the following states
		#   PowerState/stopped this is different from PowerState/deallocated (perhaps if the machine is powered off from the OS side)
		#   PowerState/starting vm is starting up
		#   PowerState/running vm is running
		#
		if (($VmStatus.Statuses |Select-Object -Property Code) -match 'ProvisioningState/updating')
		{
			#
			# VM is updating
			#
			$Status = ($VmStatus.Statuses |Where-Object -Property Code -Like 'PowerState*' |Select-Object -ExpandProperty Code);
			Write-Output "$($VM.Name) is updating current status is $($Status).";
		}
		else
		{
			if ($PowerState -eq 'PowerState/running')
			{
				#
				# This VM needs to be running
				#
				if (!(($VmStatus.Statuses |Select-Object -Property Code) -match $PowerState))
				{
					Start-AzureRmVM -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName;
				}
			}
			elseif ($PowerState -eq 'PowerState/deallocated')
			{
				#
				# This VM needs to be stopped
				#
				if (!(($VmStatus.Statuses |Select-Object -Property Code) -match $PowerState))
				{
					Stop-AzureRmVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Force;
				}
			}
		}
	}
}