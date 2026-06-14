# 1. SPRAWDZENIE UPRAWNIEN ADMINISTRATORA
# Sprawdzamy, czy obecne okno PowerShell ma najwyzsze uprawnienia w systemie
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Jesli skrypt odkryje, ze NIE jest administratorem (zmienna $isAdmin to falsz):
if (-not $isAdmin) {
    Write-Host "=======================================================" -ForegroundColor Red
    Write-Host "BLAD: Komenda nie mogla sie zaladowac przez brak uprawnien." -ForegroundColor Red
    Write-Host "Wymagane sa uprawnienia administratorskie, aby edytowac pliki Steam." -ForegroundColor Red
    Write-Host "Prosze uruchomic PowerShell jako Administrator i wkleic komende ponownie." -ForegroundColor Yellow
    Write-Host "=======================================================" -ForegroundColor Red
    
    # Skrypt zatrzymuje sie tutaj i czeka, az uzytkownik wcisnie ENTER
    Read-Host "Nacisnij klawisz ENTER, aby zamknac to okno"
    
    # Dopiero po wcisnieciu ENTER skrypt zamyka okno
    exit
}

# 2. POBRANIE SCIEZKI STEAM
# Pobranie sciezki instalacji Steam z rejestru systemu Windows
$steamRegPath = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction SilentlyContinue

# Sprawdzenie, czy udalo sie znalezc sciezke
if (-not $steamRegPath) {
    Write-Host "Blad: Nie znaleziono instalacji Steam w rejestrze." -ForegroundColor Red
    
    # Tutaj tez dodajemy zatrzymanie, na wypadek bledu ze sciezka
    Read-Host "Nacisnij klawisz ENTER, aby zamknac to okno"
    exit
}

# Pobranie samej sciezki i zamiana ukosnikow na standardowe dla Windowsa (z '/' na '\')
$steamPath = $steamRegPath.SteamPath -replace "/", "\"
Write-Host "Znaleziono glowny folder Steam: $steamPath" -ForegroundColor Cyan

# 3. WYLACZANIE STEAM
Write-Host "Zamykanie aplikacji Steam (jesli jest uruchomiona)..." -ForegroundColor Yellow
# Komenda Stop-Process wymusza zamkniecie procesu "steam".
Stop-Process -Name "steam" -Force -ErrorAction SilentlyContinue

# Odczekanie 3 sekund, aby upewnic sie, ze Steam calkowicie zwolnil pliki w systemie
Start-Sleep -Seconds 3

# 4. POBIERANIE PLIKOW
# Lista 4 linkow URL bezposrednio do plikow .dll na Twoim GitHubie
$dllUrls = @(
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/dmwapi.dll",
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/hyaroscript.dll",
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/OnlineFix.dll",
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/xinput1_4.dll"
)

# Petla pobierajaca kazdy plik z listy
foreach ($url in $dllUrls) {
    # Wyciagniecie samej nazwy pliku z koncowki linku (np. "dmwapi.dll")
    $fileName = Split-Path $url -Leaf
    
    # Utworzenie pelnej sciezki docelowej (np. "C:\Program Files (x86)\Steam\dmwapi.dll")
    $destination = Join-Path -Path $steamPath -ChildPath $fileName

    Write-Host "Pobieranie $($fileName) do $($destination)..."
    
    try {
        # Pobranie pliku z internetu i zapisanie go w folderze Steam
        Invoke-WebRequest -Uri $url -OutFile $destination
        Write-Host "Sukces: Zapisano $($fileName)" -ForegroundColor Green
    } catch {
        # Jesli cos pojdzie nie tak (np. blokada antywirusa), wyswietli sie blad
        Write-Host "Blad podczas pobierania $($fileName): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "Instalacja plikow zakonczona." -ForegroundColor Cyan

# 5. URUCHAMIANIE STEAM
Write-Host "Ponowne uruchamianie Steam..." -ForegroundColor Yellow
# Tworzymy sciezke do pliku steam.exe w glownym folderze
$steamExe = Join-Path -Path $steamPath -ChildPath "steam.exe"
# Uruchamiamy aplikacje
Start-Process -FilePath $steamExe

Write-Host "Gotowe! Mozesz zamknac to okno :3" -ForegroundColor Green
