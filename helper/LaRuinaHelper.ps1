# La Ruina helper
# Visible window. Closing it turns the helper off.
# Reads logs/game.log. Writes only the fixed test event into the La Ruina mod.

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$helperDir = $PSScriptRoot
if (-not $helperDir) {
    $helperDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$laRuinaDir = Split-Path -Parent $helperDir
$modDir = Split-Path -Parent $laRuinaDir
$docsDir = Split-Path -Parent $modDir
$logPath = Join-Path $docsDir "logs\game.log"
$eventPath = Join-Path $laRuinaDir "events\la_ruina_helper_generated.txt"
$locPath = Join-Path $laRuinaDir "localisation\english\la_ruina_helper_generated_l_english.yml"
$lockPath = Join-Path $helperDir "helper.lock"

function Test-HelperAlreadyRunning {
    if (-not (Test-Path -LiteralPath $lockPath)) {
        return $false
    }
    $pidText = Get-Content -LiteralPath $lockPath -ErrorAction SilentlyContinue | Select-Object -First 1
    $oldPid = 0
    if (-not [int]::TryParse($pidText, [ref]$oldPid)) {
        return $false
    }
    if ($oldPid -eq $PID) {
        return $false
    }
    $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
    return ($null -ne $proc -and $proc.ProcessName -eq "powershell")
}

if (Test-HelperAlreadyRunning) {
    [System.Windows.Forms.MessageBox]::Show(
        "The La Ruina helper is already running. Closing that window turns it off.",
        "LA RUINA HELPER IS RUNNING"
    ) | Out-Null
    exit 1
}

Set-Content -LiteralPath $lockPath -Value $PID -Encoding ascii

$script:logLength = 0
$script:signaled = $false
$script:wroteThisSession = $false

function Write-AtomicFile {
    param(
        [string]$Path,
        [string]$Content,
        [bool]$UseBom
    )
    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $tmp = "$Path.tmp"
    $encoding = New-Object System.Text.UTF8Encoding $UseBom
    [System.IO.File]::WriteAllText($tmp, $Content, $encoding)
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force
    }
    Move-Item -LiteralPath $tmp -Destination $Path
}

function Write-GeneratedFiles {
    $eventText = @"
add_namespace = la_ruina_helper_gen

country_event = {
	id = la_ruina_helper_gen.1
	title = la_ruina_helper_gen.1.t
	desc = la_ruina_helper_gen.1.d
	picture = GFX_report_event_gathering_protest

	is_triggered_only = yes
	fire_only_once = yes

	option = {
		name = la_ruina_helper_gen.1.a
		clr_country_flag = la_ruina_helper_signal
	}
}
"@
    $locText = @"
l_english:
 la_ruina_helper_gen.1.t:0 "The Helper Wrote This"
 la_ruina_helper_gen.1.d:0 "The helper wrote this event. If you are reading it, the restart pipeline works."
 la_ruina_helper_gen.1.a:0 "The pipeline works."
"@
    Write-AtomicFile -Path $eventPath -Content $eventText -UseBom $false
    Write-AtomicFile -Path $locPath -Content $locText -UseBom $true
}

function Read-LogChunk {
    if (-not (Test-Path -LiteralPath $logPath)) {
        return ""
    }
    $stream = $null
    try {
        $stream = [System.IO.File]::Open(
            $logPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )
        $length = $stream.Length
        $start = 0L
        if ($script:logLength -gt 0 -and $script:logLength -le $length) {
            $start = [Math]::Max(0L, $script:logLength - 80L)
        }
        $count = [int]($length - $start)
        if ($count -le 0) {
            $script:logLength = $length
            return ""
        }
        $buffer = New-Object byte[] $count
        $stream.Position = $start
        $read = 0
        while ($read -lt $count) {
            $n = $stream.Read($buffer, $read, $count - $read)
            if ($n -le 0) { break }
            $read += $n
        }
        $script:logLength = $length
        return [System.Text.Encoding]::UTF8.GetString($buffer, 0, $read)
    }
    finally {
        if ($stream) { $stream.Dispose() }
    }
}

function Remove-HelperLock {
    if (-not (Test-Path -LiteralPath $lockPath)) {
        return
    }
    $pidText = Get-Content -LiteralPath $lockPath -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pidText -eq "$PID") {
        Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "LA RUINA HELPER IS RUNNING"
$form.TopMost = $true
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.ClientSize = New-Object System.Drawing.Size(760, 310)
$form.MinimizeBox = $false
$form.MaximizeBox = $false
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.BackColor = [System.Drawing.Color]::FromArgb(255, 214, 0)

$title = New-Object System.Windows.Forms.Label
$title.Text = "LA RUINA HELPER IS RUNNING"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 22, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::Black
$title.BackColor = $form.BackColor
$title.AutoSize = $false
$title.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$title.Bounds = New-Object System.Drawing.Rectangle(20, 24, 720, 70)

$status = New-Object System.Windows.Forms.Label
$status.Text = "Watching the game log."
$status.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Regular)
$status.ForeColor = [System.Drawing.Color]::Black
$status.BackColor = $form.BackColor
$status.AutoSize = $false
$status.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$status.Bounds = New-Object System.Drawing.Rectangle(20, 110, 720, 90)

$hint = New-Object System.Windows.Forms.Label
$hint.Text = "This window opens when La Ruina starts. Closing it turns the helper off until La Ruina starts again."
$hint.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Regular)
$hint.ForeColor = [System.Drawing.Color]::Black
$hint.BackColor = $form.BackColor
$hint.AutoSize = $false
$hint.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$hint.Bounds = New-Object System.Drawing.Rectangle(20, 210, 720, 70)

$form.Controls.Add($title)
$form.Controls.Add($status)
$form.Controls.Add($hint)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 500
$timer.Add_Tick({
    try {
        $chunk = Read-LogChunk
        if ($chunk -and $chunk.Contains("LA_RUINA_HELPER_SIGNAL")) {
            $script:signaled = $true
        }
        if ($script:signaled) {
            $exists = Test-Path -LiteralPath $eventPath
            if (-not $exists) {
                Write-GeneratedFiles
                $script:wroteThisSession = $true
                $status.Text = "Event written. Quit Hearts of Iron IV fully and start it again, then load your save."
            }
            elseif (-not $script:wroteThisSession) {
                $status.Text = "Already written."
            }
        }
        else {
            $status.Text = "Watching the game log."
        }
    }
    catch {
        $status.Text = $_.Exception.Message
    }
})

$form.Add_FormClosing({
    $timer.Stop()
    Remove-HelperLock
})

$form.Add_Shown({
    $timer.Start()
})

[System.Windows.Forms.Application]::Run($form)
