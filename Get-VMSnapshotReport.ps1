<#

.SYNOPSIS
    Generates a table of VMware Snapshots from a vCenter Server

.DESCRIPTION
    This script takes a vCenter Server with credentials that
    are specified with the -vcenter -user and -password paramaters.

    any errors will cause the script to stop processing further snapshots. 
    It will generate an e-mail report stating the error and the last vCenter
    server it processed along with as much snapshot information it has already acquired.

.PARAMETER EmailTo
    The email address to send the report to (e.g. user@domain.com)

.PARAMETER EmailFrom
    The email address to send the report from (e.g. user@domain.com)

.PARAMETER EmailSubject
    The subject of the email

.PARAMETER EmailServer
    The SMTP Server to send the email through

.PARAMETER OlderThan
    The number of hours to ignore snapshots default 24Hours

.PARAMETER vCenter
    The vCenter server to run the script against. 

.PARAMETER user
    A read-only or above user for vCenter 

.PARAMETER password
    vCenter user password  

.EXAMPLE
    ./Get-VMSnapShotReport.ps1 -vCenter "your.vcenter.com" -user username -password YourPassword -OlderThan 48 -EmailTo "user@domain.com" -EmailSubject "My Snapshot Report" -EmailServer "mail.domain.com"
    Run a report for Snapshots older than 48 hours and overriding the email address, subject and SMTP Server.
 
.NOTES
    Script created by Steven Marks www.spottedhyena.co.uk
 
#>

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True,Position=1)]
  [Alias('File')]
   [string]$vCenter,

   [string]$user,

   [string]$password,

   [string]$EmailTo,

   [string]$EmailFrom,
  [Parameter(Mandatory=$True)]
  [Alias('SMTPServer')]
   [string]$EmailServer,

   [string]$EmailSubject,

   [int]$OlderThan=24
)
Try {
    # Load the PowerShell Modules for VMware PowerCLI if not already loaded (allows script to run via PowerShell as well as PowerCLI as long as PowerCLI is installed
    If ((Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null) { Add-PSSnapin VMware.VimAutomation.Core }

    $compareDate = (Get-Date).AddHours(-$OlderThan)

    $snapshots = @()
    $PhantomSnaps = @()

    # Connect to the vCenter Server
    $viServer = Connect-VIServer -Server $vcenter -User $user -Password $password
    $snapshots += Get-VM | Get-Snapshot | Where-Object {$_.Created -le $compareDate -and $_.Name -notlike "VCD-SNAPSHOT*" } | Select-Object VM,Name,Created,@{Label="SizeGB";Expression={[Math]::Round($_.SizeGB,2)}} 
    $PhantomSnaps = Get-VM|?{((get-harddisk $_).count*2)*((get-snapshot -vm $_).count + 1) -lt ($_.extensiondata.layoutex.file|?{$_.name -like "*vmdk"}).count} | Select @{Label="vCenter";Expression={$vCenter}},Name
                
    # Disconnect from the vCenter Server without prompting
    Disconnect-VIServer -Server $_.vcenter -Confirm:$False

    If($snapshots.Count -gt 0)
    {
        # Email the formatted output
        $mailMessage = New-Object Net.Mail.MailMessage
        $smtp = New-Object Net.Mail.SmtpClient($EmailServer)
    
        $EmailHeader = "<style>"
        $EmailHeader += "body { background-color: white; color: rgb(64, 64, 64); font-family: Calibri, sans-serif, sans-serif; }"
        $EmailHeader += "h1 { font-size: 26pt; font-weight: bold; color: rgb(50, 205, 50); letter-spacing: -1.4pt; padding: 0pt; margin: 0pt; margin-top: 6pt; }"
        $EmailHeader += "h1 small { font-size: 14pt; font-weight: normal; padding: 0pt; margin: 0pt; }"
        $EmailHeader += "h2 { font-size: 18pt; font-weight: bold; color: rgb(50, 205, 50); padding: 0pt; margin: 18pt 0pt 10pt 0pt; }"
        $EmailHeader += "p { font-size: 11pt; margin: 0pt 0pt 6pt 0pt; line-height: 1.1; }"
        $EmailHeader += "table { border-collapse: collapse; border-width: 1pt; border-color: white; border-style: solid; margin-top: 12pt; margin-bottom: 10pt;}"
        $EmailHeader += "th { font-weight: normal; background-color: rgb(50, 205, 50); color: white; border: 1px solid white; text-transform: uppercase; padding: 0.25em 1em; }"
        $EmailHeader += "td { font-weight: normal; background-color: rgb(217, 217, 217); color: rgb(64, 64, 64); border: 1px solid white; text-transform: uppercase; padding: 0.25em 1em;}"
        $EmailHeader += "</style>"

        $EmailBody = "<h1>vSphere Snapshot Report<br><small>"
        $EmailBody += Get-Date -Format "dddd, d MMMM yyyy"
        $EmailBody += "</small></h1>"
        $EmailBody += "<p>This report highlights any VMware level snapshots that currently exist on $vCenter. These snapshots should be removed where possible to avoid performance issues that can occur with long-term snapshots in vSphere environments.</p>"

        $frag1 = $snapshots | Sort-Object -Property vCenter,Created | ConvertTo-Html -fragment -PreContent '<h2>Snapshots</h2>' | Out-String
        $frag2 = $PhantomSnaps | Sort-Object -Property vCenter,Name | ConvertTo-Html -fragment -PreContent '<h2>Phantom Snapshots</h2>' | Out-String

        $mailMessage.From = $EmailFrom
        $mailMessage.To.Add($EmailTo)
        $mailMessage.Subject = $EmailSubject
        $mailMessage.Body = ConvertTo-Html -Head $EmailHeader -body $EmailBody -PostContent $frag1,$frag2
        $mailMessage.IsBodyHTML = $true
        $smtp.Send($mailMessage)
        exit 0
    } Else {
        exit 2
    }
}
Catch
{
    # Email the exception
    $mailMessage = New-Object Net.Mail.MailMessage
    $smtp = New-Object Net.Mail.SmtpClient($EmailServer)
    
    $EmailHeader = "<style>"
    $EmailHeader += "body { background-color: white; color: rgb(64, 64, 64); font-family: Calibri, sans-serif, sans-serif; }"
    $EmailHeader += "h1 { font-size: 26pt; font-weight: bold; color: rgb(50, 205, 50); letter-spacing: -1.4pt; padding: 0pt; margin: 0pt; margin-top: 6pt; }"
    $EmailHeader += "h1 small { font-size: 14pt; font-weight: normal; padding: 0pt; margin: 0pt; }"
    $EmailHeader += "h2 { font-size: 18pt; font-weight: bold; color: rgb(50, 205, 50); padding: 0pt; margin: 18pt 0pt 10pt 0pt; }"
    $EmailHeader += "p { color: red; font-size: 11pt; margin: 0pt 0pt 6pt 0pt; line-height: 1.1; }"
    $EmailHeader += "table { border-collapse: collapse; border-width: 1pt; border-color: white; border-style: solid; margin-top: 12pt; margin-bottom: 10pt;}"
    $EmailHeader += "th { font-weight: normal; background-color: rgb(50, 205, 50); color: white; border: 1px solid white; text-transform: uppercase; padding: 0.125em 1em; }"
    $EmailHeader += "td { font-weight: normal; background-color: rgb(217, 217, 217); color: rgb(64, 64, 64); border: 1px solid white; text-transform: uppercase; padding: 0.125em 1em;}"
    $EmailHeader += "</style>"

    $EmailBody = "<h1>vSphere Snapshot Report<br><small>"
    $EmailBody += Get-Date -Format "dddd, d MMMM yyyy"
    $EmailBody += "</small></h1>"
    $EmailBody += "<p><strong>An error occured while processing the SnapShot Script: </strong>"
    $EmailBody += $_.Exception.Message
    $EmailBody += "</p>"
    $EmailBody += "<p><strong>Last vCenter: </strong>"
    $EmailBody += $vCenter
    $EmailBody += "</p>"
    $EmailBody += "<p>Below is a report of what the script was able to retrieve</p>"

    $EmailSubject += " (Some errors occured)"

    $frag1 = $snapshots | Sort-Object -Property vCenter,Created | ConvertTo-Html -fragment -PreContent '<h2>Snapshots</h2>' | Out-String
    $frag2 = $PhantomSnaps | Sort-Object -Property vCenter,Name | ConvertTo-Html -fragment -PreContent '<h2>Phantom Snapshots</h2>' | Out-String


    $mailMessage.From = $EmailFrom
    $mailMessage.To.Add($EmailTo)
    $mailMessage.Subject = $EmailSubject
    $mailMessage.Body = ConvertTo-Html -Head $EmailHeader -body $EmailBody -PostContent $frag1,$frag2
    $mailMessage.IsBodyHTML = $true
    $smtp.Send($mailMessage)
    Write-Host "Last vCenter: " $vCenter
    Write-Error -Message $_.Exception.Message
    exit 1
}
Finally
{
    # Any code that should complete after an exception occurs
}