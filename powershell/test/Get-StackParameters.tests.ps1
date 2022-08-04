Import-Module -Name (Join-Path $PSScriptRoot '../moodle-docker.psm1') -Force

InModuleScope 'moodle-docker' {

    Describe 'Get-StackParameters' {

        BeforeDiscovery {
        }

        BeforeAll {
            . (Join-Path $PSScriptRoot 'helpers.ps1')

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

        BeforeDiscovery {

            $testvals = @(
                @{
                    paramname = 'MOODLE_DOCKER_WWWROOT'
                    envval    = { TestDir MOODLE }
                    passedval = { TestDir MOODLE2 }
                }
                @{
                    paramname = 'MOODLE_DOCKER_PHP_VERSION'
                    default   = '7.4'
                    envval    = '7.1'
                    passedval = '7.2'
                }
                @{
                    paramname = 'MOODLE_DOCKER_DB'
                    default   = 'pgsql'
                    envval    = 'mysql'
                    passedval = 'oracle'
                }
                @{
                    paramname = 'MOODLE_DOCKER_BROWSER'
                    default   = 'firefox:3'
                    envval    = 'chrome:2'
                    passedval = 'firefox:4'
                }
                @{
                    paramname = 'MOODLE_DOCKER_WEB_HOST'
                    default   = 'localhost'
                    envval    = 'localhost2'
                    passedval = 'localhost3'
                }
                @{
                    paramname = 'MOODLE_DOCKER_WEB_PORT'
                    default   = $null
                    envval    = '6.6.6.6:6666'
                    passedval = '7.7.7.7:7777'
                }
                @{
                    paramname = 'MOODLE_DOCKER_APP_VERSION'
                    default   = $null
                    envval    = '3.4'
                    passedval = '3.5'
                }
                @{
                    paramname = 'MOODLE_DOCKER_APP_RUNTIME'
                    default   = $null
                    envval    = 'ionic3'
                    passedval = 'ionic5'
                }
                @{
                    paramname = 'MOODLE_DOCKER_APP_PATH'
                    default   = $null
                    envval    = { TestDir 'APP_3.9.4' }
                    passedval = { TestDir 'APP_3.9.5' }
                }
                @{
                    paramname = 'MOODLE_DOCKER_BEHAT_FAILDUMP'
                    default   = $null
                    envval    = { TestDir 'FAILDUMP' }
                    passedval = { TestDir 'FAILDUMP2' }
                }
                @{
                    paramname = 'MOODLE_DOCKER_SELENIUM_VNC_PORT'
                    default   = $null
                    envval    = '2.2.2.2:2222'
                    passedval = '3.3.3.3:3333'
                }
                @{
                    paramname = 'MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES'
                    default   = $null
                    envval    = 'abc'
                    envexpect = 'true'
                    passedval = $null
                }
            )
        }

        Context 'Sets correct defaults' {
            It '<paramname>' -TestCases $testvals {
                if (-Not $_.Contains('default')) {
                    Set-ItResult -Skipped -Because "$paramname has no default"
                }
                $expect = $_.default
                $passedargs = StackArgs @{}
                $Stack = New-Stack $passedargs
                $Stack.StackParams[$paramname] | Should -Be $expect
                # $stackparams = Get-StackParams $passedargs
                # $stackparams[$paramname] | Should -Be $expect
            }
        }

        Context 'Environment overides default' {
            It '<paramname>' -TestCases $testvals {
                $envval = ValOrEval($envval)
                $expect = ($_.Contains('envexpect')) ? (ValOrEval($_.envexpect)) : $envval
                Set-Item "Env:$paramname" -Value $envval
                $passedargs = StackArgs @{}
                $stackparams = Get-StackParams $passedargs
                $stackparams[$paramname] | Should -Be $expect
            }
        }
        Context 'Passed parameter overrides environment' {
            It '<paramname>' -TestCases $testvals {
                $envval = ValOrEval($envval)
                $expect = ($_.Contains('envexpect')) ? (ValOrEval($_.envexpect)) : $envval
                Set-Item "Env:$paramname" -Value $envval
                $passedargs = StackArgs @{}
                $stackparams = Get-StackParams $passedargs
                $stackparams[$paramname] | Should -Be $expect
            }
        }

        Context 'Accepts all valid parameter values' {

            It '<paramname>' -TestCases @(
                @{
                    paramname   = 'MOODLE_DOCKER_WWWROOT'
                    paramvalues = { TestDir MOODLE }, { TestDir MOODLE2 }
                }
                @{
                    paramname   = 'MOODLE_DOCKER_PHP_VERSION'
                    paramvalues = $VALID_PHP_VERSION
                }
                @{
                    paramname   = 'MOODLE_DOCKER_DB'
                    paramvalues = $VALID_DB
                }
                @{
                    paramname   = 'MOODLE_DOCKER_BROWSER'
                    paramvalues = 'chrome', 'chrome:4', 'firefox', 'firefox:4'
                }
                @{
                    paramname   = 'MOODLE_DOCKER_WEB_HOST'
                    paramvalues = 'host1', 'host2'
                }
                @{
                    paramname   = 'MOODLE_DOCKER_WEB_PORT'
                    paramvalues = '8000', '1.1.1.1.:8001'
                }
                @{
                    paramname   = 'MOODLE_DOCKER_APP_VERSION'
                    paramvalues = '3.4', '3.5'
                }
                @{
                    paramname   = 'MOODLE_DOCKER_APP_RUNTIME'
                    paramvalues = 'ionic3', 'ionic5'
                }
                @{
                    paramname   = 'MOODLE_DOCKER_APP_PATH'
                    paramvalues = $null, { TestDir 'APP_3.9.4' }, { TestDir 'APP_3.9.5' }
                }
                @{
                    paramname   = 'MOODLE_DOCKER_BEHAT_FAILDUMP'
                    paramvalues = $null, { TestDir 'FAILDUMP' }, { TestDir 'FAILDUMP2' }
                }
                @{
                    paramname   = 'MOODLE_DOCKER_SELENIUM_VNC_PORT'
                    paramvalues = $null, '1000', '1.1.1.1.:1001'
                }
                @{
                    paramname   = 'MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES'
                    paramvalues = $null, $false, 0, $true, 'true'
                }
            ) {
                foreach ($paramvalue in $paramvalues) {
                    $passedargs = StackArgs @{
                        $paramname = ValOrEval $paramvalue
                    }
                    { Get-StackParams $passedargs } | Should -Not -Throw -Because "$paramvalue is valid"
                }

            }

        }

        Context 'invalid parameter values' {

            It '<paramname>' -TestCases @(
                @{
                    paramname   = 'MOODLE_DOCKER_WWWROOT'
                    paramvalues = $null
                }
                @{
                    paramname   = 'MOODLE_DOCKER_PHP_VERSION'
                    paramvalues = '5.5'
                }
                @{
                    paramname   = 'MOODLE_DOCKER_DB'
                    paramvalues = 'sqllite'
                }
                @{
                    paramname   = 'MOODLE_DOCKER_BROWSER'
                    paramvalues = 'edge', 'chrome.3.3'
                }
                @{
                    paramname   = 'MOODLE_DOCKER_WEB_HOST'
                    paramvalues = '(&*^)'
                }
                @{
                    paramname   = 'MOODLE_DOCKER_WEB_PORT'
                    paramvalues = 'localhost:80'
                }
                @{
                    paramname   = 'MOODLE_DOCKER_APP_VERSION'
                    paramvalues = '3'
                }
                @{
                    paramname   = 'MOODLE_DOCKER_APP_RUNTIME'
                    paramvalues = 'ionic4'
                }
                @{
                    paramname   = 'MOODLE_DOCKER_APP_PATH'
                    paramvalues = { TestDir 'NODIR' }
                }
                @{
                    paramname   = 'MOODLE_DOCKER_BEHAT_FAILDUMP'
                    paramvalues = { TestDir 'NODIR' }
                }
                @{
                    paramname   = 'MOODLE_DOCKER_SELENIUM_VNC_PORT'
                    paramvalues = 'localhost:55'
                }
            ) {
                foreach ($paramvalue in $paramvalues) {
                    $passedargs = StackArgs @{
                        $paramname = ValOrEval $paramvalue
                    }
                    { Get-StackParams $passedargs } | Should -Throw -Because "$paramvalue is not valid"
                }

            }

            Context 'Invalid conditions' {

                It 'Disallows specifying both MOODLE_DOCKER_APP_PATH and MOODLE_DOCKER_APP_VERSION' {

                }

                It 'Throws if APP_PATH is used and package.json is missing' {

                }

                It 'Throws if APP_PATH is used and package.json is corrupt JSON' {

                }

                It 'Throws if APP_PATH is used and package.json does not specify version' {

                }
            }

            It 'Derives MOODLE_DOCKER_APP_RUNTIME' -TestCases @(
                @{
                    Arguments = @{
                        MOODLE_DOCKER_APP_VERSION = '3.9.4'
                    }
                    Expect    = @{
                        MOODLE_DOCKER_APP_RUNTIME = 'ionic3'
                    }
                }
                @{
                    Arguments = @{
                        MOODLE_DOCKER_APP_VERSION = '3.9.5'
                    }
                    Expect    = @{
                        MOODLE_DOCKER_APP_RUNTIME = 'ionic5'
                    }
                }
            ) {
                $Stack = New-Stack (StackArgs $Arguments)
                foreach($item in $Expect.GetEnumerator()) {
                    $Stack.StackParams[$item.name] | Should -Be $item.Value -Because "$($item.name) should be $($item.value)"
                }
            }

        }
    }
}