# 1. ADMINISTRATOR PRIVILEGES CHECK
# Check if the current PowerShell window has the highest system privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# If the script detects it is NOT running as administrator ($isAdmin is false):
if (-not $isAdmin) {
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host "         Administrator permissions are required to use this command.        " -ForegroundColor Red
    Write-Host "      Please run PowerShell as Administrator and paste the command again.   " -ForegroundColor Yellow
    Write-Host "============================================================================" -ForegroundColor Red
    
    # The script stops here and waits for the user to press ENTER
    Read-Host "Press the ENTER key to close this window"
    exit
}

# 2. GET STEAM PATH
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

# List of file names only (needed for uninstallation)
$dllNames = @(
    "dwmapi.dll",
    "hyaroscript.dll",
    "OnlineFix.dll",
    "xinput1_4.dll"
)

# 3. MAIN MENU (Loop that repeats until the user chooses the exit option)
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
            # CLEAR SCREEN FOR WARNING
            Clear-Host
            
            Write-Host "================ INSTALLATION WARNING ================" -ForegroundColor Yellow
            Write-Host "Please read the following information carefully:`n" -ForegroundColor White
            
            Write-Host "Proceeding with this installation will:" -ForegroundColor White
            Write-Host "1. Forcefully close your Steam application." -ForegroundColor Gray
            Write-Host "2. Download the required .DLL files from the server." -ForegroundColor Gray
            Write-Host "3. Install them directly into your main Steam directory.`n" -ForegroundColor Gray
            Write-Host "4. Automatically start Steam application.`n" -ForegroundColor Gray
            
            Write-Host "Do you wish to proceed? [Y] Yes / [N] No: " -NoNewline -ForegroundColor Yellow
            
            # Catch Y/N key
            $confirmKey = [System.Console]::ReadKey($true)
            # Convert whatever they pressed to uppercase (so 'y' becomes 'Y')
            $confirm = $confirmKey.KeyChar.ToString().ToUpper()

            # If they pressed Y, start installation
            if ($confirm -eq "Y") {
                Write-Host "`n`nClosing Steam application..." -ForegroundColor Yellow
                Stop-Process -Name "steam" -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 5

                foreach ($url in $dllUrls) {
                    $fileName = Split-Path $url -Leaf
                    $destination = Join-Path -Path $steamPath -ChildPath $fileName

                    Write-Host "Downloading $($fileName)..."
                    try {
                        Invoke-WebRequest -Uri $url -OutFile $destination
                        Write-Host "Success: Saved $($fileName)" -ForegroundColor Green
                    } catch {
                        Write-Host "Error during download $($fileName): $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                
                Write-Host "`nInstallation of files completed. Starting Steam..." -ForegroundColor Yellow
                Start-Process -FilePath $steamExe
                Write-Host "Done!" -ForegroundColor Green
                
                Read-Host "`nPress the ENTER key to return to the menu"
            } 
            # If they pressed N (or any other key), cancel
            else {
                Write-Host "`n`nOperation canceled. Returning to main menu..." -ForegroundColor DarkGray
                Start-Sleep -Seconds 2
            }
        }
        
        # OPTION 2: UNINSTALLATION
        "2" {
            # CLEAR SCREEN FOR WARNING
            Clear-Host
            
            Write-Host "=============== UNINSTALLATION WARNING ===============" -ForegroundColor Yellow
            Write-Host "Please read the following information carefully:`n" -ForegroundColor White
            
            Write-Host "Proceeding with this uninstallation will:" -ForegroundColor White
            Write-Host "1. Forcefully close your Steam application." -ForegroundColor Gray
            Write-Host "2. Permanently delete specific files from your Steam directory:" -ForegroundColor Gray
            Write-Host "   (dwmapi.dll, hyaroscript.dll, OnlineFix.dll, xinput1_4.dll)`n" -ForegroundColor Gray
            
            Write-Host "WARNING: You will lose access to all your buyed games from Hyaro's Shop" -ForegroundColor Red
            
            Write-Host "Are you sure you want to completely remove these files? [Y] Yes / [N] No: " -NoNewline -ForegroundColor Yellow
            
            # Catch Y/N key
            $confirmKey = [System.Console]::ReadKey($true)
            $confirm = $confirmKey.KeyChar.ToString().ToUpper()

            # If they pressed Y, start uninstallation
            if ($confirm -eq "Y") {
                Write-Host "`n`nClosing Steam application..." -ForegroundColor Yellow
                Stop-Process -Name "steam" -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 5

                foreach ($name in $dllNames) {
                    $destination = Join-Path -Path $steamPath -ChildPath $name
                    
                    if (Test-Path $destination) {
                        Remove-Item -Path $destination -Force
                        Write-Host "Success: Deleted $($name)" -ForegroundColor Green
                    } else {
                        Write-Host "Ignoring: File $($name) does not exist (already deleted)" -ForegroundColor DarkGray
                    }
                }

                Write-Host "`nUninstallation completed. Starting Steam..." -ForegroundColor Yellow
                Start-Process -FilePath $steamExe
                Write-Host "Done!" -ForegroundColor Green

                Read-Host "`nPress the ENTER key to return to the menu"
            } 
            # If they pressed N (or any other key), cancel
            else {
                Write-Host "`n`nOperation canceled. Returning to main menu..." -ForegroundColor DarkGray
                Start-Sleep -Seconds 2
            }
        }
        
        # OPTION 3: EXIT
        "3" {
            # Exits the script completely and closes the window
            exit
        }
        
        # ERROR: When someone types a different number or letter
        default {
            Write-Host "`nError: Invalid choice! Press only the number 1, 2, or 3." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}
