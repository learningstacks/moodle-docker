Import-Module -Name (Join-Path $PSScriptRoot '../moodle-docker.psm1') -Force
# $ErrorActionPreference = 'Break'

Describe 'Parameter Tests' {

    BeforeDiscovery {
        $tests = . (Join-Path $PSScriptRoot 'ParameterHandling.testdata.ps1')
    }

    BeforeAll {
        . (Join-Path $PSScriptRoot 'helpers.ps1')
        ClearTestDrive
        SetupStandardTestDirs
    }

    AfterAll {
        ClearTestDrive
    }

    BeforeEach {
        ResetEnvironment
    }

    AfterEach {
        ResetEnvironment
    }

    $select = {
        $_.paramname -eq 'MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES' -and $_.testname -match '^false'
        $true
    }

    Context '<_.name>' -ForEach ($tests | Where-Object $select | Group-Object 'paramname') {
        Context '<_.name>' -ForEach ($_.group | Group-Object 'groupname') {
            It '<_.testname>' -TestCases ($_.group) {
                ApplyTest @_
            }
        }
    }
}
