# 1. SPRAWDZENIE UPRAWNIEN ADMINISTRATORA
# Sprawdzamy, czy obecne okno PowerShell ma najwyzsze uprawnienia w systemie
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Jesli skrypt odkryje, ze NIE jest administratorem (zmienna $isAdmin to falsz):
if (-not $isAdmin) {
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host "        BLAD: Komenda nie mogla sie zaladowac przez brak uprawnien.         " -ForegroundColor Red
    Write-Host "    Wymagane sa uprawnienia administratorskie, aby edytowac pliki Steam.    " -ForegroundColor Red
    Write-Host "  Prosze uruchomic PowerShell jako Administrator i wkleic komende ponownie. " -ForegroundColor Yellow
    Write-Host "============================================================================" -ForegroundColor Red
    
    # Skrypt zatrzymuje sie tutaj i czeka, az uzytkownik wcisnie ENTER
    Read-Host "Nacisnij klawisz ENTER, aby zamknac to okno"
    exit
}

# 2. POBRANIE SCIEZKI STEAM
$steamRegPath = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction SilentlyContinue

if (-not $steamRegPath) {
    Write-Host "Blad: Nie znaleziono instalacji Steam w rejestrze." -ForegroundColor Red
    Read-Host "Nacisnij klawisz ENTER, aby zamknac to okno"
    exit
}

$steamPath = $steamRegPath.SteamPath -replace "/", "\"
$steamExe = Join-Path -Path $steamPath -ChildPath "steam.exe"

# Lista linkow do pobrania
$dllUrls = @(
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/dwmapi.dll",
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/hyaroscript.dll",
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/OnlineFix.dll",
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/xinput1_4.dll"
)

# Lista samych nazw plikow (potrzebna do usuwania)
$dllNames = @(
    "dwmapi.dll",
    "hyaroscript.dll",
    "OnlineFix.dll",
    "xinput1_4.dll"
)

# 3. GLOWNE MENU (Pętla, która powtarza sie, az uzytkownik wybierze opcje wyjscia)
while ($true) {
    # Czyszczenie ekranu przed pokazaniem menu
    Clear-Host
    
    # Rysowanie nowego, hakerskiego logo (ASCII Art)
    Write-Host "   _   _ __   __  _    ____   ___  ____   ____ ____  ___ ____ _____ " -ForegroundColor Red
    Write-Host "  | | | |\ \ / / / \  |  _ \ / _ \/ ___| / ___|  _ \|_ _|  _ \_   _|" -ForegroundColor Red
    Write-Host "  | |_| | \ V / / _ \ | |_) | | | \___ \| |   | |_) || || |_) || |  " -ForegroundColor Red
    Write-Host "  |  _  |  | | / ___ \|  _ <| |_| |___) | |___|  _ < | ||  __/ | |  " -ForegroundColor Red
    Write-Host "  |_| |_|  |_|/_/   \_\_| \_\\___/|____/ \____|_| \_\___|_|    |_|  " -ForegroundColor Red
    Write-Host "  |___________ P O W E R S H E L L   I N S T A L L E R ____________| " -ForegroundColor White
    Write-Host ""
    Write-Host "  Znaleziono folder Steam: $steamPath" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [1] Pobierz i zainstaluj najnowsze pliki .DLL (v1.2)" -ForegroundColor White
    Write-Host "  [2] Odinstaluj pliki .DLL z folderu Steam" -ForegroundColor White
    Write-Host "  [3] Wyjdz" -ForegroundColor White
    Write-Host ""
    Write-Host ""
    
    # Natychmiastowe lapanie klawisza
    Write-Host "  Wybierz opcje (1-3): " -NoNewline -ForegroundColor Yellow
    
    # Używamy funkcji systemowej do zlapania jednego klawisza bez czekania na ENTER
    $klawisz = [System.Console]::ReadKey($true)
    $wybor = $klawisz.KeyChar.ToString()

    # Mechanizm sprawdzajacy, co wybral uzytkownik
    switch ($wybor) {
        
        # OPCJA 1: INSTALACJA
        "1" {
            Write-Host "`nZamykanie aplikacji Steam..." -ForegroundColor Yellow
            Stop-Process -Name "steam" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5

            foreach ($url in $dllUrls) {
                $fileName = Split-Path $url -Leaf
                $destination = Join-Path -Path $steamPath -ChildPath $fileName

                Write-Host "Pobieranie $($fileName)..."
                try {
                    Invoke-WebRequest -Uri $url -OutFile $destination
                    Write-Host "Sukces: Zapisano $($fileName)" -ForegroundColor Green
                } catch {
                    Write-Host "Blad podczas pobierania $($fileName): $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            
            Write-Host "`nInstalacja plikow zakonczona. Uruchamianie Steam..." -ForegroundColor Yellow
            Start-Process -FilePath $steamExe
            Write-Host "Gotowe!" -ForegroundColor Green
            
            # Czekamy na ENTER, zeby uzytkownik mogl przeczytac, ze sie udalo
            Read-Host "`nNacisnij klawisz ENTER, aby wrocic do menu"
        }
        
        # OPCJA 2: DEINSTALACJA
        "2" {
            Write-Host "`nZamykanie aplikacji Steam..." -ForegroundColor Yellow
            Stop-Process -Name "steam" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5

            foreach ($name in $dllNames) {
                # Tworzymy sciezke do usuwanego pliku
                $destination = Join-Path -Path $steamPath -ChildPath $name
                
                # Sprawdzamy, czy plik w ogole istnieje w Steamie
                if (Test-Path $destination) {
                    # Komenda Remove-Item usuwa plik na zawsze
                    Remove-Item -Path $destination -Force
                    Write-Host "Sukces: Usunieto $($name)" -ForegroundColor Green
                } else {
                    Write-Host "Ignorowanie: Plik $($name) nie istnieje (juz usuniety)" -ForegroundColor DarkGray
                }
            }

            Write-Host "`nDeinstalacja zakonczona. Uruchamianie Steam..." -ForegroundColor Yellow
            Start-Process -FilePath $steamExe
            Write-Host "Gotowe!" -ForegroundColor Green

            # Czekamy na ENTER
            Read-Host "`nNacisnij klawisz ENTER, aby wrocic do menu"
        }
        
        # OPCJA 3: WYJSCIE
        "3" {
            # Wychodzi calkowicie ze skryptu i zamyka okno
            exit
        }
        
        # BLAD: Gdy ktos wpisze inna cyfre lub literę
        default {
            Write-Host "`nBlad: Nieprawidlowy wybor! Wcisnij tylko cyfre 1, 2 lub 3." -ForegroundColor Red
            # Dajemy 2 sekundy na przeczytanie bledu, po czym menu rysuje sie od nowa
            Start-Sleep -Seconds 2
        }
    }
}
