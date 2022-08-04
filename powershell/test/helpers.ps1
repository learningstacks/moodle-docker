function ValOrEval([object]$Value) {
    if ($Value -is [scriptblock]) {
        $Value = & $Value
    }
    $Value
}

filter NormalizePath {
    $_.ToString() -replace '(/|\\)+', '/'
}


function BaseDir([string]$Name) {
    [system.io.path]::GetFullPath((Join-Path $PSScriptRoot '..' '..' $name))
}

function TestDir([string]$Name) {
    [system.io.path]::GetFullPath((Join-Path $TestDrive $name))
}

function AssetDir([string]$Name) {
    [system.io.path]::GetFullPath((Join-Path (BaseDir) 'assets' $name))
}

function StackArgs([hashtable]$params) {
    foreach ($paramname in [array]$params.Keys) {
        $params[$paramname] = ValOrEval $params[$paramname]
    }
    if (-Not $params.Contains('MOODLE_DOCKER_WWWROOT')) {
        $params.MOODLE_DOCKER_WWWROOT = (TestDir MOODLE)
    }
    $params
}

function ArrayizeHashHash([hashtable]$hash) {
    foreach ($item in $hash.GetEnumerator()) {
        @{
            Key   = $item.Key
            Value = $item.Value
        }
    }
}

function SetupStandardTestDirs {
    foreach ($name in 'MOODLE', 'MOODLE2', 'APP_3.9.4', 'APP_3.9.5', 'FAILDUMP', 'FAILDUMP2') {
        New-Item -ItemType Directory -Path (TestDir $name)
    }
    @{version = '3.9.4' } | ConvertTo-Json | Set-Content (TestDir 'APP_3.9.4/package.json')
    @{version = '3.9.5' } | ConvertTo-Json | Set-Content (TestDir 'APP_3.9.5/package.json')
}


