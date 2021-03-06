#Get Variables --
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
#$creds=Get-Credential -Message "Enter domain admin credentials in the form NETBIOS/USERNAME" -Username $currentUser
$creds=Read-Host -Prompt "Enter your Domain Admin password" -AsSecureString
#$user=$creds.UserName
$pass=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($creds))
$serverName=(Get-WmiObject Win32_ComputerSystem).Name
$serverList=@(((Read-host -Prompt 'Enter names of all other servers to install agent to (comma separated)').Split(",")).Trim())
$id=Read-Host -Prompt 'Azure Sentinel Workspace ID'
$key=Read-Host -Prompt 'Azure Sentinel Workspace ID Key (PLACE IN DOUBLE QUOTES)'



#Enable TLS1.2 --
write-host "Enabling TLS 1.2 ..." -ForegroundColor Magenta
try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
catch {
  Write-Warning $Error[0].exception.message
}

#create the directory --
write-host "Creating Software Distribution directory ..." -ForegroundColor Magenta
try {
  new-item -itemtype "directory" -path "C:\softwareDistribution\AzureSentinelAgent\Setup" -ErrorAction Stop
}
catch {
  Write-Warning $Error[0].exception.message
}

#share the directory --
write-host "Sharing Software Distribution directory ..." -ForegroundColor Magenta
try {
  New-SmbShare -Name "softwareDistribution" -Path "C:\softwareDistribution\" -FullAccess "everyone" -ErrorAction Stop
}
catch {
  Write-Warning $Error[0].exception.message
}

#Download batch file --
write-host "Downloading Azure Sentinel Agent Batch File ..." -ForegroundColor Magenta
try {
  Invoke-WebRequest -Uri "https://raw.githubusercontent.com/EpsilonSupport/SentinelTest/master/Install-AzureSentinel.bat" -outfile "C:\softwareDistribution\AzureSentinelAgent\Install-AzureSentinel.bat" -ErrorAction Stop
}
catch {
  Write-Warning $Error[0].exception.message
}

#Download zip file --
write-host "Downloading Azure Sentinel Agent Setup files ..." -ForegroundColor Magenta
try {
  If(Test-Path -LiteralPath 'C:\softwareDistribution\AzureSentinelAgent\AzureSentinelAgentSetup.zip'){
    write-host "Already downloaded..." -ForegroundColor Magenta
  }
  Else {
    try {
      Invoke-WebRequest -Uri "https://github.com/EpsilonSupport/SentinelTest/releases/download/v1.1/AzureSentinelAgentSetup.zip" -outfile "C:\softwareDistribution\AzureSentinelAgent\AzureSentinelAgentSetup.zip" -ErrorAction Stop
    }
    catch {
      Write-Warning $Error[0].exception.message
    }
  }
}
catch {
  Write-Warning $Error[0].exception.message
}

#EXTRACT AzureSentinelAgentSetup.zip -- 
write-host "Extracting ZIP to C:\softwareDistribution\AzureSentinelAgent\Setup ..." -ForegroundColor Magenta
try {
  If(Test-Path -LiteralPath 'C:\softwareDistribution\AzureSentinelAgent\Setup\setup.exe'){
    write-host "Already Unzipped..." -ForegroundColor Magenta
  }
  else {
    if (Get-Command Expand-Archive -errorAction SilentlyContinue){
      try {
        Expand-Archive -LiteralPath "C:\softwareDistribution\AzureSentinelAgent\AzureSentinelAgentSetup.zip" -DestinationPath "C:\softwareDistribution\AzureSentinelAgent\Setup" -ErrorAction Stop
      }
      catch {
        Write-Warning $Error[0].exception.message
      }
    }
    else {
      write-warning "Expand-Archive cmdlet not available - please manually unzip AzureSentinelAgentSetup.zip to C:\softwareDistribution\AzureSentinelAgent\Setup and re-run this script."
    }
  }
}
catch {
  Write-Warning $Error[0].exception.message
}

#Mounting Drive --
write-host "Mounting Drive ..." -ForegroundColor Magenta
try {
  net use X: \\$serverName\softwareDistribution\AzureSentinelAgent
}
catch {
  Write-Warning $Error[0].exception.message
}

#Installing Agent --
write-host "Installing Agent ..." -ForegroundColor Magenta
try {
  X:\Install-AzureSentinel.bat $id $key
}
catch {
  Write-Warning $Error[0].exception.message
}

#Unmounting Drive
write-host "Unmounting Drive ..." -ForegroundColor Magenta
try {
  net use x: /d
}
catch {
  Write-Warning $Error[0].exception.message
}

#Install to other servers
write-host "Installing Agent to servers in list provided..." -ForegroundColor Cyan
try {
  foreach($server in $serverList){
    Write-Host "Starting install process on"$server -ForegroundColor Green;
    try {
        Invoke-Command -ComputerName $server -ScriptBlock {
            Write-Host "Mounting Drive on"$using:server -ForegroundColor Magenta;
            & net use X: \\$using:serverName\softwareDistribution\AzureSentinelAgent /user:$using:currentUser $using:pass
            Write-Host "Installing Agent on"$using:server -ForegroundColor Magenta;
            & X:\Install-AzureSentinel.bat $using:id $using:key;
            Write-Host "Unmounting Drive on"$using:server -ForegroundColor Magenta;
            & net use X: /d
        }
    }
    catch {
        Write-Warning $Error[0].exception.message    
    }
  }
}
catch {
  Write-Warning $Error[0].exception.message
}

