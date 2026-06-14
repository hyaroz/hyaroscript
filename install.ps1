# Pobranie ścieżki instalacji Steam z rejestru systemu Windows
$steamRegPath = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction SilentlyContinue

# Sprawdzenie, czy udało się znaleźć ścieżkę
if (-not $steamRegPath) {
    Write-Host "Błąd: Nie znaleziono instalacji Steam w rejestrze." -ForegroundColor Red
    exit
}

# Pobranie samej ścieżki i zamiana ukośników na standardowe dla Windowsa (z '/' na '\')
$steamPath = $steamRegPath.SteamPath -replace "/", "\"
Write-Host "Znaleziono główny folder Steam: $steamPath" -ForegroundColor Cyan

# WYŁĄCZANIE STEAM
Write-Host "Zamykanie aplikacji Steam (jeśli jest uruchomiona)..." -ForegroundColor Yellow
# Komenda Stop-Process wymusza zamknięcie procesu "steam".
# ErrorAction SilentlyContinue sprawia, że jeśli Steam był już wyłączony, skrypt nie wyrzuci błędu.
Stop-Process -Name "steam" -Force -ErrorAction SilentlyContinue

# Odczekanie 3 sekund, aby upewnić się, że Steam całkowicie zwolnił pliki w systemie
Start-Sleep -Seconds 3

# Lista 4 linków URL bezpośrednio do plików .dll na Twoim GitHubie (MUSISZ JE ZMIENIĆ NA SWOJE)
$dllUrls = @(
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/dmwapi.dll",
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/hyaroscript.dll",
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/OnlineFix.dll",
    "https://github.com/hyaroz/hyaroscript/releases/latest/download/xinput1_4.dll"
)

# Pętla pobierająca każdy plik z listy
foreach ($url in $dllUrls) {
    # Wyciągnięcie samej nazwy pliku z końcówki linku (np. "plik1.dll")
    $fileName = Split-Path $url -Leaf
    
    # Utworzenie pełnej ścieżki docelowej (np. "C:\Program Files (x86)\Steam\plik1.dll")
    $destination = Join-Path -Path $steamPath -ChildPath $fileName

    Write-Host "Pobieranie $fileName do $destination..."
    
    try {
        # Pobranie pliku z internetu i zapisanie go w folderze Steam
        Invoke-WebRequest -Uri $url -OutFile $destination
        Write-Host "Sukces: Zapisano $fileName" -ForegroundColor Green
    } catch {
        # Jeśli coś pójdzie nie tak (np. brak uprawnień), wyświetli się błąd
        Write-Host "Błąd podczas pobierania $fileName: $_" -ForegroundColor Red
    }
}

Write-Host "Instalacja plików zakończona." -ForegroundColor Cyan

# URUCHAMIANIE STEAM
Write-Host "Ponowne uruchamianie Steam..." -ForegroundColor Yellow
# Tworzymy ścieżkę do pliku steam.exe w głównym folderze
$steamExe = Join-Path -Path $steamPath -ChildPath "steam.exe"
# Uruchamiamy aplikację
Start-Process -FilePath $steamExe

Write-Host "Gotowe! Możesz zamknąć to okno." -ForegroundColor Green
