
#Wipe terminal
cls

#Echo
echo "----------------------------------"
echo "EntraID Logs VPN checker for VPNAPI.IO"
echo "By Aleksander Kurpios"
echo "----------------------------------"

#Create Variables
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
$OutPath = "$directoryPath\ResolvedIPs-$CurrentDate.csv" #Set OutPath
$Progress = 0 #Wipe Progress bar status

#Start transcript
Start-Transcript -Path $TranscriptPatch

# Replace "Incoming token type" with "Token" in a file
$OldfirstLine = Get-Content -Path $MScsvPath | Select-Object -First 1
[regex]$pattern = "Incoming token type"
$NewfirstLine = $pattern.replace($OldfirstLine, "Token", 1) 

#Replace "IP Address" with "IP" in the file
$NewfirstLine = $NewfirstLine.Replace("IP address","IP")

#Replace 1st line of string
$x = Get-Content $MScsvPath
$x[0] = $NewfirstLine
$x | Out-File $TempMScsvPath

#Import Fixed CSV and add to Array to get only Unique IPs
Import-Csv -Path $TempMScsvPath | ForEach-Object {
    $IP = $_.IP
    $AllIPsArray += $IP 
}
$CountOfAllIPs = $AllIPsArray.Count
Write-Host "All entries: " $CountOfAllIPs
$UniqueIPsArray = $AllIPsArray | Select-Object -Unique
$CountOfUniqueIPs = $UniqueIPsArray.Count
Write-Host "Unique entries: " $CountOfUniqueIPs

#Checking Unique IPs
ForEach ($UniqueIP in $UniqueIPsArray){
  $URL= "https://vpnapi.io/api/"+$UniqueIP+"?key="+$APIKey

  #Obtain VPN data
  Invoke-RestMethod -Uri $URL | ConvertTo-Csv >> $RawOutPath -NoTypeInformation
  $Progress++
   Write-Progress -activity "Checking Unique IPs" -status "Scanned: $Progress of $($CountOfUniqueIPs)" -percentComplete (($Progress / $CountOfUniqueIPs)  * 100)
}

#Remove duplicates from Exported CSV
 Import-Csv (Get-ChildItem $RawOutPath) | Sort-Object -Unique ip | Export-Csv $OutPath -NoClobber -NoTypeInformation

#Remove last line in final CSV
$data = Get-Content $OutPath
$data[0..($data.count-2)] | Out-File $OutPath

#Check if the Final CSV is correct
$FinalCSVsize = (Get-Content $OutPath | Measure-Object -Line).Lines
$FinalCSVsize = $FinalCSVsize-1

Write-Host "Final file size: " $FinalCSVsize
Write-Host "Unique entries: " $CountOfUniqueIPs

if ($FinalCSVsize -eq $CountOfUniqueIPs) {
    Write-Host "Final CSV is correct" -BackgroundColor Green
}
else {
    Write-Host "Final CSV is incorrect" -BackgroundColor Red
}

#Ask if the user wants to keep temp files
$DeleteTemp = Read-Host "Want to keep temp files [y/n]"
while($DeleteTemp -ne "y")
{
    if ($DeleteTemp -eq 'n') {    
      Write-Host "Removing temp files" -BackgroundColor DarkYellow
      Remove-Item -Path $RawOutPath
      Remove-Item -Path $TempMScsvPath
      exit
      }
  Write-Host "Keeping temp files" -BackgroundColor DarkYellow
}

Write-Host "Script Finished"
#pause
Stop-Transcript
