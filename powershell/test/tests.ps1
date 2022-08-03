using module '../moodle-docker.psm1'

Describe 'Stack Construction' {

    BeforeDiscovery {

        # function ServiceImageMatches([hashtable]$Stack, [string]$ServiceName, [string]$Expected) {
        #     It "Image matches $Expected" {
        #         $Stack.services.$ServiceName | Should -Match $Expected
        #     }
        # }

        # function ServiceEnvironmentIncludes([hashtable]$Stack, [string]$ServiceName, [hashtable]$Expected) {
        #     foreach ($variable in $Expected.GetEnumerator()) {
        #         $Name = $variable.Name
        #         $Value = $variable.Value

        #         It "Environment.$Name = $Value" {
        #             $Stack.$ServiceName.Environment.$Name | Should -Be $Value
        #         }
        #     }

        # }

        # function ServiceIncludesPort([hashtable]$Stack, [string]$ServiceName, [string]$LocalPort, [string]$HostName, [string]$HostPort) {
        #     It "Maps $($LocalPort) to $($HostName):$($HostPort)" {
        #         $port = $Stack.services.ServiceName.ports | Where-Object Source -EQ $HostPort
        #     }
        # }

        # function ServiceVolumesInclude([hashtable]$Stack, [string]$ServiceName, [hashtable]$Expected) {

        # }

        $TestStacks = . (Join-Path $PSScriptRoot 'teststacks.ps1')

    }

    BeforeAll {
        function TestDir([string]$Name) {
            Join-Path $TestDrive $name
        }

        function BaseDir([string]$Name) {
            Join-Path (Split-Path $PSScriptRoot) $name
        }

        function AssetDir([string]$Name) {
            Join-Path (BaseDir) 'assets' $name
        }

        foreach ($name in 'MOODLE', 'MOODLE2', 'APP_3.9.4', 'APP_3.9.5', 'FAILDUMP', 'FAILDUMP2') {
            New-Item -ItemType Directory -Path (TestDir $name)
        }
        @{version = '3.9.4' } | ConvertTo-Json | Set-Content (TestDir 'APP_3.9.4/package.json')
        @{version = '3.9.5' } | ConvertTo-Json | Set-Content (TestDir 'APP_3.9.5/package.json')
    }

    AfterEach {
        Get-ChildItem env: | Where-Object { $_.Name -match '^(MOODLE|COMPOSE)' } | ForEach-Object {
            Remove-Item "Env:$($_.Name)"
        }
    }

    AfterAll {
        #Delete all files and directories in TestDrive:
        Get-ChildItem 'TestDrive:/' | Remove-Item -Force -Recurse
    }

    Context '<_.Scenario>' -ForEach $TestStacks {

        BeforeDiscovery {
            $TestStack = $_
        }


        BeforeAll {
            $TestStack = $_
            $ExpectedServiceNames = ($TestStack.Expected.Services | ForEach-Object { $_.Name } | Sort-Object) -join ', '

            if (-Not $TestStack.Params.ContainsKey('MOODLE_DOCKER_WWWROOT')) {
                $TestStack.Params.MOODLE_DOCKER_WWWROOT = TestDir MOODLE
            }

            $Stack = ([Stack]::New($TestStack.Params)).Invoke('convert') | ConvertFrom-Yaml
        }

        It 'Stack consists of services: <ExpectedServiceNames>' {
            $ActualServiceNames = ($Stack.services.Keys | Sort-Object) -join ', '
            $ActualServiceNames | Should -Be $ExpectedServiceNames
        }

        Context 'Service <Name>' -ForEach $TestStack.Expected.Services {

            BeforeDiscovery {
                $ExpectedService = $_
            }

            BeforeAll {
                $ExpectedService = $_
            }

            if ($ExpectedService.Image) {
                It 'Image matches <Image>' {
                    $Stack.services.$($ExpectedService.Name).image | Should -Match $ExpectedService.Image
                }
            }

            It 'environment.<Name> = <Value>' -TestCases $ExpectedService.Environment {
                $Stack.services.$($ExpectedService.Name).environment.$Name | Should -Be $Value
            }

            if ($ExpectedService.ContainsKey('Ports')) {
                if ($ExpectedService.Ports) {
                    It 'Port <LocalPort> => <HostName>:<HostPort>' -TestCases $ExpectedService.Ports {
                        $Stack.services.$($ExpectedService.Name).Keys | Should -Contain 'ports'
                        $port = $Stack.services.$($ExpectedService.Name).ports | Where-Object target -EQ $LocalPort
                        $port | Should -Not -BeNullOrEmpty
                        $port.host_ip | Should -Be $_.HostName
                        $port.published | Should -Be $_.HostPort
                    }
                }
                else {
                    It 'No ports are published' {
                        $Stack.services.$($ExpectedService.Name).Keys | Should -Not -Contain 'ports'
                    }
                }
            }

            if ($ExpectedService.ContainsKey('Volumes')) {
                if ($ExpectedService.Volumes) {
                }
            }
        }

    }

}

