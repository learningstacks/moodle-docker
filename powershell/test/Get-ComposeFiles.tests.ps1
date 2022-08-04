Import-Module -Name (Join-Path $PSScriptRoot '../moodle-docker.psm1') -Force

InModuleScope 'moodle-docker' {

    Describe 'Compose file handling' {

        BeforeDiscovery {
            $TestCases = @(
                @{
                    Scenario    = 'Default Stack'
                    Arguments        = @{
                    }
                    ExpectFiles  = @(
                        { BaseDir 'base.yml' }
                        { BaseDir 'service.mail.yml' }
                    )
                }
                @{
                    Scenario    = 'APP_PATH 3.9.5'
                    Arguments   = @{
                        MOODLE_DOCKER_APP_PATH = { TestDir 'APP_3.9.5' }
                    }
                    ExpectFiles = @(
                        { BaseDir 'base.yml' }
                        { BaseDir 'service.mail.yml' }
                        { BaseDir 'moodle-app-dev-ionic5.yml' }
                    )
                }
                @{
                    Scenario    = 'APP_PATH 3.9.4'
                    Arguments   = @{
                        MOODLE_DOCKER_APP_PATH = { TestDir 'APP_3.9.4' }
                    }
                    ExpectFiles = @(
                        { BaseDir 'base.yml' }
                        { BaseDir 'service.mail.yml' }
                        { BaseDir 'moodle-app-dev-ionic3.yml' }
                    )
                }
                @{
                    Scenario    = 'APP_VERSION, 3.9.5'
                    Arguments   = @{
                        MOODLE_DOCKER_APP_VERSION = '3.9.5'
                    }
                    ExpectFiles = @(
                        { BaseDir 'base.yml' }
                        { BaseDir 'service.mail.yml' }
                        { BaseDir 'moodle-app-ionic5.yml' }
                    )
                }
                @{
                    Scenario    = 'APP_VERSION, 3.9.4'
                    Arguments   = @{
                        MOODLE_DOCKER_APP_VERSION = '3.9.4'
                    }
                    ExpectFiles = @(
                        { BaseDir 'base.yml' }
                        { BaseDir 'service.mail.yml' }
                        { BaseDir 'moodle-app-ionic3.yml' }
                    )
                }
            )
        }

        BeforeAll {
            . (Join-Path $PSScriptRoot 'helpers.ps1')

            foreach ($name in 'MOODLE', 'MOODLE2', 'APP_3.9.4', 'APP_3.9.5', 'FAILDUMP', 'FAILDUMP2') {
                New-Item -ItemType Directory -Path (TestDir $name)
            }
            @{version = '3.9.4' } | ConvertTo-Json | Set-Content (TestDir 'APP_3.9.4/package.json')
            @{version = '3.9.5' } | ConvertTo-Json | Set-Content (TestDir 'APP_3.9.5/package.json')

        }

        Context '<scenario>' -Foreach $TestCases {

            BeforeAll {
                $Stack = New-Stack (StackArgs $Arguments)
            }

            It "Includes <_>" -TestCases $expectfiles{
                $Stack.ComposeFiles | Should -Contain (ValOrEval $_)
            }

            It "Includes no other files" {
                $Stack.ComposeFiles | Should -HaveCount $expectfiles.count
            }


        }

    }
}