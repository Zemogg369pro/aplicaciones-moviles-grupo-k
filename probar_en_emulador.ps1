# ============================================================
#  Prepara Android SDK + emulador, configura los proyectos,
#  compila los APK, levanta los backends e instala las apps.
#  Uso (PowerShell):
#    irm https://raw.githubusercontent.com/Zemogg369pro/aplicaciones-moviles-grupo-k/main/probar_en_emulador.ps1 | iex
# ============================================================
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$repo = "$env:USERPROFILE\Documents\aplicaciones-moviles-grupo-k"
$log  = "$repo\emulador_reporte.txt"
$env:Path = "C:\flutter\bin;C:\Program Files\Git\cmd;C:\Program Files\nodejs;" + $env:Path
function Log($m) { $line = "[{0:HH:mm:ss}] $m" -f (Get-Date); Write-Host $line -ForegroundColor Cyan; Add-Content $log $line }

# ---------- 0) Repositorio actualizado ----------
if (-not (Test-Path $repo)) { git clone https://github.com/Zemogg369pro/aplicaciones-moviles-grupo-k $repo }
Set-Location $repo
git fetch origin; git reset --hard origin/main
Set-Content $log "Reporte emulador $(Get-Date)"

# ---------- 1) Java 17 ----------
$jbr = 'C:\Program Files\Android\Android Studio\jbr'
if (Test-Path $jbr) { $env:JAVA_HOME = $jbr }
elseif (-not (Get-ChildItem 'C:\Program Files\Microsoft\jdk-17*' -ErrorAction SilentlyContinue)) {
  Log 'Instalando OpenJDK 17...'
  winget install -e --id Microsoft.OpenJDK.17 --accept-source-agreements --accept-package-agreements | Out-Null
}
if (-not $env:JAVA_HOME) { $env:JAVA_HOME = (Get-ChildItem 'C:\Program Files\Microsoft\jdk-17*' | Select-Object -First 1).FullName }
$env:Path = "$env:JAVA_HOME\bin;" + $env:Path
Log "JAVA_HOME=$env:JAVA_HOME"

# ---------- 2) Android SDK ----------
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$sdkm = "$sdk\cmdline-tools\latest\bin\sdkmanager.bat"
if (-not (Test-Path $sdkm)) {
  Log 'Descargando Android command-line tools...'
  New-Item -ItemType Directory -Force "$sdk\cmdline-tools" | Out-Null
  Invoke-WebRequest 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip' -OutFile "$env:TEMP\clt.zip"
  Expand-Archive "$env:TEMP\clt.zip" "$env:TEMP\clt" -Force
  if (Test-Path "$sdk\cmdline-tools\latest") { Remove-Item "$sdk\cmdline-tools\latest" -Recurse -Force }
  Move-Item "$env:TEMP\clt\cmdline-tools" "$sdk\cmdline-tools\latest"
}
$env:ANDROID_HOME = $sdk; $env:ANDROID_SDK_ROOT = $sdk
[Environment]::SetEnvironmentVariable('ANDROID_HOME', $sdk, 'User')
$img = 'system-images;android-35;google_apis;x86_64'
Log 'Instalando paquetes del SDK (puede tardar varios minutos)...'
("y`n" * 30) | & $sdkm --licenses | Out-Null
& $sdkm 'platform-tools' 'emulator' 'platforms;android-35' 'build-tools;35.0.0' $img | Out-Null
flutter config --android-sdk $sdk | Out-Null
("y`n" * 30) | flutter doctor --android-licenses | Out-Null
$adb = "$sdk\platform-tools\adb.exe"

# ---------- 3) Emulador ----------
$avd = 'Pixel_Moviles'
$avdm = "$sdk\cmdline-tools\latest\bin\avdmanager.bat"
if (-not ((& "$sdk\emulator\emulator.exe" -list-avds) -contains $avd)) {
  Log "Creando emulador $avd..."
  'no' | & $avdm create avd -n $avd -k $img -d pixel_6 --force | Out-Null
}
if (-not ((& $adb devices) -match 'emulator-')) {
  Log 'Iniciando emulador...'
  Start-Process "$sdk\emulator\emulator.exe" -ArgumentList "-avd $avd -no-snapshot-load -gpu auto"
}
& $adb wait-for-device
do { Start-Sleep 3 } until ((& $adb shell getprop sys.boot_completed 2>$null) -match '1')
Log 'Emulador listo.'

# ---------- 4) Configuración Android de cada app ----------
function Prepare($dir, $name, [string[]]$perms, [int]$minSdk = 0, [string]$activityExtra = '') {
  Push-Location "$repo\$dir"
  if (-not (Test-Path android)) { flutter create . --project-name $name --org com.example --platforms=android,ios | Out-Null }
  Remove-Item test\widget_test.dart -ErrorAction SilentlyContinue
  $mf = 'android\app\src\main\AndroidManifest.xml'
  $x = Get-Content $mf -Raw
  foreach ($p in @('android.permission.INTERNET') + $perms) {
    if ($x -notmatch [regex]::Escape($p)) { $x = $x -replace '<application', "<uses-permission android:name=`"$p`"/>`n    <application" }
  }
  if ($x -notmatch 'usesCleartextTraffic') { $x = $x -replace '<application', '<application android:usesCleartextTraffic="true"' }
  if ($activityExtra -and $x -notmatch 'chatapp') { $x = $x -replace '</activity>', "$activityExtra`n        </activity>" }
  [IO.File]::WriteAllText((Resolve-Path $mf), $x)
  if ($minSdk -gt 0) {
    $g = 'android\app\build.gradle.kts'
    [IO.File]::WriteAllText((Resolve-Path $g), ((Get-Content $g -Raw) -replace 'minSdk = flutter.minSdkVersion', "minSdk = $minSdk"))
  }
  flutter pub get | Out-Null
  Pop-Location
}

$deep = @'
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https" android:host="chat.ejemplo.com" android:pathPrefix="/chat" />
                <data android:scheme="https" android:host="chat.ejemplo.com" android:pathPrefix="/join" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="chatapp" />
            </intent-filter>
            <meta-data android:name="flutter_deeplinking_enabled" android:value="false" />
'@

Prepare '01-reservaciones\flutter-getx' 'reservaciones_getx' @()
Prepare '02-camara-deteccion' 'camara_deteccion' @('android.permission.CAMERA','android.permission.RECORD_AUDIO','android.permission.READ_MEDIA_IMAGES','android.permission.READ_MEDIA_VIDEO') 26
Prepare '03-gps-bluetooth-sensores' 'recorridos_ble' @('android.permission.ACCESS_FINE_LOCATION','android.permission.ACCESS_COARSE_LOCATION','android.permission.BLUETOOTH_SCAN','android.permission.BLUETOOTH_CONNECT','android.permission.HIGH_SAMPLING_RATE_SENSORS') 21
Prepare '05-offline-sync\app' 'incidencias_offline' @('android.permission.ACCESS_NETWORK_STATE','android.permission.ACCESS_FINE_LOCATION','android.permission.CAMERA')
Prepare '06-websocket-deeplink\app' 'chat_realtime' @('android.permission.READ_MEDIA_IMAGES') 0 $deep

# ---------- 5) Backends ----------
foreach ($b in @(@('01-reservaciones\backend', 3000), @('05-offline-sync\backend', 4000), @('06-websocket-deeplink\backend', 5000))) {
  Push-Location "$repo\$($b[0])"; npm install --no-audit --no-fund | Out-Null; Pop-Location
  Start-Process powershell -ArgumentList "-NoExit -Command `"cd '$repo\$($b[0])'; `$host.UI.RawUI.WindowTitle='API puerto $($b[1])'; node server.js`""
}
Log 'Backends iniciados en 3000, 4000 y 5000.'

# ---------- 6) Compilar e instalar ----------
$apps = @(
  @('01-reservaciones\flutter-getx', 'http://10.0.2.2:3000'),
  @('05-offline-sync\app', 'http://10.0.2.2:4000'),
  @('06-websocket-deeplink\app', 'http://10.0.2.2:5000'),
  @('03-gps-bluetooth-sensores', ''),
  @('02-camara-deteccion', '')
)
foreach ($a in $apps) {
  Push-Location "$repo\$($a[0])"
  Log "Compilando $($a[0])..."
  $def = if ($a[1]) { @("--dart-define=API_URL=$($a[1])") } else { @() }
  $out = flutter build apk --debug @def 2>&1
  $apk = 'build\app\outputs\flutter-apk\app-debug.apk'
  if (Test-Path $apk) {
    & $adb install -r $apk | Out-Null
    Log "OK  $($a[0]) instalado en el emulador"
  } else {
    Log "ERROR al compilar $($a[0]):"
    $out | Select-Object -Last 40 | ForEach-Object { Add-Content $log "    $_" }
  }
  Pop-Location
}
Log 'TERMINADO. Las apps estan instaladas en el emulador.'
Start-Process notepad $log
