<#

.SYNOPSIS
    Gets the resource pool shares per VM from vCenter and shows the weight imbalance

.DESCRIPTION
    This script will connect to your vCenter server and scan the resource pools. 
    It will then calculate how many shares are in place per CPU / 1MB memory. 
    This allows you to correctly size your resource pools

.PARAMETER vCenter
    FQDN or IP for the vCenter server you wish to run the script against.

.PARAMETER csv
    Path to csv file: 
    FQDN, Username, Password
    vcenter.domain.com,user1,password1

.PARAMETER Reservation
    Show how much resources are reserved by the resource pool

.PARAMETER Limit 
    Show the resource limits for a resource pool.

.PARAMETER PerVmShares
    Display the current value per vm for the shares in a resource pool. This allows you to 
    see the balance between pools and see which pool has a higher priority.

.PARAMETER RecommendedShares
    Display the recommended total pool shares for low / normal / high these can either be 
    hard coded into the script or added to variables. 

.PARAMETER CpuShares
    Set the share value you would like to have for Low/normal/high and the script will calculate
    the values for you, default values are "2000,4000,8000" following VMware standards

.PARAMETER MemShares
    Set the share value you would like to have for Low/normal/high and the script will calculate
    the values for you, default values are "5,10,20" following VMware standards

.EXAMPLE
    .\Get-ResourcePoolSharesReport.ps1 -Csv .\ResourcePoolShares.csv 
.EXAMPLE    
    .\Get-ResourcePoolSharesReport.ps1 -vCenter "my-vc01.yoursite.com"
.EXAMPLE
    .\Get-ResourcePoolSharesReport.ps1 -vCenter "my-vc01.yoursite.com" -PerVmShares -RecommendedShares -CpuShares "2000,4000,8000" -MemShares "5,10,20" -reservation -limit
 
.NOTES
    Script created by Steven Marks www.spottedhyena.co.uk
 
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true,ParameterSetName="vCenter", Position=0)]
        [string]$vCenter,

    [Parameter(Mandatory=$true,ParameterSetName="Csv", Position=0)]
        [string]$Csv,

    [Parameter(Mandatory=$false)]
        [switch]$PerVmShares,
        [switch]$RecommendedShares,
        [switch]$Reservation,
        [switch]$Limit,
        [string]$Report="Report.html",
        [string]$CpuShares="500,1000,2000",
        [string]$MemShares="5,10,20"
)
Try{    
    If ((Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null) { Add-PSSnapin VMware.VimAutomation.Core }
    
    function Get-vCenterClusterPools{
        ## Null clusters then get clusters
        $clusters = $null
        $clusters = Get-Cluster
    
        ## Enumerate Members of Cluster
        Foreach($cluster in $clusters){
            Add-Content $report "<h3>$cluster</h3>"
        
            $rpools = $null
            [array]$rpools = Get-ResourcePool -Location $cluster
            ### Get total memory in cluster ##
            $clusterhosts = get-vmhost -Location $cluster
            $totalclustermem = ($clusterhosts.memorytotalmb | measure -sum).sum
            $totalclustermem = "{0:N0}" -f $totalclustermem


            $objAverage = $null
            $sharesallocation = $null
            $sharesallocation = @()

            ## Enumerate Members of RPools
            Foreach ($rpool in $rpools){
                If ($rpool.name -ne "Resources"){
	        
	                $rpoolvms = $rpool | Get-VM
                    if($rpoolvms){
                        $totalvms = ($rpool | Get-VM).count
                        $totalram = "{0:N0}" -f ($rpoolvms.MemoryMB | Measure-Object -sum).sum
                        $totalcpu = "{0:N0}" -f ($rpoolvms.NumCPU | Measure-Object -sum).sum

            
                        ### Calculate current Shares ###
            
                        [int]$totalmemshares = $rpool.NummemShares
                        [int]$totalcpushares = $rpool.NumCpuShares

                        $totalpercpu = "{0:N2}" -f ($totalcpushares/$totalcpu)
                        $totalpermem = "{0:N2}" -f ($totalmemshares/$totalram)
            
                        $objAverage = New-Object System.Object
                        $objAverage | Add-Member -type NoteProperty -name ResourcePool -value $rpool.name
                        $objAverage | Add-Member -type NoteProperty -name "RAM Shares" -value $totalmemshares 
                        $objAverage | Add-Member -type NoteProperty -name "CPU Shares" -value $totalcpushares 

                        $objAverage | Add-Member -type NoteProperty -name "Total VMs" -value $totalvms
                        $objAverage | Add-Member -type NoteProperty -name "Total RAM (MB)" -value $totalram
                        $objAverage | Add-Member -type NoteProperty -name "Total CPU" -value $totalcpu
                        if($PerVmShares){
                            $objAverage | Add-Member -type NoteProperty -name "Shares Per MB RAM" -value $totalpermem
                            $objAverage | Add-Member -type NoteProperty -name "Shares Per CPU" -value $totalpercpu
                        }
                        if($RecommendedShares){
                            
                            $CpuShares = $CpuShares.Split(",")
                            $MemShares = $MemShares.Split(",")

                            $low = [int]$totalram * [int]$MemShares[0]
                            $normal = [int]$totalram * [int]$MemShares[1]
                            $high = [int]$totalram * [int]$MemShares[2]
                            $recommendedmem = "$low / $normal / $high"

                            $low = [int]$totalcpu * [int]$CpuShares[0]
                            $normal = [int]$totalcpu * [int]$CpuShares[1]
                            $high = [int]$totalcpu * [int]$CpuShares[2]
                            $recommendedcpu = "$low / $normal / $high"
                            
                            $objAverage | Add-Member -type NoteProperty -name "Recommended RAM LOW/NORMAL/HIGH" -value $recommendedmem
                            $objAverage | Add-Member -type NoteProperty -name "Recommended CPU LOW/NORMAL/HIGH" -value $recommendedcpu
                        }
                        if($reservation){
                            $objAverage | Add-Member -type NoteProperty -name "RAM Reservation" -value $rpool.MemReservationMB
                            $objAverage | Add-Member -type NoteProperty -name "CPU Reservation" -value $rpool.CpuReservationMhz
                        }
                        if($limit){
                            $objAverage | Add-Member -type NoteProperty -name "RAM Limit" -value $rpool.MemLimitMB
                            $objAverage | Add-Member -type NoteProperty -name "CPU Limit" -value $rpool.CpuLimitMhz
                        }

                    $sharesallocation  += $objAverage    
                    }
                } 
            }
            $sharesallocation | ConvertTo-Html -Fragment | Add-Content $report
        
        }

    }

    ### BEGIN PROCESSING SCRIPT ###

    $HtmlHeader = "<head><style>"
    $HtmlHeader += "body { background-color: white; color: rgb(64, 64, 64); font-family: Calibri, sans-serif, sans-serif; }"
    $HtmlHeader += "h1 { font-size: 26pt; font-weight: bold; color: rgb(0,210,255); letter-spacing: -1.4pt; padding: 0pt; margin: 0pt; margin-top: 6pt; }"
    $HtmlHeader += "h1 small { font-size: 14pt; font-weight: normal; padding: 0pt; margin: 0pt; }"
    $HtmlHeader += "h2 { font-size: 18pt; font-weight: bold; color: rgb(0,210,255); padding: 0pt; margin: 18pt 0pt 10pt 0pt; }"
    $HtmlHeader += "p { font-size: 11pt; margin: 0pt 0pt 6pt 0pt; line-height: 1.1; }"
    $HtmlHeader += "table { border-collapse: collapse; border-width: 1pt; border-color: white; border-style: solid; margin-top: 12pt; margin-bottom: 10pt;}"
    $HtmlHeader += "th { font-weight: normal; background-color: rgb(0,210,255); color: white; border: 1px solid white; text-transform: uppercase; padding: 0.25em 1em; }"
    $HtmlHeader += "td { font-weight: normal; background-color: rgb(217, 217, 217); color: rgb(64, 64, 64); border: 1px solid white; text-transform: uppercase; padding: 0.25em 1em;}"
    $HtmlHeader += "footer { font-weight: normal; background-color: white; color: rgb(64, 64, 64); text-transform: uppercase; padding: 0.25em 1em;}"

    $HtmlHeader += "</style></head>"
    
    Set-Content $report $HtmlHeader
    Add-Content $report "<h1>Resource Pool Shares</h1>"

    if($vCenter){
        $cred = Get-Credential
        ## Connect to the vCenter Server
        $viServer = Connect-VIServer -Server $vCenter -Credential $cred

        ## Create HTML Document
        Add-Content $report "<h2>$vCenter</h2>"
    
        Get-vCenterClusterPools

        Disconnect-VIServer -Server $vCenter -Confirm:$false -Force -ErrorAction SilentlyContinue
        
    }elseif($Csv){

        $csvData = Import-Csv $csv
    
        $csvData | ForEach-Object {
            $vCenter = $_.FQDN
            ## Connect to the vCenter Server
            $viServer = Connect-VIServer -Server $vCenter -User $_.User -Password $_.Pass

            ## Create HTML Document
            Add-Content $report "<h2>$vCenter</h2>"
        
            Get-vCenterClusterPools

            Disconnect-VIServer -Server $_.FQDN -Confirm:$false -Force -ErrorAction SilentlyContinue
        }

    }
    Add-Content $report "<footer><center>Script Created by <a href='http://spottedhyena.co.uk'>www.spottedhyena.co.uk</a></center><footer>"
}
Catch{
    # catch any exceptions
}
Finally{
    # Any code that should complete after an exception occurs
}
