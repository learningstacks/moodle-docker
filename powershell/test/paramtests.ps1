$DebugPreference = 'continue'

. (Join-Path $PSScriptRoot 'helpers.ps1')

function TestEnvOverride($paramname, $envval, $expect) {
    Write-Debug "    TestArgOverride $paramname, $envval, $expect"

    It 'Environment overrides default' {
        $test = @{
            stackenv     = @{
                $paramname = ValOrEval $envval
            }
            expectvalues = @{
                $paramname = ValOrEval $expect
            }
        }
        ApplyTest @test
    }
}

Describe 'Paramater handling' {

    BeforeDiscovery {
        function TestPair([array]$spec) {
            $testpair = switch ($spec.count) {
                1 { @{value = $spec[0]; expect = $spec[0] } }
                2 { @{value = $spec[0]; expect = $spec[1] } }
                default { throw }
            }
            return $testpair
        }

        function TestPairs([array]$testvals = @()) {
            $testpairs = foreach ($val in $testvals) {
                TestPair $val
            }
            return $testpairs
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
                    , @('chrome', 'chrome:3')
                    , @('firefox', 'firefox:3')
                    , @('chrome:4', 'chrome:4')
                    , @('firefox:5', 'firefox:5')
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
                invalidvals = @(
                    '%$#'
                )
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
                Default     = $null
                ValidVals   = $VALID_APP_RUNTIME
                InvalidVals = @(
                    ''
                    'ionic4'
                )
            }
        }
    }

    BeforeAll {
        function ApplyTest($paramname, $stackenv = @{}, $stackargs = @{}, $expecThow = $false, $expect) {
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
            elseif ($expect -is [hashtable]) {
            }
            else {}
            $Stack = New-Stack $stackargs
            $Stack.StackParams.$paramname | Should -Be (ValOrEval $expect)
        }

    }

    Context 'Environment overrides default' {

        BeforeDiscovery {
            $testcases = foreach ($item in $paramspecs.GetEnumerator()) {
                $paramname = $item.Key
                $spec = $item.value
                [array]$testpairs = ($spec.ContainsKey('ValidVals')) ? (TestPairs $spec.ValidVals) : @()
                if ($testpairs) {
                    @{
                        paramname = $paramname
                        envval    = $testpairs[0].value
                        expect    = $testpairs[0].expect
                    }
                }
            }
        }

        It '<paramname>' -TestCases $testcases -Tag $paramname {
            ApplyTest @{
                stackenv = @{
                    $paramname = ValOrEval $_.envval
                }
                # expect   = $_.expect
                expect   = 4
            }

        }
    }

}


function TestArgOverride($paramname, $envval, $argval, $expect) {
    Write-Debug "    TestArgOverride $paramname, $envval, $expect"
    It 'Passed arg overrides environment' {
        $test = @{
            stackenv     = @{
                $paramname = ValOrEval $envval
            }
            stackargs    = @{
                $paramname = ValOrEval $argval
            }
            expectvalues = @{
                $paramname = ValOrEval $expect
            }
        }
        ApplyTest @test
    }
}

function TestDefault($paramname, $expect) {
    Write-Debug "    TestDefault $(($null -eq $expect) ? '$null' : $expect)"
}

function TestMandatory($paramname) {
    Write-Debug '    TestMandatory'
}

function TestAccept($paramname, $argval, $expect) {
    Write-Debug "    TestAccept $argval, $expect"
}

function TestReject($paramname, $argval) {
    Write-Debug "    TestReject $(($null -eq $argval) ? '$null' : $argval)"
}

function TestPair([array]$spec) {
    $testpair = switch ($spec.count) {
        1 { @{value = ValOrEval $spec[0]; expect = ValOrEval $spec[0] } }
        2 { @{value = ValOrEval $spec[0]; expect = ValOrEval $spec[1] } }
        default { throw }
    }
    return $testpair
}

function TestPairs([array]$testvals = @()) {
    $testpairs = foreach ($val in $testvals) {
        TestPair $val
    }
    return $testpairs
}

function BuildTests {
    foreach ($paramspec in $paramspecs.GetEnumerator()) {
        Write-Debug "Parameter: $($paramspec.key)"

        $paramname = $paramspec.key
        $spec = $paramspec.value

        $defaultval = ($spec.ContainsKey('Default')) ? (ValOrEval $spec.Default) : $null
        $mandatory = (-not $spec.ContainsKey('Default'))
        $ValidVals = ($spec.ContainsKey('ValidVals')) ? (TestPairs $spec.ValidVals) : @()
        $InvalidVals = ($spec.ContainsKey('InvalidVals')) ? (TestPairs $spec.ValidVals) : @()

        if ($mandatory) { TestMandatory -paramname $paramname }
        else { TestDefault -paramname $paramname -expect $defaultval }

        foreach ($testpair in $ValidVals) {
            TestAccept -paramname $paramname -argval $testpair.value -expect (ValOrEval $testpair.expect)
        }

        if ($ValidVals.count -ge 1) {
            $envval = $ValidVals[0].value
            $expect = $ValidVals[0].expect
            TestEnvOverride -paramname $paramname -envval $envval -expect $expect
        }

        if ($ValidVals.count -ge 2) {
            $envval = $ValidVals[0].value
            $argval = $ValidVals[1].value
            $expect = $ValidVals[1].expect
            TestArgOverride -paramname $paramname -envval $envval -argval $argval -expect $expect
        }

        foreach ($argval in $InValidVals) {
            TestReject -paramname $paramname -argval $argval
        }
    }
}

# BuildTests

