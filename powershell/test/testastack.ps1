param($Scenario, $Params, $expect)

Describe '<Scenario>' {

    BeforeDiscovery {
        $ExpectedServices = foreach ($svc in $expect.services.GetEnumerator()) {
            $h = $svc.value
            $h.servicename = $svc.name
            $h
        }
    }

    BeforeAll {
        Import-Module -Name (Join-Path $PSScriptRoot '../moodle-docker.psm1') -Force
        . (Join-Path $PSScriptRoot 'helpers.ps1')

        SetupStandardTestDirs

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

    Context '<servicename>' -ForEach $ExpectedServices {

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
                foreach ($item in $ports.GetEnumerator()) {
                    @{
                        Key   = $item.Key
                        Value = $item.Value
                    }
                }
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