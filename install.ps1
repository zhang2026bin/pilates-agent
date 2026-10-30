# 安装 pilates-agent 到 DSH（改写路径 + 注册插件 + 接入本地课序引擎）
param(
    [string]$Profile = "desktop",
    [string]$StudioApp = "D:\Downloads\普拉提"
)

$ErrorActionPreference = "Stop"
$repo = $PSScriptRoot
$package = "dsh-agent-pilates"
$patch = Join-Path $repo "plugin\cordis.patch.yml"
$agentDir = Join-Path $repo "agent"
$sharedDir = Join-Path $repo "agent\_shared"
$enc = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path $patch)) { throw "找不到 $patch" }

# 1. 改写 preset 里的绝对路径（含 _shared）
Copy-Item $patch "$patch.bak" -Force
$text = Get-Content $patch -Raw -Encoding UTF8
$text = [regex]::Replace($text, '[A-Za-z]:\\[^\r\n]*?\\agents\\pilates\\', ($agentDir.TrimEnd('\') + '\'))
$text = [regex]::Replace($text, '[A-Za-z]:\\[^\r\n]*?\\agents\\_shared\\', ($sharedDir.TrimEnd('\') + '\'))
[IO.File]::WriteAllText($patch, $text, $enc)
Write-Host "[1/4] 已改写 preset 路径 -> $agentDir"

# 2. 安装数据桥技能（独立于本机是否装了课序引擎）
$skillSrc = Join-Path $repo "plugin\skill\pilates-studio"
if (Test-Path $skillSrc) {
    $skillDst = Join-Path $env:USERPROFILE ".agents\skills\pilates-studio"
    New-Item -ItemType Directory -Force -Path (Split-Path $skillDst) | Out-Null
    Copy-Item $skillSrc $skillDst -Recurse -Force
    Write-Host "[2/4] 技能已安装 -> $skillDst"
} else {
    Write-Host "[2/4] 未找到 $skillSrc，跳过技能安装" -ForegroundColor Yellow
}

# 2b. 若本机有课序引擎，写入 STUDIO_APP
$bridge = Join-Path $StudioApp "app\agent-bridge.js"
if (Test-Path $bridge) {
    [Environment]::SetEnvironmentVariable("STUDIO_APP", $StudioApp, "User")
    $env:STUDIO_APP = $StudioApp
    Write-Host "[2b] STUDIO_APP = $StudioApp"
} else {
    Write-Host "[2b] 未找到 $bridge，跳过数据桥配置（之后可手动设置 STUDIO_APP）" -ForegroundColor Yellow
}

# 3. 安装插件包
if (-not (Get-Command dsh -ErrorAction SilentlyContinue)) {
    throw "找不到 dsh 命令，请确认 DeepSeek Harness 已安装并在 PATH 中"
}
& dsh plugin --profile $Profile add "file:$repo\plugin"
if ($LASTEXITCODE -ne 0) { throw "dsh plugin add 失败" }
Write-Host "[3/4] 插件包已安装"

# 4. 加入 bundle 列表
$profileJson = Join-Path $env:USERPROFILE ".dsh\profiles\$Profile\package.json"
if (Test-Path $profileJson) {
    $data = Get-Content $profileJson -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($data.dsh.profile.bundles -notcontains $package) {
        $data.dsh.profile.bundles = @($data.dsh.profile.bundles) + $package
        [IO.File]::WriteAllText($profileJson, ($data | ConvertTo-Json -Depth 10), $enc)
        Write-Host "[4/4] 已加入 bundles: $package"
    } else {
        Write-Host "[4/4] bundles 已包含 $package"
    }
} else {
    Write-Host "[4/4] 未找到 $profileJson，请手动把 $package 加进 dsh.profile.bundles"
}

Write-Host ""
Write-Host "完成。重启 DeepSeek Harness，然后在 Agent 列表选择 pilates。" -ForegroundColor Green
