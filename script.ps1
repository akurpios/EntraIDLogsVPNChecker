#Wipe terminal
cls

#Echo
echo "----------------------------------"
echo "EntraID SignIn Logs VPN checker for VPNAPI.IO"
echo "By Aleksander Kurpios"
echo "----------------------------------"


#Create Varibles
$CurrentDate = get-date -f dd-MM-yyyy_THH-mm-ss #Get Current date and time
$AllIPsArray = @() # wipe All IPs Array table
$UniqueIPsArray = @() # wipe Unique IPs Array table
$APIKey = Read-Host -Prompt "Enter your VPNAPI.io API Key: " #Prompt for VPNAPI.io API Key

$MScsvPath = Read-Host -Prompt "Enter your Microsoft report CSV path without quotes: " #Prompt for RAW InteractiveSignIns export file
$RootdirectoryPath = Split-Path -Path $MScsvPath #Get RAW InteractiveSignIns file location
New-Item -Path $RootdirectoryPath -Name $CurrentDate -ItemType "directory" #Create new folder for this job
$directoryPath = "$RootdirectoryPath\$CurrentDate" #Set work folder
Write-host "`n`nDirectory path: " $directoryPath "`n`n" #Display work folder
$TempMScsvPath = "$directoryPath\TempRaw-$CurrentDate.csv" #Set location for Temp CSV
$TranscriptPatch = "$directoryPath\MsLogsVPNchecker-REPORT$CurrentDate.txt" #Set location for transcript
$RawOutPath = "$directoryPath\TempResolvedIPs-$CurrentDate.csv"
$UniqueTempMScsvPath = "$directoryPath\UniqueTempRaw-$CurrentDate.csv" #Set location for Temp Unique IPs CSV
$OutPath = "$directoryPath\ResolvedIPs-$CurrentDate.csv" #Set OutPath
$Progress = 1 #Wipe Progress bar status

#Start transcript
Start-Transcript -Path $TranscriptPatch

# Replace "Incoming token type" with "Token" in a file
$OldfirstLine = Get-Content -Path $MScsvPath | Select-Object -First 1
[regex]$pattern = "Incoming token type"
$NewfirstLine = $pattern.replace($OldfirstLine, "Token", 1) 

#Replace "IP Address" with "IP" in file
$NewfirstLine = $NewfirstLine.Replace("IP address","IP")
#Replace "IP Address" with "IP" in file
$NewfirstLine = $NewfirstLine.Replace("Date (UTC)","Date")

#Replace 1st line of string
$x = Get-Content $MScsvPath
$x[0] = $NewfirstLine
$x | Out-File $TempMScsvPath

#Remove duplicated IPs from Fixed CSV
Import-Csv $TempMScsvPath | Sort-Object "IP" -Unique | Export-Csv -Path $UniqueTempMScsvPath

#Checking size of unique IP list

$CountOfUniqueIPs = (Get-Content $UniqueTempMScsvPath | Measure-Object -Line).Lines
$CountOfUniqueIPs = $CountOfUniqueIPs

#Checking Unique IPs
Import-Csv $UniqueTempMScsvPath | ForEach-Object { 
    $Progress++
    $Date = $_.Date
    $IP = $_.IP
    $Username = $_.Username
    $URL = "https://vpnapi.io/api/"+$IP+"?key="+$APIKey
    $Curl = Invoke-RestMethod -Uri $URL
    write-host "Working for: "$IP
    echo $Curl

    [PsCustomObject]@{
        "Date (UTC)" = $Date;
        username = $Username;
        IP = $IP;
        VPN = $Curl.security.vpn;
        TOR = $Curl.security.tor;
        Country = $Curl.location.country;
        ISP = $Curl.network.autonomous_system_organization;

    } | Export-Csv $RawOutPath -NoTypeInformation -append

     Write-Progress -activity "Checking Unique IPs" -status "Scanned: $Progress of $($CountOfUniqueIPs)" -percentComplete (($Progress / $CountOfUniqueIPs)  * 100)
}

#Remove duplicates from Exported CSV (Multiple header lines)
Import-Csv (Get-ChildItem $RawOutPath) | Sort-Object -Unique IP | Export-Csv $OutPath -NoClobber -NoTypeInformation

#Check if Final CSV is correct
$FinalCSVsize = (Get-Content $OutPath | Measure-Object -Line).Lines

Write-Host "Final file size: " $FinalCSVsize
Write-Host "Unique entries: " $CountOfUniqueIPs

if ($FinalCSVsize -eq $CountOfUniqueIPs) {
    Write-Host "Final CSV is correct" -BackgroundColor Green
}
else {
    Write-Host "Final CSV is incorrect" -BackgroundColor Red
}

#Ask if user want to keep temp files
$DeleteTemp = Read-Host "Want to keep temp files [y/n]"
while($DeleteTemp -ne "y")
{
    if ($DeleteTemp -eq 'n') {    
      Write-Host "Removing temp files" -BackgroundColor DarkYellow
      Remove-Item -Path $RawOutPath
      Remove-Item -Path $TempMScsvPath
      Remove-Item -Path $UniqueTempMScsvPath
      break
      }
  Write-Host "Keeping temp files" -BackgroundColor DarkYellow
}

#Ask if user want to open export location
$DeleteTemp = Read-Host "Want to open export location [y/n]"
while($DeleteTemp -ne "n")
{
    if ($DeleteTemp -eq 'y') {  
        Write-Host "Opening export location" -BackgroundColor DarkYellow  
        ii $directoryPath
      }
      break
}

Write-Host "Script Finished"
Stop-Transcript
