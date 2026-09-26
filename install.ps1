# ============================================================================
# 0. SETUP AND FUNCTIONS (Smart Kill & Progress Info)
# ============================================================================
# Enforce TLS 1.2 to ensure downloads from GitHub work on all Windows versions
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# FUNCTION 1: Intelligent Steam shutdown (Smart Kill)
function Stop-SteamSmart {
    Write-Host "  [*] Checking Steam process..." -ForegroundColor DarkGray
    $steamProcess = Get-Process -Name "steam" -ErrorAction SilentlyContinue
    
    if ($steamProcess) {
        Write-Host "  [*] Closing Steam application..." -ForegroundColor DarkGray
        Stop-Process -Name "steam" -Force -ErrorAction SilentlyContinue
        
        $timeout = 15
        $timer = 0
        
        # Wait until Steam process completely disappears, max 15 seconds
        while ((Get-Process -Name "steam" -ErrorAction SilentlyContinue) -and ($timer -lt $timeout)) {
            Start-Sleep -Seconds 1
            $timer++
        }
        
        if ($timer -ge $timeout) {
            Write-Host "  [!] Warning: Steam took too long to close, proceeding anyway..." -ForegroundColor Yellow
        }
    }
    
    # Small pause to release file locks in Windows
    Start-Sleep -Seconds 1
}

# FUNCTION 2: File download with Percentage and File Size
function Download-WithProgress {
    param (
        [string]$Url,
        [string]$Destination,
        [string]$FileName
    )
    
    # Disable default PowerShell progress bar to avoid visual glitches
    $ProgressPreference = 'SilentlyContinue'
    
    $webRequest = $null
    $response = $null
    $responseStream = $null
    $targetStream = $null
    
    try {
        $webRequest = [System.Net.WebRequest]::Create($Url)
        $response = $webRequest.GetResponse()
        $totalBytes = $response.ContentLength
        $responseStream = $response.GetResponseStream()
        $targetStream = [System.IO.File]::Create($Destination)
        $buffer = New-Object byte[] 8192
        $bytesRead = 0
        $totalDownloaded = 0
        
        # Calculate file size in Megabytes and round to 2 decimal places
        $totalMB = [math]::Round($totalBytes / 1MB, 2)
        
        # Loop for reading stream chunks and drawing the text
        do {
            $bytesRead = $responseStream.Read($buffer, 0, $buffer.Length)
            if ($bytesRead -gt 0) {
                $targetStream.Write($buffer, 0, $bytesRead)
                $totalDownloaded += $bytesRead
                
                if ($totalBytes -gt 0) {
                    $percent = [math]::Floor(($totalDownloaded / $totalBytes) * 100)
                    $formattedPercent = $percent.ToString().PadLeft(3)
                    
                    # `r returns carriage to the beginning of the line to overwrite text
                    Write-Host "`r      Downloading... $formattedPercent% (File Size: $totalMB MB) " -NoNewline -ForegroundColor White
                }
            }
        } while ($bytesRead -gt 0)
        
        Write-Host "`n  [+] Success: Saved $($FileName)`n" -ForegroundColor Green
    }
    catch {
        Write-Host "`n    [-] Error during download $($FileName): $($_.Exception.Message)`n" -ForegroundColor Red
    }
    finally {
        # Release files so they can be used
        if ($targetStream) { $targetStream.Dispose() }
        if ($responseStream) { $responseStream.Dispose() }
        if ($response) { $response.Dispose() }
    }
}

# FUNCTION 3: Unifikowana instalacja i synchronizacja wersji plików
function Install-HyaroVersion {
    param (
        [string]$VersionTag,
        [string[]]$Urls,
        [hashtable]$Hashes,
        [string]$TargetFolder,
        [string]$ExecutablePath
    )

    Clear-Host
    Write-Host "=================== INSTALLATION INFO ($VersionTag) ===================" -ForegroundColor Yellow
    Write-Host "Please read the following information carefully:`n" -ForegroundColor White
    
    Write-Host "Proceeding with this installation will:" -ForegroundColor White
    Write-Host "1. Forcefully close your Steam application." -ForegroundColor Gray
    Write-Host "2. Download the required .DLL files ($VersionTag) from the server." -ForegroundColor Gray
    Write-Host "3. Install them directly into your main Steam directory." -ForegroundColor Gray
    Write-Host "4. Automatically start Steam application.`n" -ForegroundColor Gray
    
    Write-Host "Do you wish to proceed? [Y] Yes / [N] No: " -NoNewline -ForegroundColor Yellow
    
    $confirmKey = [System.Console]::ReadKey($true)
    $confirm = $confirmKey.KeyChar.ToString().ToUpper()

    if ($confirm -eq "Y") {
        Clear-Host
        $downloadQueue = @()
        
        foreach ($url in $Urls) {
            $name = Split-Path $url -Leaf
            $destination = Join-Path -Path $TargetFolder -ChildPath $name
            $expectedHash = $Hashes[$name]

            if (-not (Test-Path -Path $destination)) {
                $downloadQueue += [PSCustomObject]@{ Name = $name; Url = $url; Reason = "Missing" }
            } 
            else {
                $currentHash = (Get-FileHash -Path $destination -Algorithm SHA256).Hash
                if ($currentHash -ne $expectedHash) {
                    $downloadQueue += [PSCustomObject]@{ Name = $name; Url = $url; Reason = "Mismatch" }
                }
            }
        }

        if ($downloadQueue.Count -eq 0) {
            Clear-Host
            Write-Host " =========================================================" -ForegroundColor Red
            Write-Host "                  V E R S I O N   C H E C K               " -ForegroundColor White
            Write-Host " =========================================================" -ForegroundColor Red
            Write-Host "`n  [!] You already have the latest $VersionTag version installed!" -ForegroundColor Yellow
            Write-Host "  [*] No files need to be downloaded or updated.`n" -ForegroundColor DarkGray
            
            Read-Host "  Press the ENTER key to return to the menu"
        } 
        else {
            Write-Host " =========================================================" -ForegroundColor Red
            Write-Host "            S Y N C H R O N I Z I N G   F I L E S         " -ForegroundColor White
            Write-Host " =========================================================" -ForegroundColor Red
            Write-Host ""

            Stop-SteamSmart

            foreach ($item in $downloadQueue) {
                if ($item.Reason -eq "Missing") {
                    Write-Host "  [!] Missing File Detected: $($item.Name)" -ForegroundColor Yellow
                } 
                elseif ($item.Reason -eq "Mismatch") {
                    Write-Host "  [!] Outdated/Changed Version Detected: $($item.Name)" -ForegroundColor Yellow
                }
                
                $destination = Join-Path -Path $TargetFolder -ChildPath $item.Name
                Download-WithProgress -Url $item.Url -Destination $destination -FileName $item.Name
            }
            
            Write-Host "  [*] Installation of required files completed." -ForegroundColor DarkGray
            Write-Host "  [*] Starting Steam..." -ForegroundColor DarkGray
            Start-Process -FilePath $ExecutablePath
            
            Write-Host "`n  [+] Files successfully updated to version $VersionTag!" -ForegroundColor Green
            
            Read-Host "`n  Press the ENTER key to return to the menu"
        }
    } 
    else {
        Write-Host "`n`nOperation canceled. Returning to main menu..." -ForegroundColor DarkGray
        Start-Sleep -Seconds 2
    }
}

# ============================================================================
# 1. ADMINISTRATOR PRIVILEGES CHECK
# ============================================================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "=============================================================================" -ForegroundColor Red
    Write-Host "        Administrator permissions are required to use this command.          " -ForegroundColor Red
    Write-Host "     Please run PowerShell as Administrator and paste the command again.     " -ForegroundColor Yellow
    Write-Host "=============================================================================" -ForegroundColor Red
    
    Read-Host "Press the ENTER key to close this window"
    exit
}

# ============================================================================
# 2. GET STEAM PATH & DEFINE FILES
# ============================================================================
$steamRegPath = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction SilentlyContinue

if (-not $steamRegPath) {
    Write-Host "Error: Steam installation not found in the registry." -ForegroundColor Red
    Read-Host "Press the ENTER key to close this window"
    exit
}

$steamPath = $steamRegPath.SteamPath -replace "/", "\"
$steamExe = Join-Path -Path $steamPath -ChildPath "steam.exe"

# List of file names only (needed for uninstallation and verification)
$dllNames = @(
    "dwmapi.dll",
    "hyaroscript.dll",
    "OnlineFix.dll",
    "xinput1_4.dll"
)

# ----------------- CONFIGURATION: VERSION v1.2 (STABLE) -----------------
$dllUrlsV12 = @(
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/dwmapi.dll",
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/hyaroscript.dll",
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/OnlineFix.dll",
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/xinput1_4.dll"
)

$dllHashesV12 = @{
    "dwmapi.dll"      = "0a2583ce3fe1f400f93ee5bcc2a4c89c0e9830d6ea10e31beb1bd0b0108edff0"
    "hyaroscript.dll" = "fe164a25fc457b1117e20789e790e7091bb7a05953c78d83ea38b0c5daf59594"
    "OnlineFix.dll"   = "fd20bc209b6a3cdf4cce468bf5ea98c6d8839c16254fcbba0e4bd7ffb40a089e"
    "xinput1_4.dll"   = "b56d642415ce57d0a4345d41490985bab3c05a44001eec1e9dd6405fd2674932"
}

# ----------------- CONFIGURATION: VERSION v1.3 (BETA) -------------------
# Poniżej możesz zmienić linki, jeśli pliki wersji beta są pod innym adresem
$dllUrlsV13Beta = @(
    "https://github.com/hyaroz/hyaroscript/releases/download/v1.3_Beta/dwmapi.dll",
    "https://github.com/hyaroz/hyaroscript/releases/download/v1.3_beta/hyaroscript.dll",
    "https://github.com/hyaroz/hyaroscript/releases/download/v1.3_beta/OnlineFix.dll",
    "https://github.com/hyaroz/hyaroscript/releases/download/v1.3_beta/xinput1_4.dll"
)

# Podmień poniższe wartości SHA256 na swoje docelowe sumy kontrolne dla v1.3:
$dllHashesV13Beta = @{
    "dwmapi.dll"      = "47916edcfe6b1a4e5a4e594d29bf632e86d1a6248eedaa4b5c5fd4c893a7da81"
    "hyaroscript.dll" = "f16ebe36ff19d6db24af34f6dfdeaf40fa54df6e620a422f9714818ff174b894"
    "OnlineFix.dll"   = "e7b2df92ccd5ec14077dc04525729feed2189eb5750ab21754c3439e8cbf81ae"
    "xinput1_4.dll"   = "0117947323e4233afb9e7cd1963c37e691c251420844537eb049967dea0e2cbc"
}

# ============================================================================
# 3. MAIN MENU (Loop that repeats until the user chooses the exit option)
# ============================================================================
while ($true) {
    Clear-Host
    
    # ASCII Art Logo
    Write-Host "   _   _ __   __  _    ____   ___  ____   ____ ____  ___ ____ _____ " -ForegroundColor Red
    Write-Host "  | | | |\ \ / / / \  |  _ \ / _ \/ ___| / ___|  _ \|_ _|  _ \_   _|" -ForegroundColor Red
    Write-Host "  | |_| | \ V / / _ \ | |_) | | | \___ \| |   | |_) || || |_) || |  " -ForegroundColor Red
    Write-Host "  |  _  |  | | / ___ \|  _ <| |_| |___) | |___|  _ < | ||  __/ | |  " -ForegroundColor Red
    Write-Host "  |_| |_|  |_|/_/   \_\_| \_\\___/|____/ \____|_| \_\___|_|    |_|  " -ForegroundColor Red
    Write-Host "  |___________ P O W E R S H E L L   I N S T A L L E R ____________| " -ForegroundColor White
    Write-Host ""
    Write-Host "  Found Steam folder: $steamPath" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [1] Download and install Stable .DLL files (v1.2)" -ForegroundColor White
    Write-Host "  [2] Download and install Beta .DLL files (v1.3)" -ForegroundColor White
    Write-Host "  [3] Uninstall .DLL files from the Steam folder" -ForegroundColor White
    Write-Host "  [4] Exit" -ForegroundColor White
    Write-Host ""
    Write-Host ""
    
    Write-Host "  Select option (1-4): " -NoNewline -ForegroundColor Yellow
    
    $key = [System.Console]::ReadKey($true)
    $choice = $key.KeyChar.ToString()

    switch ($choice) {
        
        # OPTION 1: INSTALL STABLE v1.2
        "1" {
            Install-HyaroVersion -VersionTag "v1.2" -Urls $dllUrlsV12 -Hashes $dllHashesV12 -TargetFolder $steamPath -ExecutablePath $steamExe
        }

        # OPTION 2: INSTALL BETA v1.3
        "2" {
            Install-HyaroVersion -VersionTag "v1.3-BETA" -Urls $dllUrlsV13Beta -Hashes $dllHashesV13Beta -TargetFolder $steamPath -ExecutablePath $steamExe
        }
        
        # OPTION 3: UNINSTALLATION
        "3" {
            Clear-Host
            
            Write-Host "======================== UNINSTALLATION WARNING =========================" -ForegroundColor Yellow
            Write-Host "Please read the following information carefully:`n" -ForegroundColor White
            
            Write-Host "Proceeding with this uninstallation will:" -ForegroundColor White
            Write-Host "1. Forcefully close your Steam application." -ForegroundColor Gray
            Write-Host "2. Permanently delete specific files from your Steam directory:" -ForegroundColor Gray
            Write-Host "   (dwmapi.dll, hyaroscript.dll, OnlineFix.dll, xinput1_4.dll)`n" -ForegroundColor Gray
            
            Write-Host "WARNING: You will lose access to all your buyed games from Hyaro's Shop`n" -ForegroundColor Red
            
            Write-Host "Are you sure you want to completely remove these files? [Y] Yes / [N] No: " -NoNewline -ForegroundColor Yellow
            
            $confirmKey = [System.Console]::ReadKey($true)
            $confirm = $confirmKey.KeyChar.ToString().ToUpper()

            if ($confirm -eq "Y") {
                Clear-Host
                
                Write-Host " ========================================================" -ForegroundColor Red
                Write-Host "             U N I N S T A L L I N G   F I L E S          " -ForegroundColor White
                Write-Host " ========================================================" -ForegroundColor Red
                Write-Host ""
                
                Stop-SteamSmart

                foreach ($name in $dllNames) {
                    $destination = Join-Path -Path $steamPath -ChildPath $name
                    
                    if (Test-Path $destination) {
                        Remove-Item -Path $destination -Force
                        Write-Host "  [+] Success: Deleted $($name)" -ForegroundColor Green
                    } else {
                        Write-Host "  [-] Ignoring: $($name) does not exist" -ForegroundColor DarkGray
                    }
                }

                Write-Host "`n  [*] Uninstallation completed." -ForegroundColor DarkGray
                Write-Host "  [*] Starting Steam..." -ForegroundColor DarkGray
                Start-Process -FilePath $steamExe

                Write-Host "`n  [+] Done!" -ForegroundColor Green

                Read-Host "`n  Press the ENTER key to return to the menu"
            } 
            else {
                Write-Host "`n`nOperation canceled. Returning to main menu..." -ForegroundColor DarkGray
                Start-Sleep -Seconds 2
            }
        }
        
        # OPTION 4: EXIT
        "4" {
            exit
        }
        
        # ERROR:
        default {
            Write-Host "`nError: Invalid choice! Press only the number 1, 2, 3, or 4." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}
