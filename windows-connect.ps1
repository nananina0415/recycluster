# RCCR Windows Auto-Connect Script
# Automatically finds and connects to Control node

param(
    [string]$Subnet = "192.168.1",
    [string]$Hostname = "ReCyClusteR-Node",
    [string]$Username = "root"
)

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "         RCCR Windows Auto-Connect Script                      " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Network scan
$networkRange = $Subnet + ".0/24"
Write-Host "[1/3] Scanning network $networkRange for active hosts..." -ForegroundColor Yellow
Write-Host "      (This may take 5-10 seconds)" -ForegroundColor Gray

$activeHosts = @()
$subnetBase = $Subnet
1..254 | ForEach-Object -Parallel {
    $ip = $using:subnetBase + "." + $_
    if (Test-Connection -ComputerName $ip -Count 1 -TimeoutSeconds 1 -Quiet) {
        $ip
    }
} -ThrottleLimit 50 | ForEach-Object {
    $activeHosts += $_
    Write-Host "      Found: $_" -ForegroundColor Green
}

if ($activeHosts.Count -eq 0) {
    Write-Host ""
    Write-Host "ERROR: No active hosts found on network $networkRange" -ForegroundColor Red
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

# 2. Check hostnames via SSH
Write-Host "[2/3] Checking hostnames via SSH..." -ForegroundColor Yellow

$matchedHost = $null
foreach ($ip in $activeHosts) {
    Write-Host "      Trying $ip..." -ForegroundColor Gray -NoNewline

    # Check hostname via SSH (timeout 2 seconds)
    $result = ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o BatchMode=yes "$Username@$ip" "hostname" 2>$null

    if ($LASTEXITCODE -eq 0 -and $result) {
        Write-Host " hostname: $result" -ForegroundColor Cyan

        if ($result -like "*$Hostname*") {
            $matchedHost = $ip
            Write-Host "      Match found!" -ForegroundColor Green
            break
        }
    } else {
        Write-Host " (no SSH or auth required)" -ForegroundColor DarkGray
    }
}

Write-Host ""

if ($null -eq $matchedHost) {
    Write-Host "ERROR: No host with hostname '$Hostname' found" -ForegroundColor Red
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

# 3. Connect
Write-Host "[3/3] Connecting to Control node..." -ForegroundColor Yellow
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Green
Write-Host "  Control Node Found!                                          " -ForegroundColor Green
Write-Host "  IP Address: $matchedHost" -ForegroundColor Green
Write-Host "  Hostname: $Hostname" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Green
Write-Host ""

# Suggest updating hosts file
Write-Host "Tip: Add to hosts file for easier access:" -ForegroundColor Cyan
Write-Host "   $matchedHost   rccr-control" -ForegroundColor Gray
Write-Host "   Then use: ssh root@rccr-control" -ForegroundColor Gray
Write-Host ""

Start-Sleep -Seconds 1
Write-Host "Connecting..." -ForegroundColor Yellow
Write-Host ""

# SSH connection
ssh "$Username@$matchedHost"
