# Pobranie sciezki instalacji Steam z rejestru systemu Windows
$steamRegPath = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction SilentlyContinue

# Sprawdzenie, czy udalo sie znalezc sciezke
if (-not $steamRegPath) {
    Write-Host "Blad: Nie znaleziono instalacji Steam w rejestrze." -ForegroundColor Red
    exit
}

# Pobranie samej sciezki i zamiana ukosnikow na standardowe dla Windowsa (z '/' na '\')
$steamPath = $steamRegPath.SteamPath -replace "/", "\"
Write-Host "Znaleziono glowny folder Steam: $steamPath" -ForegroundColor Cyan

# WYLACZANIE STEAM
Write-Host "Zamykanie aplikacji Steam (jesli jest uruchomiona)..." -ForegroundColor Yellow
# Komenda Stop-Process wymusza zamkniecie procesu "steam".
# ErrorAction SilentlyContinue sprawia, ze jesli Steam byl juz wylaczony, skrypt nie wyrzuci bledu.
Stop-Process -Name "steam" -Force -ErrorAction SilentlyContinue

# Odczekanie 3 sekund, aby upewnic sie, ze Steam calkowicie zwolnil pliki w systemie
Start-Sleep -Seconds 3

# Lista 4 linkow URL bezposrednio do plikow .dll na Twoim GitHubie
$dllUrls = @(
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/dmwapi.dll",
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/hyaroscript.dll",
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/OnlineFix.dll",
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/xinput1_4.dll"
)

# Petla pobierajaca kazdy plik z listy
foreach ($url in $dllUrls) {
    # Wyciagniecie samej nazwy pliku z koncowki linku (np. "plik1.dll")
    $fileName = Split-Path $url -Leaf
    
    # Utworzenie pelnej sciezki docelowej (np. "C:\Program Files (x86)\Steam\plik1.dll")
    $destination = Join-Path -Path $steamPath -ChildPath $fileName

    Write-Host "Pobieranie $($fileName) do $($destination)..."
    
    try {
        # Pobranie pliku z internetu i zapisanie go w folderze Steam
        Invoke-WebRequest -Uri $url -OutFile $destination
        Write-Host "Sukces: Zapisano $($fileName)" -ForegroundColor Green
    } catch {
        # Jesli cos pojdzie nie tak (np. brak uprawnien), wyswietli sie blad
        Write-Host "Blad podczas pobierania $($fileName): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "Instalacja plikow zakonczona." -ForegroundColor Cyan

# URUCHAMIANIE STEAM
Write-Host "Ponowne uruchamianie Steam..." -ForegroundColor Yellow
# Tworzymy sciezke do pliku steam.exe w glownym folderze
$steamExe = Join-Path -Path $steamPath -ChildPath "steam.exe"
# Uruchamiamy aplikacje
Start-Process -FilePath $steamExe

Write-Host "Gotowe! Mozesz zamknac to okno." -ForegroundColor Green
