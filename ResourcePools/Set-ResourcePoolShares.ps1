<#

.SYNOPSIS
    Sets the resource pool shares per VM

.DESCRIPTION
    This script will connect to your vCenter server and scan the resource pools.
    It will ask for a per VM share value for CPU and RAM, these will then be calculated together and set on the 
    resource pools giving the correct shares value

.PARAMETER vcenter
    FQDN for your vCenter server

.PARAMETER cluster
    The name of your vCenter cluster

.EXAMPLE
    ./Get-ResourcePoolShares.ps1 -vcenter "vcenter.domain.com" -cluster "vcluster"
 
.NOTES
    Script created by Steven Marks from spottedhyena.co.uk
 
#>
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True,Position=1)]
   [string]$vcenter,
  [Parameter(Mandatory=$True,Position=1)]
   [string]$cluster
)
Try 
    {
    If ((Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null) { Add-PSSnapin VMware.VimAutomation.Core }

    ## Gather RPools
    $cred = Get-Credential

    Connect-VIServer $vcenter -Credential $cred
    [array]$rpools = Get-ResourcePool -Location (Get-Cluster $cluster)

    ## Enumerate Members of RPools
    Foreach ($rpool in $rpools)
	    {
	    If ($rpool.name -ne "Resources")
		    {
		    [int]$percpushares = Read-Host "How many shares per CPU in the $($rpool.Name) resource pool?"
            [int]$perramshares = Read-Host "How many shares per MB RAM in the $($rpool.Name) resource pool?"
		    $rpoolvms = $rpool | Get-VM
            $totalram = ($rpoolvms.MemoryMB | Measure-Object -sum).sum
            $totalcpu = ($rpoolvms.NumCPU | Measure-Object -sum).sum
        
		    [int]$rpcpushares = $percpushares * $totalcpu
            [int]$rpramshares = $perramshares * $totalram
		    Write-Host -ForegroundColor Green -BackgroundColor Black $rpool.name
		    Write-Host "Found $totalvms in the $($rpool.name) resource pool, using $totalram MB RAM and $totalcpu vCPU's. This pool will be set to $rpramshares RAM shares and $rpcpushares CPU shares."
		    Set-ResourcePool -ResourcePool $rpool.Name -CpuSharesLevel:Custom -NumCpuShares $rpshares -MemSharesLevel:Custom -NumMemShares $rpshares -Confirm:$true | Out-Null
		    }
	    }
    }
Catch
    {
    # catch any exceptions
    }
Finally
    {
    # Any code that should complete after an exception occurs
    }
