# Checking Script
# For safe and local quick-dumping of System logs and files
#
# Author:
# Created by dot-sys under GPL-3.0 license
# This script is not related to any external Project.
#
# Usage:
# Use with Powershell 5.1 and NET 4.0 or higher.
# Running PC Checking Programs, including this script, outside of PC Checks may have impact on the outcome.
# It is advised not to use this on your own.
#
# Version 3.0 - Discord Webhook, Session-Log, Retry-Downloads, Zusammenfassungen
# 06 - September - 2026

$ErrorActionPreference = "SilentlyContinue"

# TLS 1.2 erzwingen - behebt abgebrochene/korrupte Downloads auf aelteren Systemen
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

# ============================
#  KONFIGURATION
# ============================
$DiscordWebhookUrl = "https://discord.com/api/webhooks/1545965631227301948/oBzOz5bcfLwHDuc9dKKjclf0rjR6Ju0hYYuVPqiy0_A8UtkR_YNuJBsBr06p41ISpw1M"
$LogDirectory       = "C:\Temp\Logs"
$MaxDownloadRetries  = 3
$RetryDelaySeconds   = 2
$MinFreeSpaceMB      = 500
$KeepLogFiles        = 10

# ============================
#  EMOJI-DEFINITIONEN (reines ASCII im Dateicode, Zeichen zur Laufzeit erzeugt)
# ============================
$E_Blue    = [char]::ConvertFromUtf32(0x1F535)                   # Blauer Kreis
$E_Red     = [char]::ConvertFromUtf32(0x1F534)                   # Roter Kreis
$E_Search  = [char]::ConvertFromUtf32(0x1F50E)                   # Lupe
$E_Broom   = [char]::ConvertFromUtf32(0x1F9F9)                   # Besen
$E_Stop    = [char]::ConvertFromUtf32(0x23F9) + [char]0xFE0F     # Stopp-Quadrat
$E_Clock   = [char]::ConvertFromUtf32(0x1F550)                   # Uhr
$E_Flag    = [char]::ConvertFromUtf32(0x1F3C1)                   # Ziel-Flagge
$E_Timer   = [char]::ConvertFromUtf32(0x23F1) + [char]0xFE0F     # Stoppuhr
$E_PC      = [char]::ConvertFromUtf32(0x1F5A5) + [char]0xFE0F    # Computer
$E_Gear    = [char]::ConvertFromUtf32(0x2699) + [char]0xFE0F     # Zahnrad
$E_Check   = [char]::ConvertFromUtf32(0x2705)                    # Haken
$E_Cross   = [char]::ConvertFromUtf32(0x274C)                    # Kreuz
$E_Globe   = [char]::ConvertFromUtf32(0x1F310)                   # Globus
$E_Folder  = [char]::ConvertFromUtf32(0x1F4C1)                   # Ordner
$E_Warning = [char]::ConvertFromUtf32(0x26A0) + [char]0xFE0F     # Warnung
$E_Id      = [char]::ConvertFromUtf32(0x1F194)                   # ID-Symbol

# ============================
#  SESSION-INFO
# ============================
$Global:ScriptStartTime   = Get-Date
$Global:SessionId         = ([guid]::NewGuid().ToString().Substring(0,8)).ToUpper()
$Global:TotalDownloadsOk  = 0
$Global:TotalDownloadsErr = 0
$Global:LastCheckName     = "-"
$ComputerName             = $env:COMPUTERNAME
$PSVersionString          = $PSVersionTable.PSVersion.ToString()

New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
$Global:LogFile = Join-Path $LogDirectory "run_$(Get-Date -Format 'yyyyMMdd_HHmmss')_$($Global:SessionId).log"

function Write-Log {
    param([string]$Message)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    try { Add-Content -Path $Global:LogFile -Value $line -Encoding UTF8 } catch {}
    Write-Host $line
}

function Remove-OldLogFiles {
    try {
        $files = Get-ChildItem -Path $LogDirectory -Filter "run_*.log" | Sort-Object LastWriteTime -Descending
        if ($files.Count -gt $KeepLogFiles) {
            $files | Select-Object -Skip $KeepLogFiles | Remove-Item -Force
        }
    } catch {}
}

function Get-SystemInfoBlock {
    return "$E_PC **Computer:** $ComputerName`n$E_Gear **PowerShell:** $PSVersionString`n$E_Id **Session:** $Global:SessionId"
}

function Test-WebhookUrlValid {
    if ([string]::IsNullOrWhiteSpace($DiscordWebhookUrl)) { return $false }
    if ($DiscordWebhookUrl -like "*XXXX*") { return $false }
    return ($DiscordWebhookUrl -match '^https://discord(app)?\.com/api/webhooks/\d+/.+$')
}

function Test-InternetConnection {
    try {
        $null = Invoke-WebRequest -Uri "https://discord.com" -Method Head -TimeoutSec 5 -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Get-FreeDiskSpaceMB {
    try {
        $drive = Get-PSDrive -Name C
        return [math]::Round($drive.Free / 1MB, 0)
    } catch {
        return -1
    }
}

function Send-DiscordMessage {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [bool]$Mention = $false,
        [int]$Color = 3447003,
        [array]$Fields = @()
    )

    Write-Log "DISCORD: $Message"

    if (-not (Test-WebhookUrlValid)) {
        Write-Host "[Webhook nicht konfiguriert oder ungueltig - Nachricht nur lokal geloggt]" -ForegroundColor DarkGray
        return
    }

    $content = $null
    if ($Mention) { $content = "@everyone" }

    $embed = @{
        description = $Message
        color       = $Color
        timestamp   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        footer      = @{ text = "PC Check Suite v3.0 - Session $Global:SessionId" }
    }
    if ($Fields.Count -gt 0) { $embed["fields"] = $Fields }

    $payload = @{
        content = $content
        embeds  = @($embed)
    } | ConvertTo-Json -Depth 6

    try {
        Invoke-RestMethod -Uri $DiscordWebhookUrl -Method Post -ContentType "application/json; charset=utf-8" -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 10 | Out-Null
    } catch {
        Write-Log "Fehler beim Senden an Discord: $_"
    }
}

# Farbcodes je Meldungsart
$ColorBlue   = 3447003
$ColorRed    = 15158332
$ColorYellow = 15844367
$ColorGreen  = 3066993
$ColorGray   = 9807270

# ============================
#  MENUE-FUNKTIONEN
# ============================
function Show-MainMenu {
    return Read-Host "`n`n`nChoose a Category:`n
    (1)`t`tChecks`n
    (2)`t`tPrograms`n
    (Clean)`tClean Traces`n
    (0)`t`tClose Script`n`nChoose"
}

function Show-ChecksMenu {
    return Read-Host "`n`n`nChecks Menu:`n
    (1)`tFull Check`n
    (2)`tQuick Check`n
    (3)`tRecording Check`n
    (4)`tAdvanced Filechecking (BETA - Requires Full Check)`n
    (0)`tBack to Main Menu`n`nChoose"
}

function Show-ProgramsMenu {
    return Read-Host "`n`n`nPrograms Menu:`n
    (1)`tDownload CSV File View (by NirSoft)`n
    (2)`tDownload Timeline Explorer (by ygk7)`n
    (3)`tDownload Registry Explorer (by ygk7)`n
    (4)`tDownload Journal Tool (by Echo)`n
    (5)`tDownload WinprefetchView (by NirSoft)`n
    (6)`tDownload System Informer (by Winsider S&S Inc.)`n
    (7)`tDownload Everything (by voidtools)`n
    (0)`tBack to Main Menu`n`nChoose"
}

function Confirm-Action {
    param([string]$Prompt)
    $answer = Read-Host "$Prompt (J/N)"
    return ($answer -eq "J" -or $answer -eq "j")
}

function CleanTraces {
    Write-Host "`n`nCleaning traces of the Check..." -ForegroundColor yellow
    Write-Host "`rDoes not include installed programs" -ForegroundColor yellow
    Send-DiscordMessage -Message "$E_Broom **Bereinigung gestartet**`n$(Get-SystemInfoBlock)" -Color $ColorGreen
    Start-Sleep 1
    try {
        Get-ChildItem -Path "C:\Temp\Dump" | Remove-Item -Recurse -Force | Out-Null
        Get-ChildItem -Path "C:\Temp\Scripts" -File | Where-Object { $_.Name -ne "Menu.ps1" } | ForEach-Object { Remove-Item -Path $_.FullName -Recurse -Force } | Out-Null
        Remove-OldLogFiles
        Write-Host "Traces cleaned successfully." -ForegroundColor green
        Send-DiscordMessage -Message "$E_Broom **Bereinigung abgeschlossen**`n$(Get-SystemInfoBlock)" -Color $ColorGreen
    } catch {
        Send-DiscordMessage -Message "$E_Red **Fehler bei der Bereinigung**`nFehler: $_`n$(Get-SystemInfoBlock)" -Mention $true -Color $ColorRed
    }
    Write-Host "`n`n`tReturning to Menu in " -NoNewline
    Write-Host "2 " -NoNewLine -ForegroundColor Magenta
    Write-Host "Seconds`n`n`n" -NoNewline
    Start-Sleep 2
}

function Unzip {
    param(
        [string]$zipFilePath,
        [string]$destinationPath
    )
    Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFilePath, $destinationPath)
}

function Invoke-CheckDownloads {
    param(
        [string[]]$Urls,
        [string]$DestinationPath,
        [string]$CheckName
    )

    $Global:LastCheckName = $CheckName

    $freeSpace = Get-FreeDiskSpaceMB
    if ($freeSpace -ge 0 -and $freeSpace -lt $MinFreeSpaceMB) {
        Send-DiscordMessage -Message "$E_Warning **Wenig Speicherplatz auf C:** Nur noch $freeSpace MB frei`n$(Get-SystemInfoBlock)" -Color $ColorYellow
    }

    Send-DiscordMessage -Message "$E_Search **$CheckName gestartet**`n$(Get-SystemInfoBlock)" -Color $ColorYellow

    $okCount = 0
    $failedFiles = @()

    foreach ($url in $Urls) {
        $fileName = [System.IO.Path]::GetFileName($url)
        $destinationFile = Join-Path -Path $DestinationPath -ChildPath $fileName
        $attempt = 0
        $success = $false

        while (-not $success -and $attempt -lt $MaxDownloadRetries) {
            $attempt++
            try {
                Invoke-WebRequest -Uri $url -OutFile $destinationFile -ErrorAction Stop
                if (Test-Path -Path $destinationFile) {
                    $success = $true
                    Write-Log "$fileName heruntergeladen (Versuch $attempt)"
                } else {
                    throw "Datei nach Download nicht gefunden: $fileName"
                }
            } catch {
                Write-Log "Download fehlgeschlagen ($fileName), Versuch $attempt von $MaxDownloadRetries : $_"
                if ($attempt -lt $MaxDownloadRetries) { Start-Sleep -Seconds $RetryDelaySeconds }
            }
        }

        if ($success) {
            $okCount++
            $Global:TotalDownloadsOk++
        } else {
            $failedFiles += $fileName
            $Global:TotalDownloadsErr++
            Send-DiscordMessage -Message "$E_Red **Download endgueltig fehlgeschlagen: $fileName**`nNach $MaxDownloadRetries Versuchen`n$(Get-SystemInfoBlock)" -Mention $true -Color $ColorRed
        }
    }

    $summaryColor = if ($failedFiles.Count -eq 0) { $ColorGreen } else { $ColorYellow }
    $fields = @(
        @{ name = "Erfolgreich"; value = "$E_Check $okCount / $($Urls.Count)"; inline = $true }
        @{ name = "Fehlgeschlagen"; value = "$E_Cross $($failedFiles.Count)"; inline = $true }
    )
    Send-DiscordMessage -Message "$E_Search **$CheckName - Downloads abgeschlossen**`n$(Get-SystemInfoBlock)" -Color $summaryColor -Fields $fields

    return ($failedFiles.Count -eq 0)
}

# ============================
#  START
# ============================
Remove-OldLogFiles
Write-Log "Script gestartet - Session $Global:SessionId auf $ComputerName"

if (-not (Test-InternetConnection)) {
    Write-Host "`n`nWarnung: Keine Internetverbindung erkannt. Downloads und Discord-Meldungen koennten fehlschlagen." -ForegroundColor Red
    Write-Log "Keine Internetverbindung beim Start erkannt"
}

Send-DiscordMessage -Message "$E_Blue **Script gestartet**`n$E_Clock **Startzeit:** $($Global:ScriptStartTime.ToString('dd.MM.yyyy HH:mm:ss'))`n$(Get-SystemInfoBlock)" -Mention $true -Color $ColorBlue

try {
    do {
        Clear-Host
        $mainChoice = Show-MainMenu
        switch ($mainChoice) {
            "1" {
                do {
                    Clear-Host
                    $checksChoice = Show-ChecksMenu
                    switch ($checksChoice) {
                        1 {
                            if (-not (Confirm-Action "Full Check wirklich starten?")) { break }
                            Write-Host "`n`nPerforming Check..." -ForegroundColor yellow
                            New-Item -Path "C:\Temp\Scripts" -ItemType Directory -Force | Out-Null
                            New-Item -Path "C:\Temp\Dump" -ItemType Directory -Force | Out-Null
                            Set-Location "C:\temp"
                            Get-ChildItem -Path "C:\Temp\Dump" | Remove-Item -Recurse -Force | Out-Null
                            Get-ChildItem -Path "C:\Temp\Scripts" -File | Where-Object { $_.Name -ne "Menu.ps1" } | ForEach-Object { Remove-Item -Path $_.FullName -Recurse -Force } | Out-Null
                            $urls = @(
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/PCCheck.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/MFT.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/Registry.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/SystemLogs.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/ProcDump.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/Localhost.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/Viewer.html"
                            )
                            Invoke-CheckDownloads -Urls $urls -DestinationPath "C:\Temp\Scripts" -CheckName "Full Check" | Out-Null
                            try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop } catch {}
                            try { Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop } catch {}
                            & C:\temp\scripts\PCCheck.ps1
                            return
                        }
                        2 {
                            Write-Host "`n`nPerforming Quick Check..." -ForegroundColor yellow
                            New-Item -Path "C:\Temp\Scripts" -ItemType Directory -Force | Out-Null
                            New-Item -Path "C:\Temp\Dump" -ItemType Directory -Force | Out-Null
                            Set-Location "C:\temp"
                            Get-ChildItem -Path "C:\Temp\Dump" | Remove-Item -Recurse -Force | Out-Null
                            Get-ChildItem -Path "C:\Temp\Scripts" -File | Where-Object { $_.Name -ne "Menu.ps1" } | ForEach-Object { Remove-Item -Path $_.FullName -Recurse -Force } | Out-Null
                            $urls = @(
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/PCCheck.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/QuickMFT.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/Registry.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/SystemLogs.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/ProcDump.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/Localhost.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/Viewer.html"
                            )
                            Invoke-CheckDownloads -Urls $urls -DestinationPath "C:\Temp\Scripts" -CheckName "Quick Check" | Out-Null
                            try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop } catch {}
                            try { Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop } catch {}
                            & "C:\Temp\Scripts\PCCheck.ps1"
                            return
                        }
                        3 {
                            Write-Host "`n`nPerforming Recording Check..." -ForegroundColor yellow
                            New-Item -Path "C:\Temp\Scripts" -ItemType Directory -Force | Out-Null
                            New-Item -Path "C:\Temp\Dump" -ItemType Directory -Force | Out-Null
                            Set-Location "C:\temp"
                            Invoke-CheckDownloads -Urls @("https://raw.githubusercontent.com/dot-sys/Recording-Check/master/Recording-Check.ps1") -DestinationPath "C:\Temp\Scripts" -CheckName "Recording Check" | Out-Null
                            try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop } catch {}
                            try { Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop } catch {}
                            Add-MpPreference -ExclusionPath 'C:\Temp' | Out-Null
                            & C:\temp\scripts\Recording-Check.ps1
                            Start-Sleep 3
                            & C:\temp\scripts\Menu.ps1
                            return
                        }
                        4 {
                            if (-not (Confirm-Action "Advanced Filechecking (BETA) wirklich starten?")) { break }
                            Write-Host "`n`nPerforming Advanced Filechecking (BETA)..." -ForegroundColor yellow
                            New-Item -Path "C:\Temp\Scripts" -ItemType Directory -Force | Out-Null
                            Set-Location "C:\temp"
                            Invoke-CheckDownloads -Urls @("https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/Packers.ps1") -DestinationPath "C:\Temp\Scripts" -CheckName "Advanced Filechecking (BETA)" | Out-Null
                            try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop } catch {}
                            & C:\Temp\Scripts\Packers.ps1
                            return
                        }
                        0 { break }
                        default {
                            Write-Host "`n`nInvalid option selected. Returning to Checks Menu." -ForegroundColor red
                            Start-Sleep 3
                        }
                    }
                } while ($checksChoice -ne 0)
            }
            "2" {
                do {
                    Clear-Host
                    $programsChoice = Show-ProgramsMenu
                    switch ($programsChoice) {
                        1 {
                            Write-Host "`n`nDownloading CSVFileView..." -ForegroundColor yellow
                            try {
                                (New-Object System.Net.WebClient).DownloadFile("https://www.nirsoft.net/utils/csvfileview-x64.zip", "C:\temp\dump\CSVFileView.zip")
                                Unzip -zipFilePath "C:\temp\dump\CSVFileView.zip" -destinationPath "C:\temp\dump\CSVFileView"
                                Write-Host "CSVFileView downloaded and extracted successfully. Returning to Programs Menu." -ForegroundColor green
                            } catch {
                                Send-DiscordMessage -Message "$E_Red **Fehler beim Download von CSVFileView**`nFehler: $_`n$(Get-SystemInfoBlock)" -Mention $true -Color $ColorRed
                            }
                            Start-Sleep 5
                        }
                        2 {
                            Write-Host "`n`nDownloading Timeline Explorer..." -ForegroundColor yellow
                            try {
                                (New-Object System.Net.WebClient).DownloadFile("https://download.mikestammer.com/net6/TimelineExplorer.zip", "C:\temp\dump\TimelineExplorer.zip")
                                Unzip -zipFilePath "C:\temp\dump\TimelineExplorer.zip" -destinationPath "C:\temp\dump\TimelineExplorer"
                                Write-Host "Timeline Explorer downloaded and extracted successfully. Returning to Programs Menu." -ForegroundColor green
                            } catch {
                                Send-DiscordMessage -Message "$E_Red **Fehler beim Download von Timeline Explorer**`nFehler: $_`n$(Get-SystemInfoBlock)" -Mention $true -Color $ColorRed
                            }
                            Start-Sleep 5
                        }
                        3 {
                            Write-Host "`n`nDownloading Registry Explorer..." -ForegroundColor yellow
                            try {
                                (New-Object System.Net.WebClient).DownloadFile("https://download.mikestammer.com/net6/RegistryExplorer.zip", "C:\temp\dump\RegistryExplorer.zip")
                                Unzip -zipFilePath "C:\temp\dump\RegistryExplorer.zip" -destinationPath "C:\temp\dump\RegistryExplorer"
                                Write-Host "Registry Explorer downloaded and extracted successfully. Returning to Programs Menu." -ForegroundColor green
                            } catch {
                                Send-DiscordMessage -Message "$E_Red **Fehler beim Download von Registry Explorer**`nFehler: $_`n$(Get-SystemInfoBlock)" -Mention $true -Color $ColorRed
                            }
                            Start-Sleep 5
                        }
                        4 {
                            Write-Host "`n`nOpening Echo Website" -ForegroundColor yellow
                            Start-Process "http://dl.echo.ac/tool/journal"
                            Write-Host "Echo Website opened. Returning to Programs Menu." -ForegroundColor green
                            Start-Sleep 5
                        }
                        5 {
                            Write-Host "`n`nDownloading WinprefetchView..." -ForegroundColor yellow
                            try {
                                (New-Object System.Net.WebClient).DownloadFile("https://www.nirsoft.net/utils/winprefetchview.zip", "C:\temp\dump\WinprefetchView.zip")
                                Unzip -zipFilePath "C:\temp\dump\WinprefetchView.zip" -destinationPath "C:\temp\dump\WinprefetchView"
                                Write-Host "WinprefetchView downloaded and extracted successfully. Returning to Programs Menu." -ForegroundColor green
                            } catch {
                                Send-DiscordMessage -Message "$E_Red **Fehler beim Download von WinprefetchView**`nFehler: $_`n$(Get-SystemInfoBlock)" -Mention $true -Color $ColorRed
                            }
                            Start-Sleep 5
                        }
                        6 {
                            Write-Host "`n`nOpening System Informer Website" -ForegroundColor yellow
                            Start-Process "https://systeminformer.sourceforge.io/canary"
                            Write-Host "System Informer Website opened. Returning to Programs Menu." -ForegroundColor green
                            Start-Sleep 5
                        }
                        7 {
                            Write-Host "`n`nDownloading Everything..." -ForegroundColor yellow
                            try {
                                (New-Object System.Net.WebClient).DownloadFile("https://www.voidtools.com/Everything-1.4.1.1026.x64-Setup.exe", "C:\temp\dump\Everything.exe")
                                Write-Host "Everything downloaded successfully. Returning to Programs Menu." -ForegroundColor green
                            } catch {
                                Send-DiscordMessage -Message "$E_Red **Fehler beim Download von Everything**`nFehler: $_`n$(Get-SystemInfoBlock)" -Mention $true -Color $ColorRed
                            }
                            Start-Sleep 5
                        }
                        0 { break }
                        default {
                            Write-Host "`n`nInvalid option selected. Returning to Programs Menu." -ForegroundColor red
                            Start-Sleep 3
                        }
                    }
                } while ($programsChoice -ne 0)
            }
            "clean" {
                CleanTraces
            }
            "0" {
                Write-Host "`n`nExiting script." -ForegroundColor red
                Send-DiscordMessage -Message "$E_Stop **Script wird beendet (manuell)**`n$(Get-SystemInfoBlock)" -Color $ColorGray
                Start-Sleep 2
                Clear-Host
                return
            }
            default {
                Write-Host "`n`nInvalid option selected. Please try again." -ForegroundColor red
                Start-Sleep 2
            }
        }
    } while ($mainChoice -ne 0)
} catch {
    Send-DiscordMessage -Message "$E_Red **Unerwarteter Fehler im Script**`nFehler: $_`n$(Get-SystemInfoBlock)" -Mention $true -Color $ColorRed
} finally {
    $endTime = Get-Date
    $duration = $endTime - $Global:ScriptStartTime
    $durationString = "{0:hh\:mm\:ss}" -f $duration

    $fields = @(
        @{ name = "Letzter Check"; value = $Global:LastCheckName; inline = $true }
        @{ name = "Downloads OK"; value = "$E_Check $Global:TotalDownloadsOk"; inline = $true }
        @{ name = "Downloads Fehler"; value = "$E_Cross $Global:TotalDownloadsErr"; inline = $true }
    )

    Send-DiscordMessage -Message "$E_Blue **Script beendet**`n$E_Clock **Startzeit:** $($Global:ScriptStartTime.ToString('dd.MM.yyyy HH:mm:ss'))`n$E_Flag **Endzeit:** $($endTime.ToString('dd.MM.yyyy HH:mm:ss'))`n$E_Timer **Laufzeit:** $durationString`n$E_Folder **Log:** $Global:LogFile`n$(Get-SystemInfoBlock)" -Mention $true -Color $ColorBlue -Fields $fields
    Write-Log "Script beendet - Laufzeit $durationString"
}
