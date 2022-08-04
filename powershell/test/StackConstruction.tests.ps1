using module '../moodle-docker.psm1'

Describe 'Stack Construction' {

    BeforeDiscovery {
        $stackspecs = . (Join-Path $PSScriptRoot 'teststacks.ps1')
        $stackspecs = $stackspecs | Where-Object { $_.Scenario -match 'selenium' }

     }

    BeforeAll {
        # Import-Module (Join-Path $PSScriptRoot '..' 'moodle-docker.psm1') -Force
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

    # Context '<Scenario>' -ForEach ($stackspecs.GetEnumerator() | ForEach-Object { @{Scenario = $spec.key; spec = $spec.value }}) {
    Describe '<Scenario>' -ForEach $stackspecs {

        BeforeDiscovery {
            $ExpectedServices = foreach ($svc in $expect.services.GetEnumerator()) {
                $h = $svc.value
                $h.servicename = $svc.name
                $h
            }
        }

        BeforeAll {
            if (-Not $Params.ContainsKey('MOODLE_DOCKER_WWWROOT')) {
                $Params.MOODLE_DOCKER_WWWROOT = TestDir MOODLE
            }
            $Stack = New-Stack $Params
            $stackyaml = $Stack.Invoke('convert') | ConvertFrom-Yaml
            $ExpectedServiceNames = ($expect.services.keys | Sort-Object) -join ', '
        }

        It 'Services = <ExpectedServiceNames>' {
            $ActualServiceNames = ($stackyaml.services.Keys | Sort-Object) -join ', '
            $ActualServiceNames | Should -Be $ExpectedServiceNames
        }

        Context '<servicename>' -Foreach $ExpectedServices {

            BeforeDiscovery {
                $expectedenvironment = @()
                if ($environment) {
                    $expectedenvironment = foreach ($item in $environment.GetEnumerator()) {
                        @{
                            Name  = $item.Name
                            Value = $item.Value
                        }
                    }
                }
                $expectPorts = if ($ports -is [hashtable]) {
                    ArrayizeHashHash($ports)
                }
                else {
                    @()
                }
            }

            BeforeAll {
                # $ExpectedService = $_
            }

            if ($image) {
                It 'image matches <image>' {
                    $stackyaml.services.$servicename.image | Should -Match $image
                }
            }

            It 'environment.<Name> = <Value>' -TestCases ($expectedenvironment) {
                $stackyaml.services.$servicename.environment.$Name | Should -Be $Value
            }


            if ($expectPorts) {
                It 'Port <Key> => <Value.HostName>:<Value.HostPort>' -TestCases $expectPorts {
                    $stackyaml.services.$servicename.Keys | Should -Contain 'ports'
                    $port = $stackyaml.services.$servicename.ports | Where-Object target -EQ $Key
                    $port | Should -Not -BeNullOrEmpty
                    $port.host_ip | Should -Be $Value.HostName
                    $port.published | Should -Be $Value.HostPort
                }
            }
            else {
                It 'No ports are published' {
                    $stackyaml.services.$servicename.Keys | Should -Not -Contain 'ports'
                }
            }

            if ($volumes) {
            }
        }

    }

}

