Import-Module -Name (Join-Path $PSScriptRoot '../moodle-docker.psm1') -Force
# $ErrorActionPreference = 'Break'

Describe 'Parameter Tests' {

    BeforeDiscovery {
        $tests = . (Join-Path $PSScriptRoot 'paramtestdata.ps1')
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

    Context '<_.name>' -ForEach ($tests | Group-Object 'paramname') {
        Context '<_.name>' -ForEach ($_.group | Group-Object 'groupname') {
            It '<_.testname>' -TestCases ($_.group) {
                ApplyTest @_
            }
        }
    }
}
