# RCCR Windows 자동 접속 스크립트
# Control 노드를 자동으로 찾아서 SSH 접속합니다.

param(
    [string]$Subnet = "192.168.1",  # 네트워크 대역 (예: 192.168.1)
    [string]$Hostname = "ReCyClusteR-Node",  # 찾을 호스트명
    [string]$Username = "root"  # SSH 사용자명
)

Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                                   ║" -ForegroundColor Cyan
Write-Host "║         RCCR Windows Auto-Connect Script                         ║" -ForegroundColor Cyan
Write-Host "║                                                                   ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# 1. 네트워크 스캔
Write-Host "[1/3] Scanning network ${Subnet}.0/24 for active hosts..." -ForegroundColor Yellow
Write-Host "      (This may take 5-10 seconds)" -ForegroundColor Gray

$activeHosts = @()
1..254 | ForEach-Object -Parallel {
    $ip = "$($using:Subnet).$_"
    if (Test-Connection -ComputerName $ip -Count 1 -TimeoutSeconds 1 -Quiet) {
        $ip
    }
} -ThrottleLimit 50 | ForEach-Object {
    $activeHosts += $_
    Write-Host "      ✓ Found: $_" -ForegroundColor Green
}

if ($activeHosts.Count -eq 0) {
    Write-Host ""
    Write-Host "❌ No active hosts found on network ${Subnet}.0/24" -ForegroundColor Red
    Write-Host ""
    Write-Host "Tips:" -ForegroundColor Yellow
    Write-Host "  1. Check if Control node is powered on" -ForegroundColor Gray
    Write-Host "  2. Try different subnet: .\windows-connect.ps1 -Subnet '192.168.0'" -ForegroundColor Gray
    Write-Host "  3. Check your network settings (ipconfig)" -ForegroundColor Gray
    exit 1
}

Write-Host ""
Write-Host "Found $($activeHosts.Count) active host(s)" -ForegroundColor Green
Write-Host ""

# 2. SSH로 호스트명 확인
Write-Host "[2/3] Checking hostnames via SSH..." -ForegroundColor Yellow

$matchedHost = $null
foreach ($ip in $activeHosts) {
    Write-Host "      Trying $ip..." -ForegroundColor Gray -NoNewline

    # SSH로 호스트명 확인 (타임아웃 2초)
    $result = ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o BatchMode=yes "$Username@$ip" "hostname" 2>$null

    if ($LASTEXITCODE -eq 0 -and $result) {
        Write-Host " hostname: $result" -ForegroundColor Cyan

        if ($result -like "*$Hostname*") {
            $matchedHost = $ip
            Write-Host "      ✓ Match found!" -ForegroundColor Green
            break
        }
    } else {
        Write-Host " (no SSH or auth required)" -ForegroundColor DarkGray
    }
}

Write-Host ""

if ($null -eq $matchedHost) {
    Write-Host "❌ No host with hostname '$Hostname' found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible reasons:" -ForegroundColor Yellow
    Write-Host "  1. Control node not booted yet" -ForegroundColor Gray
    Write-Host "  2. SSH password not set (first boot setup required)" -ForegroundColor Gray
    Write-Host "  3. Wrong hostname filter" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Found active hosts (manual connection needed):" -ForegroundColor Yellow
    foreach ($ip in $activeHosts) {
        Write-Host "  ssh $Username@$ip" -ForegroundColor Gray
    }
    exit 1
}

# 3. 접속
Write-Host "[3/3] Connecting to Control node..." -ForegroundColor Yellow
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  Control Node Found!                                             ║" -ForegroundColor Green
Write-Host "║  IP Address: $matchedHost".PadRight(68) + "║" -ForegroundColor Green
Write-Host "║  Hostname: $Hostname".PadRight(68) + "║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# hosts 파일 업데이트 제안
Write-Host "💡 Tip: Add to hosts file for easier access:" -ForegroundColor Cyan
Write-Host "   $matchedHost   rccr-control" -ForegroundColor Gray
Write-Host "   Then use: ssh root@rccr-control" -ForegroundColor Gray
Write-Host ""

Start-Sleep -Seconds 1
Write-Host "Connecting..." -ForegroundColor Yellow
Write-Host ""

# SSH 접속
ssh "$Username@$matchedHost"
