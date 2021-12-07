<#
	.SYNOPSIS
		Clear-SCOMCache
	
	.DESCRIPTION
		The script without any switches clears the SCOM cache first and foremost.
		If the -All switch is present: Optionally Flushing DNS, Purging Kerberos Tickets, Resetting NetBIOS over TCPIP Statistics.
		If -Reboot switch is present: Reboots the server(s) along with Resetting Winsock catalog.

	.PARAMETER All
		Optionally clear all caches that SCOM could potentially use that doesnt require a reboot. Flushing DNS, Purging Kerberos Tickets, Resetting NetBIOS over TCPIP Statistics. (Combine with -Reboot for a full clear cache)
	
	.PARAMETER Reboot
		Optionally reset winsock catalog, stop the SCOM Services, clear SCOM Cache, then reboot the server. This will always perform on the local server last.

	.PARAMETER Servers
		Each Server you want to clear SCOM Cache on. Can be an Agent, Management Server, or SCOM Gateway. This will always perform on the local server last.

	.PARAMETER Shutdown
		Optionally shutdown the server after clearing the SCOM cache. This will always perform on the local server last.

	.PARAMETER Sleep
		Time in seconds to sleep between each server.	

	
	.EXAMPLE
		Clear all Gray SCOM Agents
		PS C:\> #Get the SystemCenter Agent Class
		PS C:\>	$agent = Get-SCOMClass | where-object{$_.name -eq "microsoft.systemcenter.agent"}
		PS C:\>	#Get the grey agents
		PS C:\>	$objects = Get-SCOMMonitoringObject -class:$agent | where {$_.IsAvailable -eq $false}
		PS C:\>	.\Clear-SCOMCache.ps1 -Servers $objects
		
		Clear SCOM cache on every Management Server in Management Group.
		PS C:\> Get-SCOMManagementServer | .\Clear-SCOMCache.ps1
		
		Clear SCOM cache on every Agent in the in Management Group.
		PS C:\> Get-SCOMAgent | .\Clear-SCOMCache.ps1
		
		Clear SCOM cache and reboot the Servers specified.
		PS C:\> .\Clear-SCOMCache.ps1 -Servers AgentServer.contoso.com, ManagementServer.contoso.com -Reboot

		Clear SCOM cache and shutdown the Servers specified.
		PS C:\> .\Clear-SCOMCache.ps1 -Servers AgentServer.contoso.com, ManagementServer.contoso.com -Shutdown
	
	.NOTES
		For advanced users: Edit line 716 to modify the default command run when this script is executed.

		.AUTHOR
		Blake Drumm (blakedrumm@microsoft.com)
		
		.MODIFIED
		December 7th, 2021
#>
[OutputType([string])]
param
(
	[Parameter(Mandatory = $false,
			   Position = 1,
			   HelpMessage = 'Optionally clear all caches that SCOM could potentially use that doesnt require a reboot. Flushing DNS, Purging Kerberos Tickets, Resetting NetBIOS over TCPIP Statistics. (Combine with -Reboot for a full clear cache)')]
	[Switch]$All,
	[Parameter(Mandatory = $false,
			   Position = 2,
			   HelpMessage = 'Optionally reset winsock catalog, stop the SCOM Services, clear SCOM Cache, then reboot the server. This will always perform on the local server last.')]
	[Switch]$Reboot,
	[Parameter(Mandatory = $false,
			   ValueFromPipeline = $true,
			   Position = 3,
			   HelpMessage = 'Each Server you want to clear SCOM Cache on. Can be an Agent, Management Server, or SCOM Gateway. This will always perform on the local server last.')]
	[String[]]$Servers,
	[Parameter(Mandatory = $false,
			   Position = 4,
			   HelpMessage = 'Optionally shutdown the server after clearing the SCOM cache. This will always perform on the local server last.')]
	[Switch]$Shutdown,
	[Parameter(Position = 5,
			   HelpMessage = 'Time in seconds to sleep between each server.')]
	[int64]$Sleep
)
BEGIN
{
	Write-Host '===================================================================' -ForegroundColor DarkYellow
	Write-Host '==========================  Start of Script =======================' -ForegroundColor DarkYellow
	Write-Host '===================================================================' -ForegroundColor DarkYellow
	
	$checkingpermission = "Checking for elevated permissions..."
	$scriptout += $checkingpermission
	Write-Host $checkingpermission -ForegroundColor Gray
	if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
	{
		$currentPath = $myinvocation.mycommand.definition
		$nopermission = "Insufficient permissions to run this script. Attempting to open the PowerShell script ($currentPath) as administrator."
		$scriptout += $nopermission
		Write-Warning $nopermission
		# We are not running "as Administrator" - so relaunch as administrator
		# ($MyInvocation.Line -split '\.ps1[\s\''\"]\s*', 2)[-1]
		Start-Process powershell.exe "-File", ('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
		break
	}
	else
	{
		$permissiongranted = " Currently running as administrator - proceeding with script execution..."
		Write-Host $permissiongranted -ForegroundColor Green
	}
	
	Function Time-Stamp
	{
		$TimeStamp = Get-Date -Format "MM/dd/yyyy hh:mm:ss tt"
		write-host "$TimeStamp - " -NoNewline
	}
}
PROCESS
{
	$setdefault = $false
	foreach ($Server in $input)
	{
		if ($Server)
		{
			if ($Server.GetType().Name -eq 'ManagementServer')
			{
				if (!$setdefault)
				{
					$Servers = @()
					$setdefault = $true
				}
				$Servers += $Server.DisplayName
			}
			elseif ($Server.GetType().Name -eq 'AgentManagedComputer')
			{
				if (!$setdefault)
				{
					$Servers = @()
					$setdefault = $true
				}
				$Servers += $Server.DisplayName
			}
			elseif ($Server.GetType().Name -eq 'MonitoringObject')
			{
				if (!$setdefault)
				{
					$Servers = @()
					$setdefault = $true
				}
				$Servers += $Server.DisplayName
			}
		}
	}
	Function Clear-SCOMCache
	{
		[OutputType([string])]
		param
		(
			[Parameter(Mandatory = $false,
					   Position = 1,
					   HelpMessage = 'Optionally clear all caches that SCOM could potentially use that doesnt require a reboot. Flushing DNS, Purging Kerberos Tickets, Resetting NetBIOS over TCPIP Statistics. (Combine with -Reboot for a full clear cache)')]
			[Switch]$All,
			[Parameter(Mandatory = $false,
					   Position = 2,
					   HelpMessage = 'Optionally reset winsock catalog, stop the SCOM Services, clear SCOM Cache, then reboot the server. This will always perform on the local server last.')]
			[Switch]$Reboot,
			[Parameter(Mandatory = $false,
					   ValueFromPipeline = $true,
					   Position = 3,
					   HelpMessage = 'Each Server you want to clear SCOM Cache on. Can be an Agent, Management Server, or SCOM Gateway. This will always perform on the local server last.')]
			[String[]]$Servers,
			[Parameter(Mandatory = $false,
					   Position = 4,
					   HelpMessage = 'Optionally shutdown the server after clearing the SCOM cache. This will always perform on the local server last.')]
			[Switch]$Shutdown,
			[Parameter(Position = 5,
					   HelpMessage = 'Time in seconds to sleep between each server.')]
			[int64]$Sleep
		)
		$setdefault = $false
		foreach ($Server in $input)
		{
			if ($Server)
			{
				if ($Server.GetType().Name -eq 'ManagementServer')
				{
					if (!$setdefault)
					{
						$Servers = @()
						$setdefault = $true
					}
					$Servers += $Server.DisplayName
				}
				elseif ($Server.GetType().Name -eq 'AgentManagedComputer')
				{
					if (!$setdefault)
					{
						$Servers = @()
						$setdefault = $true
					}
					$Servers += $Server.DisplayName
				}
				elseif ($Server.GetType().Name -eq 'MonitoringObject')
				{
					if (!$setdefault)
					{
						$Servers = @()
						$setdefault = $true
					}
					$Servers += $Server.DisplayName
				}
				else
				{
					if (!$setdefault)
					{
						$Servers = @()
						$setdefault = $true
					}
					$Servers += $Server
				}
				
			}
			
		}
		if (!$Servers)
		{
			$Servers = $env:COMPUTERNAME
		}
		function Inner-ClearSCOMCache
		{
			param
			(
				[Parameter(Mandatory = $false,
						   Position = 1)]
				[Switch]$All,
				[Parameter(Mandatory = $false,
						   Position = 2)]
				[Switch]$Reboot,
				[Parameter(Mandatory = $false,
						   Position = 3)]
				[Switch]$Shutdown
			)
			BEGIN
			{
				trap
				{
					Write-Host $error[0] -ForegroundColor Yellow
				}
				Function Time-Stamp
				{
					$TimeStamp = Get-Date -Format "MM/dd/yyyy hh:mm:ss tt"
					write-host "$TimeStamp - " -NoNewline
				}
				
				$currentserv = $env:COMPUTERNAME
				Function Time-Stamp
				{
					$TimeStamp = Get-Date -Format "MM/dd/yyyy hh:mm:ss tt"
					write-host "$TimeStamp - " -NoNewline
				}
				Write-Host "`n==================================================================="
				Time-Stamp
				Write-Host "Starting Script Execution on: " -NoNewline -ForegroundColor DarkCyan
				Write-Host "$currentserv" -ForegroundColor Cyan
			}
			PROCESS
			{
				$omsdk = (Get-WmiObject win32_service | ?{ $_.Name -eq 'omsdk' } | select PathName -ExpandProperty PathName | % { $_.Split('"')[1] }) | Split-Path
				$cshost = (Get-WmiObject win32_service | ?{ $_.Name -eq 'cshost' } | select PathName -ExpandProperty PathName | % { $_.Split('"')[1] }) | Split-Path
				$healthservice = (Get-WmiObject win32_service | ?{ $_.Name -eq 'healthservice' } | select PathName -ExpandProperty PathName | % { $_.Split('"')[1] }) | Split-Path
				$apm = (Get-WmiObject win32_service | ?{ $_.Name -eq 'System Center Management APM' } | select PathName -ExpandProperty PathName | % { $_.Split('"')[1] }) | Split-Path
				$auditforwarding = (Get-WmiObject win32_service -ErrorAction SilentlyContinue | ?{ $_.Name -eq 'AdtAgent' } | select PathName -ExpandProperty PathName | % { $_.Split('"')[1] }) | Split-Path -ErrorAction SilentlyContinue
				$veeamcollector = (Get-WmiObject win32_service | ?{ $_.Name -eq 'veeamcollector' } | select PathName -ExpandProperty PathName | % { $_.Split('"')[1] }) | Split-Path
				if ($omsdk)
				{
					$omsdkStatus = (Get-Service -Name omsdk).Status
					if ($omsdkStatus -eq "Running")
					{
						Time-Stamp
						Write-Host ("Stopping `'{0}`' Service" -f (Get-Service -Name 'omsdk').DisplayName)
						Stop-Service omsdk
					}
					else
					{
						Time-Stamp
						Write-Host ("[Warning] :: Status of `'{0}`' Service - " -f (Get-Service -Name 'omsdk').DisplayName) -NoNewline
						Write-Host "$omsdkStatus" -ForegroundColor Yellow
					}
					
				}
				if ($cshost)
				{
					$cshostStatus = (Get-Service -Name cshost).Status
					if ($cshostStatus -eq "Running")
					{
						Time-Stamp
						Write-Host ("Stopping `'{0}`' Service" -f (Get-Service -Name 'cshost').DisplayName)
						Stop-Service cshost
					}
					else
					{
						Time-Stamp
						Write-Host ("[Warning] :: Status of `'{0}`' Service - " -f (Get-Service -Name 'cshost').DisplayName) -NoNewline
						Write-Host "$cshostStatus" -ForegroundColor Yellow
					}
				}
				if ($apm)
				{
					$apmStatus = (Get-Service -Name 'System Center Management APM').Status
					$apmStartType = (Get-Service -Name 'System Center Management APM').StartType
					if ($apmStatus -eq "Running")
					{
						Time-Stamp
						Write-Host ("Stopping `'{0}`' Service" -f (Get-Service -Name 'System Center Management APM').DisplayName)
						Stop-Service 'System Center Management APM'
					}
					elseif ($apmStartType -eq 'Disabled')
					{
						$apm = $null
					}
					elseif ($apmStatus -eq 'Stopped')
					{
						Time-Stamp
						Write-Host ("Status of `'{0}`' Service - " -f (Get-Service -Name 'System Center Management APM').DisplayName) -NoNewline
						Write-Host "$apmStatus" -ForegroundColor Yellow
						$apm = $null
					}
					else
					{
						Time-Stamp
						Write-Host ("[Warning] :: Status of `'{0}`' Service - " -f (Get-Service -Name 'System Center Management APM').DisplayName) -NoNewline
						Write-Host "$apmStatus" -ForegroundColor Yellow
					}
				}
				if ($auditforwarding)
				{
					$auditforwardingstatus = (Get-Service -Name 'AdtAgent').Status
					$auditforwardingStartType = (Get-Service -Name 'System Center Management APM').StartType
					if ($auditforwardingstatus -eq "Running")
					{
						Time-Stamp
						Write-Host ("Stopping `'{0}`' Service" -f (Get-Service -Name 'AdtAgent').DisplayName)
						Stop-Service AdtAgent
					}
					elseif ($auditforwardingStartType -eq 'Disabled')
					{
						$auditforwarding = $null
					}
					else
					{
						Time-Stamp
						Write-Host ("[Warning] :: Status of `'{0}`' Service - " -f (Get-Service -Name 'AdtAgent').DisplayName) -NoNewline
						Write-Host "$auditforwardingstatus" -ForegroundColor Yellow
					}
				}
				if ($veeamcollector)
				{
					$veeamcollectorStatus = (Get-Service -Name 'veeamcollector').Status
					$veeamcollectorStartType = (Get-Service -Name 'veeamcollector').StartType
					if ($veeamcollectorStatus -eq "Running")
					{
						Time-Stamp
						Write-Host ("Stopping `'{0}`' Service" -f (Get-Service -Name 'System Center Management APM').DisplayName)
						Stop-Service 'System Center Management APM'
					}
					elseif ($veeamcollectorStartType -eq 'Disabled')
					{
						$veeamcollector = $null
					}
					else
					{
						Time-Stamp
						Write-Host ("[Warning] :: Status of `'{0}`' Service - " -f (Get-Service -Name 'System Center Management APM').DisplayName) -NoNewline
						Write-Host "$veeamcollectorStatus" -ForegroundColor Yellow
					}
				}
				if ($healthservice)
				{
					$healthserviceStatus = (Get-Service -Name healthservice).Status
					if ($healthserviceStatus -eq "Running")
					{
						Time-Stamp
						Write-Host ("Stopping `'{0}`' Service" -f (Get-Service -Name 'healthservice').DisplayName)
						Stop-Service healthservice
					}
					else
					{
						Time-Stamp
						Write-Host ("[Warning] :: Status of `'{0}`' Service - " -f (Get-Service -Name 'healthservice').DisplayName) -NoNewline
						Write-Host "$healthserviceStatus" -ForegroundColor Yellow
					}
					try
					{
						Time-Stamp
						Write-Host "Attempting to Move Folder from: `"$healthservice`\Health Service State`" to `"$healthservice\Health Service State.old`" "
						Move-Item "$healthservice\Health Service State" "$healthservice\Health Service State.old" -ErrorAction Stop
						Time-Stamp
						Write-Host "Moved Folder Successfully" -ForegroundColor Green
					}
					catch
					{
						Time-Stamp
						Write-Host "[Info] :: " -NoNewline -ForegroundColor DarkCyan
						Write-Host "$_" -ForegroundColor Gray
						Time-Stamp
						Write-Host "Attempting to Delete Folder: `"$healthservice`\Health Service State`" "
						try
						{
							rd "$healthservice\Health Service State" -Recurse -ErrorAction Stop
							Time-Stamp
							Write-Host "Deleted Folder Successfully" -ForegroundColor Green
						}
						catch
						{
							Write-Host "Issue removing the 'Health Service State' folder. Maybe attempt to clear the cache again, or a process is using the Health Service State Folder." -ForegroundColor Red
							#$healthservice = $null
						}
					}
					
				}
				if ($null -eq $omsdk -and $cshost -and $healthservice)
				{
					Time-Stamp
					try
					{
						$installdir = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Setup" -ErrorAction Stop | Select-Object -Property "InstallDirectory" -ExpandProperty "InstallDirectory"
						try
						{
							Time-Stamp
							Write-Host "Attempting to Move Folder from: `"$installdir`\Health Service State`" to `"$installdir\Health Service State.old`" "
							Move-Item "$installdir\Health Service State" "$installdir\Health Service State.old" -ErrorAction Stop
							Time-Stamp
							Write-Host "Moved Folder Successfully" -ForegroundColor Green
						}
						catch
						{
							Time-Stamp
							Write-Host "[Warning] :: " -NoNewline
							Write-Host "$_" -ForegroundColor Yellow
							Time-Stamp
							Write-Host "Attempting to Delete Folder: `"$installdir`\Health Service State`" "
							try
							{
								rd "$installdir\Health Service State" -Recurse -ErrorAction Stop
								Time-Stamp
								Write-Host "Deleted Folder Successfully" -ForegroundColor Green
							}
							catch
							{
								Write-Warning $_
							}
						}
					}
					catch
					{
						Write-Warning "Unable to locate the Install Directory`nHKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Setup"
						break
					}
				}
				# Clear Console Cache
				$consoleKey = Get-Item 'HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\12\Setup\Console\' -ErrorAction SilentlyContinue
				if ($consoleKey)
				{
					try
					{
						Time-Stamp
						Write-Host "Clearing Operations Manager Console Cache for the following users:";
						if ($Shutdown -or $Reboot)
						{
							Time-Stamp
							Write-Host "  Attempting to force closure of open Operations Manager Console(s) due to Reboot or Shutdown switch present." -ForegroundColor Gray
							Stop-Process -Name "Microsoft.EnterpriseManagement.Monitoring.Console" -Confirm:$false -ErrorAction SilentlyContinue
						}
						$cachePath = Get-ChildItem "$env:SystemDrive\Users\*\AppData\Local\Microsoft\Microsoft.EnterpriseManagement.Monitoring.Console\momcache.mdb"
						foreach ($consolecachefolder in $cachePath)
						{
							Time-Stamp
							Write-Host "  $($consolecachefolder.FullName.Split("\")[2])"
							Remove-Item $consolecachefolder -Force -ErrorAction Stop
						}
					}
					catch { Write-Warning $_ }
				}
				
				if ($All -or $Reboot -or $Shutdown)
				{
					Time-Stamp
					Write-Host "Purging Kerberos Tickets: " -NoNewline
					Write-Host 'KList -li 0x3e7 purge' -ForegroundColor Cyan
					Start-Process "KList" "-li 0x3e7 purge"
					Time-Stamp
					Write-Host "Flushing DNS: " -NoNewline
					Write-Host "IPConfig /FlushDNS" -ForegroundColor Cyan
					Start-Process "IPConfig" "/FlushDNS"
					Time-Stamp
					Write-Host "Resetting NetBIOS over TCPIP Statistics: " -NoNewline
					Write-Host 'NBTStat -R' -ForegroundColor Cyan
					Start-Process "NBTStat" "-R"
				}
				if ($Shutdown)
				{
					Time-Stamp
					Write-Host "Shutting down: " -NoNewLine
					Write-Host "$env:COMPUTERNAME" -ForegroundColor Green
					Shutdown /s /t 10
					continue
				}
				elseif ($Reboot)
				{
					Time-Stamp
					Write-Host "Resetting Winsock catalog: " -NoNewline
					Write-Host '​netsh winsock reset' -ForegroundColor Cyan
					Start-Process "netsh" "winsock reset"
					sleep 1
					Time-Stamp
					Write-Host "Restarting: " -NoNewLine
					Write-Host "$env:COMPUTERNAME" -ForegroundColor Green
					Shutdown /r /t 10
				}
				else
				{
					if ($veeamcollector)
					{
						Time-Stamp
						Write-Host ("Starting `'{0}`' Service" -f (Get-Service -Name 'veeamcollector').DisplayName)
						Start-Service 'veeamcollector'
					}
					if ($healthservice)
					{
						Time-Stamp
						Write-Host ("Starting `'{0}`' Service" -f (Get-Service -Name 'healthservice').DisplayName)
						Start-Service 'healthservice'
					}
					if ($omsdk)
					{
						Time-Stamp
						Write-Host ("Starting `'{0}`' Service" -f (Get-Service -Name 'omsdk').DisplayName)
						Start-Service 'omsdk'
					}
					if ($cshost)
					{
						Time-Stamp
						Write-Host ("Starting `'{0}`' Service" -f (Get-Service -Name 'cshost').DisplayName)
						Start-Service 'cshost'
					}
					if ($apm)
					{
						Time-Stamp
						Write-Host ("Starting `'{0}`' Service" -f (Get-Service -Name 'System Center Management APM').DisplayName)
						Start-Service 'System Center Management APM'
					}
					if ($auditforwarding)
					{
						Time-Stamp
						Write-Host ("Starting `'{0}`' Service" -f (Get-Service -Name 'AdtAgent').DisplayName)
						Start-Service 'AdtAgent'
					}
				}
			}
			END
			{
				Time-Stamp
				Write-Host "Completed Script Execution on: " -NoNewline -ForegroundColor DarkCyan
				Write-Host "$currentserv" -ForegroundColor Cyan
			}
			
		}
		if ($Servers)
		{
			if ($Servers -match $env:COMPUTERNAME)
			{
				$Servers = $Servers -notmatch $env:COMPUTERNAME
				$containslocal = $true
			}
			$InnerClearSCOMCacheFunctionScript = "function Inner-ClearSCOMCache { ${function:Inner-ClearSCOMCache} }"
			foreach ($server in $Servers)
			{
				if ($Shutdown)
				{
					try
					{
						Invoke-Command -ErrorAction Stop -ComputerName $server -ArgumentList $InnerClearSCOMCacheFunctionScript -ScriptBlock {
							Param ($script)
							. ([ScriptBlock]::Create($script))
							return Inner-ClearSCOMCache -Shutdown
						}
					}
					catch { Write-Host $Error[0] -ForegroundColor Red }
				}
				elseif ($Reboot)
				{
					if ($All)
					{
						try
						{
							Invoke-Command -ErrorAction Stop -ComputerName $server -ArgumentList $InnerClearSCOMCacheFunctionScript -ScriptBlock {
								Param ($script)
								. ([ScriptBlock]::Create($script))
								return Inner-ClearSCOMCache -All -Reboot
							}
						}
						catch { Write-Host $Error[0] -ForegroundColor Red }
					}
					else
					{
						try
						{
							Invoke-Command -ErrorAction Stop -ComputerName $server -ArgumentList $InnerClearSCOMCacheFunctionScript -ScriptBlock {
								Param ($script)
								. ([ScriptBlock]::Create($script))
								return Inner-ClearSCOMCache -Reboot
							}
						}
						catch { Write-Host $Error[0] -ForegroundColor Red }
					}
					if ($Sleep)
					{
						Time-Stamp
						Write-Host "Sleeping for $Sleep seconds." -NoNewline
						Start-Sleep -Seconds $Sleep
					}
					continue
				}
				elseif ($All)
				{
					try
					{
						Invoke-Command -ErrorAction Stop -ComputerName $server -ArgumentList $InnerClearSCOMCacheFunctionScript -ScriptBlock {
							Param ($script)
							. ([ScriptBlock]::Create($script))
							return Inner-ClearSCOMCache -All
						}
					}
					catch { Write-Host $Error[0] -ForegroundColor Red }
					if ($Sleep)
					{
						Time-Stamp
						Write-Host "Sleeping for $Sleep seconds." -NoNewline
						Start-Sleep -Seconds $Sleep
					}
				}
				else
				{
					try
					{
						Invoke-Command -ErrorAction Stop -ComputerName $server -ArgumentList $InnerClearSCOMCacheFunctionScript -ScriptBlock {
							Param ($script)
							. ([ScriptBlock]::Create($script))
							return Inner-ClearSCOMCache
						}
					}
					catch { Write-Host $Error[0] -ForegroundColor Red }
					if ($Sleep)
					{
						Time-Stamp
						Write-Host "Sleeping for $Sleep seconds." -NoNewline
						Start-Sleep -Seconds $Sleep
					}
					continue
				}
				continue
			}
			if ($containslocal)
			{
				if ($Reboot)
				{
					Inner-ClearSCOMCache -Reboot
				}
				elseif ($Shutdown)
				{
					Inner-ClearSCOMCache -Shutdown
				}
				elseif ($Reboot -and $All)
				{
					Inner-ClearSCOMCache -Reboot -All
				}
				elseif ($All)
				{
					Inner-ClearSCOMCache -All
				}
				else
				{
					Inner-ClearSCOMCache
				}
				$completedlocally = $true
			}
		}
		if ($containslocal -and !$completedlocally)
		{
			if ($Reboot)
			{
				Inner-ClearSCOMCache -Reboot
			}
			elseif ($Shutdown)
			{
				Inner-ClearSCOMCache -Shutdown
			}
			elseif ($Reboot -and $All)
			{
				Inner-ClearSCOMCache -Reboot -All
			}
			elseif ($All)
			{
				Inner-ClearSCOMCache -All
			}
			else
			{
				Inner-ClearSCOMCache
			}
		}
	}
	if ($All -or $Reboot -or $Servers -or $Shutdown -or $Sleep)
	{
		Clear-SCOMCache -All:$All -Reboot:$Reboot -Servers $Servers -Shutdown:$Shutdown -Sleep:$Sleep
	}
	else
	{
<# Edit line 716 to modify the default command run when this script is executed.

   Example: 
   Clear-SCOMCache -Servers Agent1.contoso.com, Agent2.contoso.com, MangementServer1.contoso.com, MangementServer2.contoso.com
   #>
		Clear-SCOMCache
	}
}
end
{
	Time-Stamp
	Write-Host "Script has Completed!" -ForegroundColor Gray
	Write-Host "==================================================================="
}
