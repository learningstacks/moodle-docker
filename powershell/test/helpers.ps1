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

function ClearTestDrive {
    Get-ChildItem 'TestDrive:/' | Remove-Item -Force -Recurse
}


function ApplyTest {
    param(
        $paramname,
        $stackenv = @{},
        $stackargs = @{},
        $expectThrow = $false,
        $expect
    )

    # Add default WWWROOT for all tests other than MOODLE_DOCKER_WWWROOT when value not provided
    if ($paramname -ne 'MOODLE_DOCKER_WWWROOT' -and !$stackenv.Contains('MOODLE_DOCKER_WWWROOT') -and !$stackargs.Contains('MOODLE_DOCKER_WWWROOT')) {
        $stackargs.MOODLE_DOCKER_WWWROOT = (TestDir MOODLE)
    }

    # Set the environment
    foreach ($varname in [array]$stackenv.keys) {
        Set-Item "Env:$varname" -Value (ValOrEval $stackenv.$varname)
    }

    # set the arguments to be passed
    foreach ($varname in [array]$stackargs.keys) {
        $stackargs.$varname = ValOrEval $stackargs.$varname
    }

    if ($expectthrow) {
        { New-Stack $stackargs } | Should -Throw
    }
    else {
        $Stack = New-Stack $stackargs
        $ExpectParams = & {
            if ($expect -is [hashtable]) {
                foreach ($item in $expect.GetEnumerator()) {
                    @{
                        paramname = $item.key
                        expectval = (ValOrEval $item.value)
                    }
                }
            }
            elseif ($expect) {
                @{
                    paramname = $paramname
                    expectval = (ValOrEval $expect)
                }
            }
        }
        foreach ($item in $expectparams) {
            $Stack.StackParams[$item.paramname] | Should -Be $item.expectval -Because "$($item.paramname) should be $($item.expectval)"
        }
    }
}

function ResetEnvironment {
    Get-ChildItem env: | Where-Object { $_.Name -match '^(MOODLE|COMPOSE)' } | ForEach-Object {
        Remove-Item "Env:$($_.Name)"
    }
}