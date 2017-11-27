# +---------------------------------------------------------------------------
# | File : SyslogSendUDP.ps1                                          
# | Version : 0.1
# | Date : 2017/11/27                                    
# | Usage : .\SyslogSendUDP.ps1 C:\temp\config.txt
# +----------------------------------------------------------------------------

function usage {
    Write-Host "Usage: "$Script:MyInvocation.MyCommand.Name "<configFilePath>"
    exit 1
}

if ($args.length -eq 0) {
    usage
}

# Get Parameters
$confs = ((Get-Content -path $args[0])) | ConvertFrom-StringData

# Set Priority - local2,notice
$Priority = 149

# Set Hostname
$Hostname = Hostname

function TargetLength($file, $countf) {
    $currentnum = (Get-Content -Path $file).Length
    $previusnum = Get-Content -Path $countf
    # Write num
    $currentnum | Out-File -FilePath $countf -Encoding UTF8
    Write-EventLog -LogName Application -Source SyslogSendUDP_event_source -EventId 1001 -EntryType Information -Message "taeget file length : $currentnum."
    $Tailnum = $currentnum - $previusnum
    return [int]$Tailnum
}

function ReadFile($number){
    # Read a file
    $Message = Get-Content -Path $confs.TAILFILE | Select-Object -Last $number
    return $Message
}

function SyslogSend($Body) {
    $ipaddress = $confs.SYSLOG_IPADDRESS.Split(",")
    foreach ($address in $ipaddress){
        $IP = $address
        $Port = $confs.SYSLOG_PORT
        $File = $confs.TAILFILE

        $Timestamp = Get-Date -Format "yyyy/MM/dd HH:mm:ss"

        # Set the Message
        $FullSyslogMessage = "<{0}>{1} {2} {3}" -f $Priority, $Timestamp, $Hostname, $Body

        # Create an UTF-8 Encoding object
        $Encoding = [System.Text.Encoding]::UTF8
 
        # Convert into byte array representation
        $ByteSyslogMessage = $Encoding.GetBytes($FullSyslogMessage)
 
        #If the message is too long, shorten it
        if ($ByteSyslogMessage.Length -gt 1024){
            $ByteSyslogMessage = $ByteSyslogMessage.SubString(0, 1024)
        }
 
        # Create a UDP Client Object
        $UDPCLient = New-Object System.Net.Sockets.UdpClient
        $UDPCLient.Connect($IP, $Port)

        # Send the Message
        $resul = $UDPCLient.Send($ByteSyslogMessage, $ByteSyslogMessage.Length)
    }
}

# Main
if ([System.Diagnostics.EventLog]::SourceExists("SyslogSendUDP_event_source") -eq $false){
    New-EventLog -LogName Application -Source SyslogSendUDP_event_source
} 
Write-EventLog -LogName Application -Source SyslogSendUDP_event_source -EventId 1001 -EntryType Information -Message "SyslogSendUDP start."
$num = 0

# Check target log
$targetfile = $confs.TAILFILE
if (Test-Path $targetfile) {
    } else {
        Write-EventLog -LogName Application -Source SyslogSendUDP_event_source -EventId 1002 -EntryType Warn -Message "log file not found. $targetfile"
        exit
    }

# Check countfile
$countfile = $confs.COUNTLOG
if (Test-Path $countfile) {
    } else {
        $create = New-Item $countfile -itemType File -Value "0"
    }

# Target count
$Tailnum = TargetLength $confs.TAILFILE $countfile
[int]$num = $Tailnum[0]

# File read
$ReadResult = ReadFile $num

# syslog send
foreach ($messages in $ReadResult){
    SyslogSend $messages
}
Write-EventLog -LogName Application -Source SyslogSendUDP_event_source -EventId 1001 -EntryType Information -Message "$num message sent."
Write-EventLog -LogName Application -Source SyslogSendUDP_event_source -EventId 1001 -EntryType Information -Message "SyslogSendUDP end."

#Remove-EventLog -Source SyslogSendUDP_event_source
#Remove-Variable messages, ReadResult, num, Tailnum, countfile, confs, currentnum, Tailnum, ipaddress, IP, Port, File, Timestamp, FullSyslogMessage

