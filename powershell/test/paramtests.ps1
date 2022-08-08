Import-Module -Name (Join-Path $PSScriptRoot '../moodle-docker.psm1') -Force
$DebugPreference = 'continue'

Describe 'Parameter handling' {

    BeforeDiscovery {
        function TestPair([array]$spec) {
            try {
                $testpair = switch ($spec.count) {
                    1 { @{value = $spec[0]; expect = $spec[0] } }
                    2 { @{value = $spec[0]; expect = $spec[1] } }
                    default { throw }
                }
                return $testpair
            }
            catch {
                throw
            }
        }

        function TestPairs([array]$testvals = @()) {
            try {
                $testpairs = foreach ($val in $testvals) {
                    TestPair $val
                }
                return $testpairs
            }
            catch {
                throw
            }
        }

        $VALID_DB = 'pgsql', 'mysql', 'mssql', 'oracle', 'mariadb'
        $VALID_PHP_VERSION = '5.6', '7.0', '7.1', '7.2', '7.3', '7.4', '8.0'
        $VALID_APP_RUNTIME = 'ionic3', 'ionic5'

        $paramspecs = @{
            MOODLE_DOCKER_WWWROOT                   = @{
                Mandatory   = $true
                ValidVals   = @(
                    { TestDir 'MOODLE' }
                    { TestDir 'MOODLE2' }
                )
                InvalidVals = @(
                    $null
                    { TestDir 'NODIR' }
                )
            }
            MOODLE_DOCKER_PHP_VERSION               = @{
                Default     = '7.4'
                ValidVals   = $VALID_PHP_VERSION
                InvalidVals = @(
                    $null
                    '5.5'
                )
            }
            MOODLE_DOCKER_DB                        = @{
                Default     = 'pgsql'
                ValidVals   = $VALID_DB
                InvalidVals = @(
                    'otherdb'
                )
            }
            MOODLE_DOCKER_BROWSER                   = @{
                Default     = 'firefox:3'
                ValidVals   = @(
                    , @('chrome')
                    , @('firefox')
                    , @('chrome:4')
                    , @('firefox:5')
                )
                InvalidVals = @(
                    'safari'
                    'edge'
                )
            }
            MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES = @{
                Default   = $null
                ValidVals = @(
                    , @('', $null)
                    , @('true', 'true')
                    , @($null, $null)
                    , @($false, $null)
                    , @('nonempty', 'true')
                    , @($true, 'true')
                )
            }
            MOODLE_DOCKER_BEHAT_FAILDUMP            = @{
                Default     = $null
                ValidVals   = @(
                    { TestDir 'FAILDUMP' }
                    { TestDir 'FAILDUMP2' }
                )
                InvalidVals = @(
                    { TestDir 'NODIR' }
                )

            }
            MOODLE_DOCKER_WEB_HOST                  = @{
                Default     = $null
                validvals   = @(
                    'localhost'
                    'a.b.com'
                )
                invalidvals = '%$#'
            }
            MOODLE_DOCKER_WEB_PORT                  = @{
                Default     = $null
                validvals   = @(
                    , @('40', '127.0.0.1:40')
                    , @('1.1.1.1:40', '1.1.1.1:40')
                )
                invalidvals = @(
                    'noport'
                )
            }
            MOODLE_DOCKER_SELENIUM_VNC_PORT         = @{
                default     = $null
                validvals   = @(
                    , @('40', '127.0.0.1:40')
                    , @('1.1.1.1:40', '1.1.1.1:40')
                )
                invalidvals = @(
                    'noport'
                )
            }
            MOODLE_DOCKER_APP_PATH                  = @{
                Default     = $null
                ValidVals   = @(
                    { TestDir 'APP_3.9.4' }
                    { TestDir 'APP_3.9.5' }
                )
                InvalidVals = @(
                    { TestDir 'NODIR' }
                )
            }
            MOODLE_DOCKER_APP_VERSION               = @{
                Default = $null
            }
            MOODLE_DOCKER_APP_RUNTIME               = @{
                # Default     = $null
                # ValidVals   = $VALID_APP_RUNTIME
                # V           = @(
                #     @{
                #         StackArgs = @{
                #             MOODLE_DOCKER_APP_PATH = { TestDir 'APP_3.9.4' }
                #         }
                #         TestVals = @(
                #             'ionic3'
                #         )
                #     }
                # )
                # InvalidVals = @(
                #     ''
                #     'ionic4'
                # )
                ApplyTests = & {

                    TestGroup -paramname $paramname -GroupName 'Null if no app' -ArgNames 'APP_PATH', 'APP_VERSION', 'APP_RUNTIME' -Values @(
                        ATest -env @() -arg $null, $null, 'ionic3', $null)
                        @($null, $null, 'ionic5', $null)

                    )
                    $itdesc = 'APP_PATH ({0}), APP_VERSION ({1}), APP_RUNTIME ({2}) => {3})'
                    $testgroups = @(
                        @{
                            group     = 'Null if no app'
                            $testvals = @(
                            )
                        }
                        @{
                            group     = 'Value derivation'
                            $testvals = @(
                                @( { TestDir 'APP_3.9.4' }, $null, $null, 'ionic3')
                                @( { TestDir 'APP_3.9.5' }, $null, $null, 'ionic5')
                                @($null, '3.9.4', $null, 'ionic3')
                                @($null, '3.9.5', $null, 'ionic5')
                            )
                        }
                        @{
                            group     = 'Override Value derivation'
                            $testvals = @(
                                @( { TestDir 'APP_3.9.4' }, 'ionic5', $null, 'ionic3')
                                @( { TestDir 'APP_3.9.5' }, $null, 'ionic3', 'ionic3')
                                @($null, '3.9.4', 'ionic5', 'ionic5')
                                @($null, '3.9.5', 'ionic3', 'ionic3')
                            )
                        }
                    )
                    foreach ($group in $testgroups) {
                        @{
                            group = $group.group
                            tests = foreach ($valset in $group.testvals) {
                                $test = @{
                                    rule      = $itdesc -f $valset
                                    StackArgs = @{}
                                }
                                foreach ($i in 0..$params.count-2) {
                                    $test.StackArgs[$params[$i]] = $valset[$i]
                                }
                                $test.expect = $valset[$params.count - 1]
                            }
                        }
                    }
                    # @{
                    #     rule      = "forced to `null if neither APP_VERSION nor APP_PATH are defined"
                    #     stackargs = @{
                    #         MOODLE_DOCKER_RUNTIME = 'ionic3'
                    #     }
                    #     expect    = $null
                    # }
                    # foreach ($valset in @('3.9.4', 'ionic3'), @('3.9.5', 'ionic5')) {
                    #     @{
                    #         rule      = 'Defaults to $valset[1] when APP_PATH/package.json/version = $valset[0]'
                    #         stackargs = @{
                    #             MOODLE_DOCKER_PATH = { TestDir "APP_$valset[0]" }
                    #         }
                    #         expect    = $valset[1]
                    #     }
                    # }
                    # foreach ($valset in @('3.9.4', 'ionic3'), @('3.9.5', 'ionic4')) {
                    #     @{
                    #         rule      = 'MOODLE_DOCKER_APP_VERSION => APP_VERSION (version 3.9.4'
                    #         stackargs = @{
                    #             MOODLE_DOCKER_APP_VERSION = { TestDir 'APP_3.9.4' }
                    #         }
                    #         expect    = 'ionic3'
                    #     }
                    #     @{
                    #         rule      = 'Derives value from APP_VERSION (version 3.9.5)'
                    #         stackargs = @{
                    #             MOODLE_DOCKER_APP_VERSION = { TestDir 'APP_3.9.5' }
                    #         }
                    #         expect    = 'ionic5'
                    #     }
                    #     foreach ($valset in @('3.9.4', 'ionic5'), @('3.9.5', 'ionic3')) {
                    #         @{
                    #             rule      = "Passed value $valset[1] overrides value derived from APP_VERSION $valset[0]"
                    #             stackargs = @{
                    #                 MOODLE_DOCKER_APP_VERSION = $valset[0]
                    #                 MOODLE_DOCKER_APP_RUNTIME = $valset[1]
                    #             }
                    #             expect    = $valset[1]
                    #         }
                    #     }
                    #     foreach ($valset in @('APP_3.9.4', 'ionic5'), @('APP_3.9.5', 'ionic3')) {
                    #         @{
                    #             rule      = 'Passed value ($($valset[1]) overrides value derived from APP_PATH ($($valset[0])'
                    #             stackargs = @{
                    #                 MOODLE_DOCKER_APP_PATH    = { TestDir $valset[0] }
                    #                 MOODLE_DOCKER_APP_RUNTIME = $valset[1]
                    #             }
                    #             expect    = $valset[1]
                    #         }
                    #     }

                }
            }
        }.GetEnumerator() | ForEach-Object {
            $spec = $_.value
            $spec.paramname = $_.key
            if ($spec.ValidVals -is [array]) {
                $spec.ValidVals = TestPairs $spec.ValidVals
            }
            $spec
        }
    }

    BeforeAll {
        . (Join-Path $PSScriptRoot 'helpers.ps1')
        Import-Module -Name (Join-Path $PSScriptRoot '../moodle-docker.psm1') -Force

        SetupStandardTestDirs

        function ApplyTest($paramname, $stackenv = @{}, $stackargs = @{}, $expectThrow = $false, $expect) {

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
                                value     = (ValOrEval $item.value)
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
                    $Stack.StackParams[$item.paramname] | Should -Be $item.expectval
                }
            }
        }
    }

    # Context "Mandatory parameter" {
    #     It '<paramname> is required' -TestCases ($paramspecs | Where-Object { $_.Mandatory }) {
    #         $test = @{
    #             expectthrow = $true
    #         }
    #         ApplyTest @test
    #     }
    # }

    Context 'Defaults' {
        It '<paramname> = <default>' -TestCases ($paramspecs | Where-Object { $_.containskey('Default') }) {
            $test = @{
                paramname = $paramname
                expect    = (ValOrEval $default)
            }
            ApplyTest @test
        }
    }
    Context 'Accepts all valid values' {
        BeforeDiscovery {
            $specs = $paramspecs | Where-Object { $_.containskey('ValidVals') }
        }
        # foreach ($spec in $specs) {
        Context '<spec.paramname>' -ForEach $specs {
            BeforeDiscovery {
                $spec = $_
            }
            BeforeAll {
                $spec = $_
            }
            It '<value> => <expect>' -TestCases $spec.ValidVals {
                $test = @{
                    paramname = $paramname
                    stackargs = @{
                        $paramname = $value
                    }
                    expect    = (ValOrEval $expect)
                }
                ApplyTest @test
            }
        }
        # }
        # Context '<paramname>' -ForEach $specs {
        #     BeforeAll {
        #         $spec = $_
        #         $testpairs = TestPairs $spec.ValidVals
        #     }
        #     It '<paramname> = <expect>' -TestCases $testpairs {
        #         $test = @{
        #             paramname = $paramname
        #             stackargs = @{
        #                 $paramname = $value
        #             }
        #             expect    = (ValOrEval $expect)
        #         }
        #         ApplyTest @test
        #     }
        # }
    }

    Context 'Rejects invalid values' {
        Context '<paramname>' -ForEach ($paramspecs | Where-Object { $_.containskey('InvalidVals') }) {
            It '<value>' -TestCases ($_.InvalidVals) {
                $test = @{
                    paramname   = $paramname
                    stackargs   = @{
                        $paramname = (ValOrEval $_)
                    }
                    expectthrow = $true
                }
                ApplyTest @test
            }
        }
    }

    Context 'Environment overrides defaul' {
        It '<paramname>' -ForEach ($paramspecs | Where-Object { $_.containskey('ValidVals') }) {
            $test = @{
                paramname = $paramname
                stackenv  = @{
                    $paramname = $value
                }
                expect    = (ValOrEval $expect)
            }
            ApplyTest @test
        }
    }

    # Context 'Argument overrides environment' {
    #     BeforeDiscovery {
    #         # $testcases = & {
    #         #     $paramstotest = $paramspecs | Where-Object { $_.containskey('ValidVals') -and $_.ValidVals.count -ge 2 }
    #         #     foreach($)
    #         # }
    #     }
    #     It '<paramname>' -Foreach ($paramspecs | Where-Object {
    #             $_.containskey('ValidVals') -and $_.ValidVals.count -ge 2
    #         })
    #     {
    #         $test = @{
    #             paramname = $paramname
    #             stackenv = @{
    #                 $paramname = $value
    #             }
    #             stackargs
    #             expect = (ValOrEval $expect)
    #         }
    #         ApplyTest @test
    #     }

    # }

    Context 'Other rules' {
        Context '<paramname>' -ForEach ($paramspecs | Where-Object { $_.containskey('ApplyTests') }) {
            It '<rule>' -TestCases ($_.ApplyTests) {
                ApplyTest @$_
            }
        }
    }

}

