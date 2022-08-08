Import-Module -Name (Join-Path $PSScriptRoot '../moodle-docker.psm1') -Force
# $ErrorActionPreference = 'Break'

$porttest = @{
    columns  = {
        @{
            input  = @(
                "stackenv.$paramname"
                "stackargs.$paramname"
            )
            expect = @(
                "expect.$paramname"
            )
        }
    }
    testdata = @{
        'default'        = @(
            , @($null, $null, $null)
        )
        'Valid values'   = @(
            , @('40', $null, '127.0.0.1:40')
            , @('1.1.1.1:1', $null, '1.1.1.1:1')
            , @('50', '40', '127.0.0.1:40')
            , @('60', '1.1.1.1:1', '1.1.1.1:1')
        )
        'Invalid values' = @(
            , @('noport', $null, 'throw')
            , @('40', 'noport', 'throw')
        )
    }
}
$testspecs = @{
    MOODLE_DOCKER_WWWROOT                   = @{
        columns  = {
            @{
                input  = @(
                    "stackenv.$paramname"
                    "stackargs.$paramname"
                )
                expect = @(
                    "expect.$paramname"
                )
            }
        }
        testdata = @{
            'Valid values'   = @(
                , @( { TestDir MOODLE }, $null, { TestDir MOODLE } )
                , @( { TestDir MOODLE }, { TestDir MOODLE2 }, { TestDir MOODLE2 } )
            )
            'Invalid values' = @(
                , @( $null, $null, 'throw' )
                , @( { TestDir NODIR }, $null, 'throw' )
                , @( $null, { TestDir NODIR }, 'throw' )

            )
        }
    }
    MOODLE_DOCKER_DB                        = @{
        columns  = {
            @{
                input  = @(
                    "stackenv.$paramname"
                    "stackargs.$paramname"
                )
                expect = @(
                    "expect.$paramname"
                )
            }
        }
        testdata = @{
            'Default'        = @(
                , @( $null, $null, 'pgsql' )
            )
            'Valid values'   = & {
                foreach ($val in $VALID_DB) {
                    , @( $val, $null, $val)
                    , @( $null, $val, $val)
                }
                , @( $VALID_DB[0], $VALID_DB[1], $VALID_DB[1])

            }
            'Invalid Values' = @(
                , @( 'otherdb', $null, 'throw' )
                , @( $null, 'otherdb', 'throw' )
            )
        }
    }
    MOODLE_DOCKER_PHP_VERSION               = @{
        columns  = {
            @{
                input  = @(
                    "stackenv.$paramname"
                    "stackargs.$paramname"
                )
                expect = @(
                    "expect.$paramname"
                )
            }
        }
        testdata = @{
            'Default'        = @(
                , @( $null, $null, '7.4' )
            )
            'Valid values'   = & {
                foreach ($val in $VALID_PHP_VERSION) {
                    , @( $val, $null, $val)
                    , @( $null, $val, $val)
                }
                , @( $VALID_PHP_VERSION[0], $VALID_PHP_VERSION[1], $VALID_PHP_VERSION[1])
            }
            'Invalid values' = @(
                , @( '5.5', $null, 'throw' )
                , @( $null, '5.5', 'throw' )
            )
        }
    }
    MOODLE_DOCKER_BROWSER                   = @{
        columns  = {
            @{
                input  = @(
                    "stackenv.$paramname"
                    "stackargs.$paramname"
                )
                expect = @(
                    "expect.$paramname"
                    'expect.MOODLE_DOCKER_BROWSER_NAME'
                    'expect.MOODLE_DOCKER_BROWSER_TAG'
                )
            }
        }
        testdata = @{
            'Default'        = @(
                , @( $null, $null, 'firefox:3', 'firefox', '3' )
            )
            'Valid values'   = & {
                , @( $null, 'chrome', 'chrome', 'chrome', '3')
                , @( $null, 'chrome:4', 'chrome:4', 'chrome', '4')
                , @( $null, 'firefox', 'firefox', 'firefox', '3')
                , @( $null, 'firefox:4', 'firefox:4', 'firefox', '4')
                , @( 'firefox', 'chrome', 'chrome', 'chrome', '3')
            }
            'Invalid values' = @(
                , @( 'safari', $null, 'throw' )
                , @( $null, 'edge', 'throw' )
            )
        }
    }
    MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES = @{
        columns   = {
            @{
                input  = @(
                    "stackenv.$paramname"
                    "stackargs.$paramname"
                )
                expect = @(
                    "expect.$paramname"
                )
            }
        }
        testdata  = @{
            'Default'      = @(
                , @($null, $null, $null )
            )
            'Valid values' = @(
                , @( $true, $null, 'true')
                , @( 'abc', $null, 'true')
                , @( '', $null, $null)
                , @( $false, $null, $null)
                , @( $false, 'abc', 'true')
            )
        }
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
        columns  = {
            @{
                input  = @(
                    "stackenv.$paramname"
                    "stackargs.$paramname"
                )
                expect = @(
                    "expect.$paramname"
                )
            }
        }
        testdata = @{
            'Default'        = @(
                , @( $null, $null, $null )
            )
            'Valid values'   = & {
                , @( { TestDir FAILDUMP }, $null, { TestDir FAILDUMP })
                , @( $null, { TestDir FAILDUMP }, { TestDir FAILDUMP })
            }
            'Invalid values' = @(
                , @(  $null, { TestDir NODIR }, 'throw' )
            )
        }
    }
    MOODLE_DOCKER_SELENIUM_VNC_PORT         = $porttest
    MOODLE_DOCKER_WEB_PORT                  = $porttest
    MOODLE_DOCKER_APP_RUNTIME               = @{
        columns  = {
            @{
                input  = @(
                    'stackargs.MOODLE_DOCKER_APP_PATH'
                    'stackargs.MOODLE_DOCKER_APP_VERSION'
                    "stackenv.$paramname"
                    "stackargs.$paramname"
                )
                expect = @(
                    "expect.$paramname"
                )
            }
        }
        testdata = @(
            @{
                'Default'        = @(
                    , @($null, $null, 'ionic3', $null)
                )
                'Valid values'   = @(
                    , @( { TestDir 'APP_3.9.4' }, $null, 'ionic5', $null, 'ionic5')
                    , @( { TestDir 'APP_3.9.5' }, $null, 'ionic5', 'ionic3', 'ionic3')
                    , @( $null, '3.9.4', 'ionic5', $null, 'ionic5')
                    , @( $null, '3.9.5', 'ionic5', 'ionic3', 'ionic3')
                )
                'invalid values' = @(
                    , @( $null, '3.9.5', $null, 'ionic4', 'throw')
                )
                'Derivations'    = @(
                    , @( { TestDir 'APP_3.9.4' }, $null, $null, $null, 'ionic3')
                    , @( { TestDir 'APP_3.9.5' }, $null, $null, 'ionic5')
                    , @($null, '3.9.4', $null, $null, 'ionic3')
                    , @($null, '3.9.5', $null, $null, 'ionic5')
                )
            }
        )
    }
    MOODLE_DOCKER_WEB_HOST                  = @{
        columns  = {
            @{
                input  = @(
                    "stackenv.$paramname"
                    "stackargs.$paramname"
                )
                expect = @(
                    "expect.$paramname"
                )
            }
        }
        testdata = @{
            'Default'        = @(
                , @( $null, $null, 'localhost' )
            )
            'Valid values'   = @(
                , @( 'abc.com', $null, 'abc.com' )
                , @( 'abc.com', 'def.net', 'def.net' )
            )
            'Invalid values' = @(
                # , @(  $null, { TestDir NODIR }, 'throw' )
            )
        }
    }
    MOODLE_DOCKER_APP_PATH                  = @{
        columns  = {
            @{
                input  = @(
                    'stackargs.MOODLE_DOCKER_APP_VERSION'
                    "stackenv.$paramname"
                    "stackargs.$paramname"
                )
                expect = @(
                    "expect.$paramname"
                )
            }
        }
        testdata = @{
            'Default'        = @(
                , @( $null, $null, $null, $null)
            )
            'Valid values'   = @(
                , @( $null, { TestDir 'APP_3.9.4' }, $null, { TestDir 'APP_3.9.4' })
                , @( $null, { TestDir 'APP_3.9.4' }, { TestDir 'APP_3.9.5' }, { TestDir 'APP_3.9.5' })

            )
            'Invalid values' = @(
                , @( $null, $null, { TestDir NODIR }, 'throw') # no dir
                , @( $null, $null, { TestDir MOODLE }, 'throw') # no package.json
                , @( '3.9.5', $null, { TestDir 'APP_3.9.4' }, 'throw') # both APP_PATH and APP_VERSION se
            )
        }
    }
    MOODLE_DOCKER_APP_VERSION               = @{
        columns  = {
            @{
                input  = @(
                    'stackargs.MOODLE_DOCKER_APP_PATH'
                    "stackenv.$paramname"
                    "stackargs.$paramname"
                )
                expect = @(
                    "expect.$paramname"
                )
            }
        }
        testdata = @{
            'Default'        = @(
                , @( $null, $null, $null, $null)
            )
            'Valid values'   = @(
                , @( $null, '3.9.4', $null, '3.9.4')
                , @( $null, '3.9.4', '3.9.5', '3.9.5')
            )
            'Invalid values' = @(
                , @( $null, $null, 'abc', 'throw') # no dir
                , @( { TestDir 'APP_3.9.4' }, $null, '3.9.4', 'throw') # both APP_PATH and APP_VERSION se
            )
        }
    }
}

function BuildTests([hashtable]$testspecs) {

    function SetTestValue([hashtable]$test, [string]$column, $value) {
        $varname, $index = $column -split '\.'
        if ($index) {
            if (-Not $test.ContainsKey($varname)) {
                $test.$varname = @{}
            }
            $test.$varname.$index = $value
        }
        else {
            $test.$varname = $value
        }
    }

    function SetTestName([hashtable]$test, [hashtable]$columns, [array]$valueset) {
        $inputstart = 0
        $inputend = $columns.input.count - 1
        $expectstart = $columns.input.count
        $expectend = $valueset.count - 1
        $inputs = ($valueset[$inputstart..$inputend] | ForEach-Object { $null -eq $_ ? 'null' : [string]$_ }) -join ', '
        $expect = ($valueset[$expectstart..$expectend] | ForEach-Object { $null -eq $_ ? 'null' : [string]$_ }) -join ', '
        $test.testname = "$inputs => $expect"
    }

    foreach ($item in $testspecs.GetEnumerator()) {
        $paramname = $item.key
        $columns = & $item.value.columns
        foreach ($item in $item.value.testdata.GetEnumerator()) {
            $groupname = $item.key
            foreach ($valueset in $item.value) {
                $test = @{
                    paramname = $paramname
                    groupname = $groupname
                    stackenv  = @{}
                    stackargs = @{}
                }

                $valindex = 0

                # Setup inputs
                foreach ($i in 0..($columns.input.count - 1)) {
                    SetTestValue $test $columns.input[$i] $valueset[$valindex++]
                }

                # setup expected
                if ($valueset[$valueset.count - 1] -eq 'throw') {
                    SetTestValue $test 'expectthrow' $true
                }
                else {
                    foreach ($i in 0..($columns.expect.count - 1)) {
                        SetTestValue $test $columns.expect[$i] $valueset[$valindex++]
                    }
                }

                SetTestName $test $columns $valueset

                $test
            }
        }
    }
}

$tests = BuildTests $testspecs

$tests