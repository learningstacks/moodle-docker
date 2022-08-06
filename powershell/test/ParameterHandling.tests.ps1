Import-Module -Name (Join-Path $PSScriptRoot '../moodle-docker.psm1') -Force

Describe 'Parameter Handling' {

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

        function AddRoot([hashtable]$test) {
            if ((-Not $test.stackenv.Contains('MOODLE_DOCKER_WWWROOT')) -and (-Not $test.stackargs.Contains('MOODLE_DOCKER_WWWROOT'))) {
                $test.stackargs.MOODLE_DOCKER_WWWROOT = { TestDir MOODLE }
            }
            $test
        }

        function TestDefault($expect) {
            @{
                rule        = "Defaults to $expect"
                stackenv    = @{}
                stackargs   = @{}
                expectvalue = $expect
            }
        }

        function TestEnvOverride($paramname, $EnvVal, $expect) {
            @{
                rule         = 'Environment overrides default'
                stackenv     = @{
                    $paramname = $enval
                }
                stackargs    = @{}
                expectvalues = @{
                    $paramname = $passedvalue
                }
            }
        }

        function TestPassOverride($paramname, $enval, $passedval, $expect) {
            @{
                rule         = 'Passed arg overrides environment'
                stackenv     = @{
                    $paramname = $EnvVal
                }
                stackargs    = @{
                    $paramname = $passedval
                }
                expectvalues = @{
                    $paramname = $passedvalue
                }
            }
        }

        function TestAccept($paramname, $passedval, $expect) {
            @{
                rule         = "Accepts $passedval"
                stackenv     = @{
                }
                stackargs    = @{
                    $paramname = $passedval
                }
                expectvalues = @{
                    $paramname = $expect
                }
            }
        }

        function TestReject($paramname, $passedval) {
            @{
                rule        = "Rejects invalid value $passedval"
                stackenv    = @{}
                stackargs   = @{
                    $paramname = $passedval
                }
                expectthrow = $true
            }

        }

        function ApplyTest($paramname, $stackenv, $stackargs, $expecTrhow, $expect) {
            if (-Not $stackenv) { $stackenv = @{} }
            if (-Not $stackargs) { $stackargs = @{} }
            if ($paramname -ne 'MOODLE_DOCKER_WWWROOT' -and !$stackenv.Contains('MOODLE_DOCKER_WWWROOT') -and !$stackargs.Contains('MOODLE_DOCKER_WWWROOT')) {
                $stackargs.MOODLE_DOCKER_WWWROOT = (TestDir MOODLE)
            }

            foreach ($varname in [array]$stackenv.keys) {
                Set-Item "Env:$varname" -Value (ValOrEval $stackenv.$varname)
            }

            foreach ($varname in [array]$stackargs.keys) {
                $stackargs.$varname = ValOrEval $stackargs.$varname
            }

            if ($expectthrow) {
                { New-Stack $stackargs } | Should -Throw
            }
            else {
                $Stack = New-Stack $stackargs
                $Stack.StackParams.$paramname | Should -Be (ValOrEval $expectvalue)
            }
        }

        function HasNullDefault($paramname) {
            It 'Defaults to $null' {
                ApplyTest -expectvalues @{
                    $paramname = $null
                }
            }
        }

        function IsMandatory() {

        }

        function EnvOverrides($paramname, $val, $expectvalue) {
            It 'Environment overrides default' {
                $test = @{
                    stackenv     = @{
                        $paramname = ValOrEval $val
                    }
                    expectvalues = @{
                        $paramname = ValOrEval $expectvalue
                    }
                }
                ApplyTest @test
            }
        }

        function ArgOverrides($paramname, $val, $val2, $expectvalue) {
            It 'Passed arg overrides environment' {
                $test = @{
                    stackenv     = @{
                        $paramname = ValOrEval $val
                    }
                    stackargs    = @{
                        $paramname = ValOrEval $val2
                    }
                    expectvalues = @{
                        $paramname = ValOrEval $expectvalue
                    }
                }
                ApplyTest @test
            }
        }
    }

    function DirMustExist($paramname) {

    }

    function Accepts($paramname, $val, $expectvalue) {
        $val = ValOrEval $val
        It "Accepts $val" {
            $test = @{
                stackargs    = @{
                    $paramname = $val
                }
                expectvalues = @{
                    $paramname = ValOrEval $expectvalue
                }
            }
            ApplyTest @test
        }
    }

    function Rejects($paramname, $val) {
        It "Rejects $val" {
            $test = @{
                stackargs   = @{
                    $paramname = ValOrEval $val
                }
                expectthrow = $true
            }
            ApplyTest @test
        }
    }

    function NormalizesPort($paramname, $val, $expectedvalue) {

    }

    $tests = @(
        @{ paramname = 'MOODLE_DOCKER_WWWROOT'
            tests    = & {
                @{
                    rule        = 'Is required'
                    stackenv    = @{}
                    stackargs   = @{}
                    expectthrow = $true
                }
                @{
                    rule        = 'Must reference an existing directory'
                    stackenv    = @{}
                    stackargs   = @{MOODLE_DOCKER_WWWROOT = { TestDir NODIR } }
                    expectthrow = $true
                }
                @{
                    rule        = 'Environment overrides default'
                    stackenv    = @{MOODLE_DOCKER_WWWROOT = { TestDir MOODLE } }
                    stackargs   = @{}
                    expectvalue = { TestDir MOODLE }
                }
                @{
                    rule        = 'Passed arg overrides environment'
                    stackenv    = @{MOODLE_DOCKER_WWWROOT = { TestDir MOODLE } }
                    stackargs   = @{MOODLE_DOCKER_WWWROOT = { TestDir MOODLE2 } }
                    expectvalue = { TestDir MOODLE2 }
                }
            }
        }
        @{ paramname = 'MOODLE_DOCKER_PHP_VERSION'
            tests    = & {
                @{
                    rule        = 'Defaults to 7.4'
                    expectvalue = '7.4'
                }
                @{
                    rule        = 'Environment overrides default'
                    stackenv    = @{
                        MOODLE_DOCKER_PHP_VERSION = '7.1'
                    }
                    expectvalue = '7.1'
                }
                @{
                    rule        = 'Passed arg overrides environment'
                    stackenv    = @{
                        MOODLE_DOCKER_PHP_VERSION = '7.1'
                    }
                    stackargs   = @{
                        MOODLE_DOCKER_PHP_VERSION = '7.2'
                    }
                    expectvalue = '7.2'
                }
                foreach ($val in $VALID_PHP_VERSION) {
                    @{
                        rule        = "Accepts $val"
                        stackenv    = @{ }
                        stackargs   = @{
                            MOODLE_DOCKER_PHP_VERSION = $val
                        }
                        expectvalue = $val
                    }
                }
                foreach ($val in '5.5') {
                    @{
                        rule        = "Rejects $val"
                        stackenv    = @{ }
                        stackargs   = @{
                            MOODLE_DOCKER_PHP_VERSION = $val
                        }
                        expectthrow = $true
                    }
                }
            }
        }
        @{ paramname = 'MOODLE_DOCKER_DB'
            tests    = & {
                @{
                    rule        = 'Defaults to pgsql'
                    expectvalue = 'pgsql'
                }
                @{
                    rule        = 'Environment overrides default'
                    stackenv    = @{
                        MOODLE_DOCKER_DB = 'mysql'
                    }
                    expectvalue = 'mysql'
                }
                @{
                    rule        = 'Passed arg overrides environment'
                    stackenv    = @{
                        MOODLE_DOCKER_DB = 'mysql'
                    }
                    stackargs   = @{
                        MOODLE_DOCKER_DB = 'mariadb'
                    }
                    expectvalue = 'mariadb'
                }
                foreach ($val in $VALID_DB) {
                    @{
                        rule        = "Accepts $val"
                        stackargs   = @{
                            MOODLE_DOCKER_DB = $val
                        }
                        expectvalue = $val
                    }
                }
                foreach ($val in 'otherdb') {
                    @{
                        rule        = "Rejects $val"
                        stackargs   = @{
                            MOODLE_DOCKER_DB = $val
                        }
                        expectthrow = $true
                    }
                }
            }
        }
        @{ paramname = 'MOODLE_DOCKER_BROWSER'
            tests    = & {
                @{
                    rule        = 'Defaults to firefox:3'
                    expectvalue = 'firefox:3'
                }
                @{
                    rule        = 'Environment overrides default'
                    stackenv    = @{
                        MOODLE_DOCKER_BROWSER = 'chrome:3'
                    }
                    expectvalue = 'chrome:3'
                }
                @{
                    rule        = 'Passed arg overrides environment'
                    stackenv    = @{
                        MOODLE_DOCKER_BROWSER = 'chrome:3'
                    }
                    stackargs   = @{
                        MOODLE_DOCKER_BROWSER = 'firefox:4'
                    }
                    expectvalue = 'firefox:4'
                }
                foreach ($val in 'chrome', 'firefox', 'chrome:3', 'firefox:4') {
                    @{
                        rule        = "Accepts $val"
                        stackargs   = @{
                            MOODLE_DOCKER_BROWSER = $val
                        }
                        expectvalue = $val
                    }
                }
                foreach ($val in 'safari', 'edge') {
                    @{
                        rule        = "Rejects $val"
                        stackargs   = @{
                            MOODLE_DOCKER_BROWSER = $val
                        }
                        expectthrow = $true
                    }
                }
            }
        }
        @{paramname = 'MOODLE_DOCKER_WEB_HOST'
            tests   = & {
                @{
                    rule        = 'Defaults to localhost'
                    expectvalue = 'localhost'
                }
                @{
                    rule        = 'Environment overrides default'
                    stackenv    = @{
                        MOODLE_DOCKER_WEB_HOST = 'host1'
                    }
                    expectvalue = 'host1'
                }
                @{
                    rule        = 'Passed arg overrides environment'
                    stackenv    = @{
                        MOODLE_DOCKER_WEB_HOST = 'host1'
                    }
                    stackargs   = @{
                        MOODLE_DOCKER_WEB_HOST = 'host2'
                    }
                    expectvalue = 'host2'
                }
            }
        }
        @{paramname = 'MOODLE_DOCKER_WEB_PORT'
            tests   = & {
                @{
                    rule        = 'Defaults to $null'
                    expectvalue = $null
                }
                @{
                    rule        = 'Environment overrides default'
                    stackenv    = @{
                        MOODLE_DOCKER_WEB_PORT = '1.1.1.1:1'
                    }
                    expectvalue = '1.1.1.1:1'
                }
                @{
                    rule        = 'Passed arg overrides environment'
                    stackenv    = @{
                        MOODLE_DOCKER_WEB_PORT = '1.1.1.1:1'
                    }
                    stackargs   = @{
                        MOODLE_DOCKER_WEB_PORT = '2.2.2.2:2'
                    }
                    expectvalue = '2.2.2.2:2'
                }
                @{
                    rule        = 'Assigns host = 127.0.0.1 if not specified'
                    stackargs   = @{
                        MOODLE_DOCKER_WEB_PORT = '2'
                    }
                    expectvalue = '127.0.0.1:2'
                }
            }
        }
        @{ paramname = 'MOODLE_DOCKER_APP_VERSION'
            tests    = & {
                @{
                    rule        = 'Defaults to $null'
                    expectvalue = $null
                }
                @{
                    rule        = 'Environment overrides default'
                    stackenv    = @{
                        MOODLE_DOCKER_APP_VERSION = '3.4'
                    }
                    expectvalue = '3.4'
                }
                @{
                    rule        = 'Passed arg overrides environment'
                    stackenv    = @{
                        MOODLE_DOCKER_APP_VERSION = '3.4'
                    }
                    stackargs   = @{
                        MOODLE_DOCKER_APP_VERSION = '3.5'
                    }
                    expectvalue = '3.5'
                }
                foreach ($val in '3.4', '3.5.1') {
                    @{
                        rule        = "Accepts $val"
                        stackargs   = @{
                            MOODLE_DOCKER_APP_VERSION = $val
                        }
                        expectvalue = $val
                    }
                }

                foreach ($val in 'abc') {
                    @{
                        rule        = "Rejects $val"
                        stackargs   = @{
                            MOODLE_DOCKER_APP_VERSION = $val
                        }
                        expectthrow = $true
                    }
                }

            }
        }
        @{paramname = 'MOODLE_DOCKER_SELENIUM_VNC_PORT'
            rules   = & {
                HasNullDefault
                EnvOverride $val1
                ArgOverride $val1 $val2
                DirExists
                Accepts 'a', 'b'
                Rejects 'z'
                NormalizesPort
            }
            tests   = & {
                @{
                    rule        = 'Defaults to $null'
                    expectvalue = $null
                }
                @{
                    rule        = 'Environment overrides default'
                    stackenv    = @{
                        MOODLE_DOCKER_SELENIUM_VNC_PORT = '1.1.1.1:1'
                    }
                    expectvalue = '1.1.1.1:1'
                }
                @{
                    rule        = 'Passed arg overrides environment'
                    stackenv    = @{
                        MOODLE_DOCKER_SELENIUM_VNC_PORT = '1.1.1.1:1'
                    }
                    stackargs   = @{
                        MOODLE_DOCKER_SELENIUM_VNC_PORT = '2.2.2.2:2'
                    }
                    expectvalue = '2.2.2.2:2'
                }
                @{
                    rule        = 'Assigns host = 127.0.0.1 if not specified'
                    stackargs   = @{
                        MOODLE_DOCKER_SELENIUM_VNC_PORT = '2'
                    }
                    expectvalue = '127.0.0.1:2'
                }
            }
        }
        @{paramname = 'MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES'
            tests   = & {
                @{
                    rule        = 'Defaults to $null'
                    expectvalue = $null
                }
                @{
                    rule        = 'Environment overrides default'
                    stackenv    = @{
                        MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES = $true
                    }
                    expectvalue = 'true'
                }
                @{
                    rule        = 'Passed arg overrides environment'
                    stackenv    = @{
                        MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES = $true
                    }
                    stackargs   = @{
                        MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES = ''
                    }
                    expectvalue = $null
                }
                foreach ($val in 'abc', $true) {
                    @{
                        rule        = "Non-empty value ('$val') results in 'true'"
                        stackargs   = @{
                            MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES = $val
                        }
                        expectvalue = 'true'
                    }
                }
                foreach ($val in $false, $null, '') {
                    @{
                        rule        = "Empty value ('$val') results in `$null"
                        stackargs   = @{
                            MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES = $val
                        }
                        expectvalue = $null
                    }
                }
            }
        }

        # @{                paramname = 'MOODLE_DOCKER_APP_RUNTIME'
        #     default                 = $null
        #     envval                  = 'ionic3'
        #     passedval               = 'ionic5'
        # }
        @{ paramname = 'MOODLE_DOCKER_APP_PATH'
            tests    = & {
                @{
                    rule        = 'Defaults to $null'
                    expectvalue = $null
                }
                @{
                    rule        = 'Environment overrides default'
                    stackenv    = @{
                        $paramname = { TestDir 'APP_3.9.4' }
                    }
                    expectvalue = { TestDir 'APP_3.9.4' }
                }
                @{
                    rule        = 'Passed arg overrides environment'
                    stackenv    = @{
                        $paramname = { TestDir 'APP_3.9.4' }
                    }
                    stackargs   = @{
                        $paramname = { TestDir 'APP_3.9.4' }
                    }
                    expectvalue = { TestDir 'APP_3.9.5' }
                }
                @{
                    rule        = 'Directory must exist'
                    stackargs   = @{
                        $paramname = { TestDir NODIR }
                    }
                    expectthrow = $true
                }

            }
        }
        # @{                paramname = 'MOODLE_DOCKER_APP_PATH'
        #     default                 = $null
        #     envval                  = { TestDir 'APP_3.9.4' }
        #     passedval               = { TestDir 'APP_3.9.5' }
        # }
        # @{                paramname = 'MOODLE_DOCKER_BEHAT_FAILDUMP'
        #     default                 = $null
        #     envval                  = { TestDir 'FAILDUMP' }
        #     passedval               = { TestDir 'FAILDUMP2' }
        # }
    )

    $run = $tests | Where-Object { $_.paramname -in 'MOODLE_DOCKER_APP_PATH' }
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


Context '<paramname>' -Foreach $run {

    It '<rule>' -TestCases $tests {
        if (-Not $stackenv) { $stackenv = @{} }
        if (-Not $stackargs) { $stackargs = @{} }
        if ($paramname -ne 'MOODLE_DOCKER_WWWROOT' -and !$stackenv.Contains('MOODLE_DOCKER_WWWROOT') -and !$stackargs.Contains('MOODLE_DOCKER_WWWROOT')) {
            $stackargs.MOODLE_DOCKER_WWWROOT = (TestDir MOODLE)
        }

        foreach ($varname in [array]$stackenv.keys) {
            Set-Item "Env:$varname" -Value (ValOrEval $stackenv.$varname)
        }

        foreach ($varname in [array]$stackargs.keys) {
            $stackargs.$varname = ValOrEval $stackargs.$varname
        }

        if ($expectthrow) {
            { New-Stack $stackargs } | Should -Throw
        }
        else {
            $Stack = New-Stack $stackargs
            $Stack.StackParams.$paramname | Should -Be (ValOrEval $expectvalue)
        }
    }
}


# Context 'Defaults' {
#     It '<paramname>' -TestCases $testvals {
#         if (-Not $_.Contains('default')) {
#             Set-ItResult -Skipped -Because "$paramname has no default"
#         }
#         $expect = $_.default
#         $passedargs = StackArgs @{}
#         $Stack = New-Stack $passedargs
#         $Stack.StackParams[$paramname] | Should -Be $expect
#         # $stackparams = Get-StackParams $passedargs
#         # $stackparams[$paramname] | Should -Be $expect
#     }
# }

# Context 'Environment overides' {
#     It '<paramname>' -TestCases $testvals {
#         $envval = ValOrEval($envval)
#         $expect = ($_.Contains('envexpect')) ? (ValOrEval($_.envexpect)) : $envval
#         Set-Item "Env:$paramname" -Value $envval
#         $passedargs = StackArgs @{}
#         $Stack = New-Stack $passedargs
#         $Stack.StackParams[$paramname] | Should -Be $expect
#     }
# }
# Context 'Passed parameter overrides' {
#     It '<paramname>' -TestCases $testvals {
#         $envval = ValOrEval($envval)
#         $expect = ($_.Contains('envexpect')) ? (ValOrEval($_.envexpect)) : $envval
#         Set-Item "Env:$paramname" -Value $envval
#         $passedargs = StackArgs @{}
#         $Stack = New-Stack $passedargs
#         $Stack.StackParams[$paramname] | Should -Be $expect
#     }
# }

# Context 'Valid parameter values' {

#     It '<paramname>' -TestCases @(
#         @{
#             paramname   = 'MOODLE_DOCKER_WWWROOT'
#             paramvalues = { TestDir MOODLE }, { TestDir MOODLE2 }
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_PHP_VERSION'
#             paramvalues = $VALID_PHP_VERSION
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_DB'
#             paramvalues = $VALID_DB
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_BROWSER'
#             paramvalues = 'chrome', 'chrome:4', 'firefox', 'firefox:4'
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_WEB_HOST'
#             paramvalues = 'host1', 'host2'
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_WEB_PORT'
#             paramvalues = '8000', '1.1.1.1.:8001'
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_APP_VERSION'
#             paramvalues = '3.4', '3.5'
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_APP_RUNTIME'
#             paramvalues = 'ionic3', 'ionic5'
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_APP_PATH'
#             paramvalues = $null, { TestDir 'APP_3.9.4' }, { TestDir 'APP_3.9.5' }
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_BEHAT_FAILDUMP'
#             paramvalues = $null, { TestDir 'FAILDUMP' }, { TestDir 'FAILDUMP2' }
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_SELENIUM_VNC_PORT'
#             paramvalues = $null, '1000', '1.1.1.1.:1001'
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES'
#             paramvalues = $null, $false, 0, $true, 'true'
#         }
#     ) {
#         foreach ($paramvalue in $paramvalues) {
#             $passedargs = StackArgs @{
#                 $paramname = ValOrEval $paramvalue
#             }
#             { New-Stack $passedargs } | Should -Not -Throw -Because "$paramvalue is valid"
#         }

#     }

# }

# Context 'Invalid parameter values' {

#     It '<paramname>' -TestCases @(
#         @{
#             paramname   = 'MOODLE_DOCKER_WWWROOT'
#             paramvalues = $null
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_PHP_VERSION'
#             paramvalues = '5.5'
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_DB'
#             paramvalues = 'sqllite'
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_BROWSER'
#             paramvalues = 'edge', 'chrome.3.3'
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_WEB_HOST'
#             paramvalues = '(&*^)'
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_WEB_PORT'
#             paramvalues = 'localhost:80'
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_APP_VERSION'
#             paramvalues = '3'
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_APP_RUNTIME'
#             paramvalues = 'ionic4'
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_APP_PATH'
#             paramvalues = { TestDir 'NODIR' }
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_BEHAT_FAILDUMP'
#             paramvalues = { TestDir 'NODIR' }
#         }
#         @{
#             paramname   = 'MOODLE_DOCKER_SELENIUM_VNC_PORT'
#             paramvalues = 'localhost:55'
#         }
#     ) {
#         foreach ($paramvalue in $paramvalues) {
#             $passedargs = StackArgs @{
#                 $paramname = ValOrEval $paramvalue
#             }
#             { New-Stack $passedargs } | Should -Throw -Because "$paramvalue is not valid"
#         }

#     }

#     Context 'Invalid conditions' {

#         It 'Disallows specifying both MOODLE_DOCKER_APP_PATH and MOODLE_DOCKER_APP_VERSION' {

#         }

#         It 'Throws if APP_PATH is used and package.json is missing' {

#         }

#         It 'Throws if APP_PATH is used and package.json is corrupt JSON' {

#         }

#         It 'Throws if APP_PATH is used and package.json does not specify version' {

#         }
#     }

#     It 'Derives MOODLE_DOCKER_APP_RUNTIME' -TestCases @(
#         @{
#             Arguments = @{
#                 MOODLE_DOCKER_APP_VERSION = '3.9.4'
#             }
#             Expect    = @{
#                 MOODLE_DOCKER_APP_RUNTIME = 'ionic3'
#             }
#         }
#         @{
#             Arguments = @{
#                 MOODLE_DOCKER_APP_VERSION = '3.9.5'
#             }
#             Expect    = @{
#                 MOODLE_DOCKER_APP_RUNTIME = 'ionic5'
#             }
#         }
#     ) {
#         $Stack = New-Stack (StackArgs $Arguments)
#         foreach ($item in $Expect.GetEnumerator()) {
#             $Stack.StackParams[$item.name] | Should -Be $item.Value -Because "$($item.name) should be $($item.value)"
#         }
#     }

# }
}
