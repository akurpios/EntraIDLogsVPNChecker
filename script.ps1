#Wipe terminal
cls

#Echo
echo "----------------------------------"
echo "EntraID SignIn Logs VPN checker for VPNAPI.IO"
echo "By Aleksander Kurpios"
echo "----------------------------------"
#Ask if user want to autogenerate SignIn logs or use manually exported file
do{
    $autogeneratelogs = Read-Host "Want to auto-generate SignIn logs? (EntraID login required) [y/n]"
    if ($autogeneratelogs -eq 'n'){
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
        $Progress = 0 #Wipe Progress bar status
        $ScriptGeneratedMScsvPath = "$directoryPath\GeneratedRawMsSignIns-$CurrentDate.csv" #Set location for the Script-generated Ms sign-in logs
        $TempScriptGeneratedMScsvPath = "$directoryPath\TempGeneratedRawMsSignIns-$CurrentDate.csv" #Set location for the Script-generated Ms sign-in logs

        #Start transcript
        Start-Transcript -Path $TranscriptPatch

        # Replace "Incoming token type" with "Token" in a file
        $OldfirstLine = Get-Content -Path $MScsvPath | Select-Object -First 1
        [regex]$pattern = "Incoming token type"
        $NewfirstLine = $pattern.replace($OldfirstLine, "Token", 1) 

        #Replace "IP Address" with "IP" in file
        $NewfirstLine = $NewfirstLine.Replace("IP address","IP")
        #Replace "Date (UTC)" with "Date" in file
        $NewfirstLine = $NewfirstLine.Replace("Date (UTC)","Date")
        #Replace "Operating System" with "OS" in file
        $NewfirstLine = $NewfirstLine.Replace("Operating System","OS")

        #Replace 1st line of string
        $x = Get-Content $MScsvPath
        $x[0] = $NewfirstLine
        $x | Out-File $TempMScsvPath

        #Remove duplicated IPs from Fixed CSV
        Import-Csv $TempMScsvPath | Sort-Object "IP" -Unique | Export-Csv -Path $UniqueTempMScsvPath
        $CountOfUniqueIPs = (Get-Content $UniqueTempMScsvPath | Measure-Object -Line).Lines
        Break
    }
    if ($autogeneratelogs -eq 'y') {
        #Create Varibles
        $CurrentDate = get-date -f dd-MM-yyyy_THH-mm-ss #Get Current date and time
        $AllIPsArray = @() # wipe All IPs Array table
        $UniqueIPsArray = @() # wipe Unique IPs Array table
        $APIKey = Read-Host -Prompt "Enter your VPNAPI.io API Key: " #Prompt for VPNAPI.io API Key
        $RootdirectoryPath = (Get-Location).path
        New-Item -Path $RootdirectoryPath -Name $CurrentDate -ItemType "directory" #Create new folder for this job
        $directoryPath = "$RootdirectoryPath\$CurrentDate" #Set work folder
        Write-host "`n`nDirectory path: " $directoryPath "`n`n" #Display work folder
        $TempMScsvPath = "$directoryPath\TempRaw-$CurrentDate.csv" #Set location for Temp CSV
        $TranscriptPatch = "$directoryPath\MsLogsVPNchecker-REPORT$CurrentDate.txt" #Set location for transcript
        $RawOutPath = "$directoryPath\TempResolvedIPs-$CurrentDate.csv"
        $UniqueTempMScsvPath = "$directoryPath\UniqueTempRaw-$CurrentDate.csv" #Set location for Temp Unique IPs CSV
        $OutPath = "$directoryPath\ResolvedIPs-$CurrentDate.csv" #Set OutPath
        $Progress = 1 #Wipe Progress bar status
        $ScriptGeneratedMScsvPath = "$directoryPath\GeneratedRawMsSignIns-$CurrentDate.csv" #Set location for the Script-generated Ms sign-in logs
        $TempScriptGeneratedMScsvPath = "$directoryPath\TempGeneratedRawMsSignIns-$CurrentDate.csv" #Set location for the Script-generated Ms sign-in logs

        #Start transcript
        Start-Transcript -Path $TranscriptPatch

        #Check Platform
        if ($PSVersionTable.Platform -eq 'Unix')
        {
            Write-host "This part works only on Windows machines. Sorry." -BackgroundColor Red
            Pause
            Exit
        }
        
        #Check if AzureAD module is installed
        if(-not (Get-Module AzureADPreview -ListAvailable)){
            Write-host "AzureADPreview Module is not installed. Installing" -BackgroundColor DarkYellow
            try{
                Install-Module AzureADPreview -Scope CurrentUser -Force
            } catch {
            Write-Host "AzureADPreview module installtion not success. Please try starting PowerShell as Admin`r`n" -BackgroundColor Red
            }
        }
        else{
            Write-host "AzureADPreview Module is already installed." -BackgroundColor Green
        }
        
        #Prompt user to type in how many days should be fetched
        Do {
            $DaysToFetch = Read-Host -Prompt "Enter how many days should be obtained (1-30): " #Prompt for RAW InteractiveSignIns export file
        } while($DaysToFetch -notin 0..30)
        
        #Import and Connect to AzureAD
        Import-Module AzureADPreview
        Connect-AzureAD
        $SetDate = (Get-Date).AddDays(-$DaysToFetch);
        $SetDate = Get-Date($SetDate) -format yyyy-MM-dd

        #Get AzureAD data
        $AADLogsarray = Get-AzureADAuditSignInLogs -Filter "createdDateTime gt $SetDate" | Select CreatedDateTime, UserPrincipalName, IpAddress,@{Name = 'OS'; Expression = {$_.DeviceDetail.OperatingSystem}}
        $AADLogsarray | Export-Csv $ScriptGeneratedMScsvPath –NoTypeInformation
        Disconnect-AzureAD
        
        #Get First line of exported file
        $NewfirstLine = Get-Content -Path $ScriptGeneratedMScsvPath | Select-Object -First 1

        #Replace "IpAddress" with "IP" in file
        $NewfirstLine = $NewfirstLine.Replace("IpAddress","IP")
        #Replace "CreatedDateTime" with "Date" in file
        $NewfirstLine = $NewfirstLine.Replace("CreatedDateTime","Date")
        #Replace "UserPrincipalName" with "Username" in file
        $NewfirstLine = $NewfirstLine.Replace("UserPrincipalName","Username")


        #Replace 1st line of string
        $x = Get-Content $ScriptGeneratedMScsvPath
        $x[0] = $NewfirstLine
        $x | Out-File $TempScriptGeneratedMScsvPath

        #Remove duplicated IPs from Fixed CSV
        Import-Csv $TempScriptGeneratedMScsvPath | Sort-Object "IP" -Unique | Export-Csv -Path $UniqueTempMScsvPath
        $CountOfUniqueIPs = (Get-Content $UniqueTempMScsvPath | Measure-Object -Line).Lines
        $CountOfUniqueIPs = $CountOfUniqueIPs-1
        Break
    }
} while ($autogeneratelogs -ne 'y' -or $autogeneratelogs -ne 'n')

#Checking size of unique IP list



#Checking Unique IPs
Import-Csv $UniqueTempMScsvPath | ForEach-Object { 
    $Progress++
    $Date = $_.Date
    $IP = $_.IP
    $Username = $_.Username
    $OS = $_.OS
    write-host "Working for: "$IP
    $URL = "https://vpnapi.io/api/"+$IP+"?key="+$APIKey
    Try {
        $Curl = Invoke-RestMethod -Uri $URL
    } Catch {
        $RAWAPIerror = $_.ErrorDetails.Message | ConvertFrom-Json
        $APIerror = $RAWAPIerror.message
        if($APIerror | Select-String -Pattern "maximum|daily|limit") {
            Write-host "You have exceeded the maximum daily limit for this API key. Please upgrade your plan or use different API Key." -BackgroundColor Red
        }
        if($APIerror | Select-String -Pattern "invalid|API|key") {
            Write-host "Invalid API key." -BackgroundColor Red
        }
        else {
            Write-host "There was some API problem." -BackgroundColor Red
            Write-Host $_
        }
        Pause
        Exit
    }
    echo $Curl

    [PsCustomObject]@{
        "Date (UTC)" = $Date;
        username = $Username;
        IP = $IP;
        OS = $OS;
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
      if (Test-Path -Path $RawOutPath) {
          Remove-Item -Path $RawOutPath
      } else{}
        if (Test-Path -Path $TempMScsvPath) {
          Remove-Item -Path $TempMScsvPath
      } else{}
      if (Test-Path -Path $UniqueTempMScsvPath) {
          Remove-Item -Path $UniqueTempMScsvPath
      } else{}
      if (Test-Path -Path $TempScriptGeneratedMScsvPath) {
          Remove-Item -Path $TempScriptGeneratedMScsvPath
      } else{}
       if (Test-Path -Path $ScriptGeneratedMScsvPath) {
          Remove-Item -Path $ScriptGeneratedMScsvPath
      } else{}
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
Pause
Stop-Transcript
