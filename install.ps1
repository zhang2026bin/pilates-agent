# 安装 pilates-agent 到 DSH（自动改写路径 + 注册插件）
param(
    [string]$Profile = "desktop"
)

$ErrorActionPreference = "Stop"
$repo = $PSScriptRoot
$package = "dsh-agent-pilates"
$patch = Join-Path $repo "plugin\cordis.patch.yml"
$agentDir = Join-Path $repo "agent"

if (-not (Test-Path $patch)) { throw "找不到 $patch" }

# 1. 备份并改写 preset 里的绝对路径
Copy-Item $patch "$patch.bak" -Force
$text = Get-Content $patch -Raw -Encoding UTF8
$text = [regex]::Replace($text, '[A-Za-z]:\\[^\r\n]*?\\agents\\pilates\\', ($agentDir.TrimEnd('\') + '\'))
$enc = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($patch, $text, $enc)
Write-Host "[1/3] 已改写 preset 路径 -> $agentDir"

# 2. 安装插件包
if (-not (Get-Command dsh -ErrorAction SilentlyContinue)) {
    throw "找不到 dsh 命令，请确认 DeepSeek Harness 已安装并在 PATH 中"
}
& dsh plugin --profile $Profile add "file:$(Join-Path $repo 'plugin')"
if ($LASTEXITCODE -ne 0) { throw "dsh plugin add 失败" }
Write-Host "[2/3] 插件包已安装"

# 3. 加入 profile 的 bundle 列表
$profileJson = Join-Path $env:USERPROFILE ".dsh\profiles\$Profile\package.json"
if (Test-Path $profileJson) {
    $data = Get-Content $profileJson -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($data.dsh.profile.bundles -notcontains $package) {
        $data.dsh.profile.bundles = @($data.dsh.profile.bundles) + $package
        [IO.File]::WriteAllText($profileJson, ($data | ConvertTo-Json -Depth 10), $enc)
        Write-Host "[3/3] 已加入 bundles: $package"
    } else {
        Write-Host "[3/3] bundles 已包含 $package"
    }
} else {
    Write-Host "[3/3] 未找到 $profileJson，请手动把 $package 加进 dsh.profile.bundles"
}

Write-Host ""
Write-Host "完成。重启 DeepSeek Harness，然后在 Agent 列表选择 pilates。" -ForegroundColor Green
