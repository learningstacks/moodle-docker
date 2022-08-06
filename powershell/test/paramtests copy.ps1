Import-Module -Name (Join-Path $PSScriptRoot '../moodle-docker.psm1') -Force

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
    }

    BeforeAll {
        function ApplyTest($paramname, $stackenv = @{}, $stackargs = @{}, $expecThow = $false, $expect) {

            $ExpectParams = & {
                if ($expect -is [hashtable]) {
                    foreach($item in $expect.GetEnumerator()) {
                        @{
                            paramname = $item.key
                            value = (ValOrEval $item.value)
                        }
                    }
                }
                elseif($expect) {
                    @{
                        name = $paramname
                        value = (ValOrEval $expect)
                    }
                }
            }

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
                foreach($item in $expectparams) {
                    $Stack.StackParams[$item.paramname] | Should -Be $item.expectval
                }
            }
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

