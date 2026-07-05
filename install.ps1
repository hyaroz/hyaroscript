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


# ============================================================================
# 1. ADMINISTRATOR PRIVILEGES CHECK
# ============================================================================
# Check if the current PowerShell window has the highest system privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# If the script detects it is NOT running as administrator ($isAdmin is false):
if (-not $isAdmin) {
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host "        Administrator permissions are required to use this command.         " -ForegroundColor Red
    Write-Host "     Please run PowerShell as Administrator and paste the command again.    " -ForegroundColor Yellow
    Write-Host "============================================================================" -ForegroundColor Red
    
    # The script stops here and waits for the user to press ENTER
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

# List of download links
$dllUrls = @(
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/dwmapi.dll",
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/hyaroscript.dll",
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/OnlineFix.dll",
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/xinput1_4.dll"
)

# List of file names only (needed for uninstallation and checking)
$dllNames = @(
    "dwmapi.dll",
    "hyaroscript.dll",
    "OnlineFix.dll",
    "xinput1_4.dll"
)

# SHA256 Hashes for version 1.2 files
$dllHashes = @{
    "dwmapi.dll"      = "0a2583ce3fe1f400f93ee5bcc2a4c89c0e9830d6ea10e31beb1bd0b0108edff0"
    "hyaroscript.dll" = "fe164a25fc457b1117e20789e790e7091bb7a05953c78d83ea38b0c5daf59594"
    "OnlineFix.dll"   = "fd20bc209b6a3cdf4cce468bf5ea98c6d8839c16254fcbba0e4bd7ffb40a089e"
    "xinput1_4.dll"   = "b56d642415ce57d0a4345d41490985bab3c05a44001eec1e9dd6405fd2674932"
}

# ============================================================================
# 3. MAIN MENU (Loop that repeats until the user chooses the exit option)
# ============================================================================
while ($true) {
    # Clear the screen before showing the menu
    Clear-Host
    
    # Draw the new, hacker-style logo (ASCII Art)
    Write-Host "   _   _ __   __  _    ____   ___  ____   ____ ____  ___ ____ _____ " -ForegroundColor Red
    Write-Host "  | | | |\ \ / / / \  |  _ \ / _ \/ ___| / ___|  _ \|_ _|  _ \_   _|" -ForegroundColor Red
    Write-Host "  | |_| | \ V / / _ \ | |_) | | | \___ \| |   | |_) || || |_) || |  " -ForegroundColor Red
    Write-Host "  |  _  |  | | / ___ \|  _ <| |_| |___) | |___|  _ < | ||  __/ | |  " -ForegroundColor Red
    Write-Host "  |_| |_|  |_|/_/   \_\_| \_\\___/|____/ \____|_| \_\___|_|    |_|  " -ForegroundColor Red
    Write-Host "  |___________ P O W E R S H E L L   I N S T A L L E R ____________| " -ForegroundColor White
    Write-Host ""
    Write-Host "  Found Steam folder: $steamPath" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [1] Download and install the latest .DLL files (v1.2)" -ForegroundColor White
    Write-Host "  [2] Uninstall .DLL files from the Steam folder" -ForegroundColor White
    Write-Host "  [3] Exit" -ForegroundColor White
    Write-Host ""
    Write-Host ""
    
    # Catch the key press instantly
    Write-Host "  Select option (1-3): " -NoNewline -ForegroundColor Yellow
    
    # We use a system function to catch a single key without waiting for ENTER
    $key = [System.Console]::ReadKey($true)
    $choice = $key.KeyChar.ToString()

    # Mechanism checking what the user selected
    switch ($choice) {
        
        # OPTION 1: INSTALLATION
        "1" {
            Clear-Host
            
            Write-Host "=================== INSTALLATION INFO ===================" -ForegroundColor Yellow
            Write-Host "Please read the following information carefully:`n" -ForegroundColor White
            
            Write-Host "Proceeding with this installation will:" -ForegroundColor White
            Write-Host "1. Forcefully close your Steam application." -ForegroundColor Gray
            Write-Host "2. Download the required .DLL files from the server." -ForegroundColor Gray
            Write-Host "3. Install them directly into your main Steam directory." -ForegroundColor Gray
            Write-Host "4. Automatically start Steam application.`n" -ForegroundColor Gray
            
            Write-Host "Do you wish to proceed? [Y] Yes / [N] No: " -NoNewline -ForegroundColor Yellow
            
            $confirmKey = [System.Console]::ReadKey($true)
            $confirm = $confirmKey.KeyChar.ToString().ToUpper()

            if ($confirm -eq "Y") {
                
                Clear-Host
                
                $downloadQueue = @()
                
                foreach ($url in $dllUrls) {
                    $name = Split-Path $url -Leaf
                    $destination = Join-Path -Path $steamPath -ChildPath $name
                    $expectedHash = $dllHashes[$name]

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
                    Write-Host "=========================================================" -ForegroundColor Red
                    Write-Host "                 V E R S I O N   C H E C K               " -ForegroundColor White
                    Write-Host "=========================================================" -ForegroundColor Red
                    Write-Host "`n  [!] You already have the latest v1.2 version installed!" -ForegroundColor Yellow
                    Write-Host "  [*] No files need to be downloaded or updated.`n" -ForegroundColor DarkGray
                    
                    Read-Host "  Press the ENTER key to return to the menu"
                } 
                else {
                    # Wyrysowanie pięknej ramki ZANIM cokolwiek zacznie się pobierać lub wyłączać
                    Write-Host "=========================================================" -ForegroundColor Red
                    Write-Host "             S Y N C H R O N I Z I N G   F I L E S       " -ForegroundColor White
                    Write-Host "=========================================================" -ForegroundColor Red
                    Write-Host ""

                    # Funkcja zamykania odpala się teraz pod ramką
                    Stop-SteamSmart

                    foreach ($item in $downloadQueue) {
                        if ($item.Reason -eq "Missing") {
                            Write-Host "  [!] Missing file detected: $($item.Name)" -ForegroundColor Yellow
                        } 
                        elseif ($item.Reason -eq "Mismatch") {
                            Write-Host "  [!] Version mismatch detected: $($item.Name)" -ForegroundColor Yellow
                        }
                        
                        $destination = Join-Path -Path $steamPath -ChildPath $item.Name
                        Download-WithProgress -Url $item.Url -Destination $destination -FileName $item.Name
                    }
                    
                    Write-Host "  [*] Installation of required files completed." -ForegroundColor DarkGray
                    Write-Host "  [*] Starting Steam..." -ForegroundColor DarkGray
                    Start-Process -FilePath $steamExe
                    
                    Write-Host "`n  [+] Files successfully updated to version v1.2!" -ForegroundColor Green
                    
                    Read-Host "`n  Press the ENTER key to return to the menu"
                }
            } 
            else {
                Write-Host "`n`nOperation canceled. Returning to main menu..." -ForegroundColor DarkGray
                Start-Sleep -Seconds 2
            }
        }
        
        # OPTION 2: UNINSTALLATION
        "2" {
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
                
                # Ramka dla deinstalacji (dla spójności)
                Write-Host "=========================================================" -ForegroundColor Red
                Write-Host "             U N I N S T A L L I N G   F I L E S         " -ForegroundColor White
                Write-Host "=========================================================" -ForegroundColor Red
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
        
        # OPTION 3: EXIT
        "3" {
            exit
        }
        
        # ERROR:
        default {
            Write-Host "`nError: Invalid choice! Press only the number 1, 2, or 3." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}
