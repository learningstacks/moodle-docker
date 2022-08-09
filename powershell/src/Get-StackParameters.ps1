function Get-StackParams([hashtable]$PassedParams) {
    $ErrorActionPreference = 'stop'
    $DebugPreference = 'continue'

    $VALID_DB = 'pgsql', 'mysql', 'mssql', 'oracle', 'mariadb'
    $VALID_PHP_VERSION = '5.6', '7.0', '7.1', '7.2', '7.3', '7.4', '8.0'
    $VALID_APP_RUNTIME = 'ionic3', 'ionic5'
    $VALID_HOST_PORT = '((?<HOST>\d+\.\d+\.\d+\.\d+):)?(?<PORT>[1-9]\d*)'
    $VALID_BROWSER = '^(?<NAME>chrome|firefox)(:(?<TAG>.+))?$'

    $ParameterDefs = [ordered]@{
        MOODLE_DOCKER_DB                        = @{
            Default    = 'pgsql'
            Validation = {
                AssertInSet $paramname $paramvalue $VALID_DB
                return $paramvalue
            }
        }
        MOODLE_DOCKER_WWWROOT                   = @{
            Default    = $null
            Validation = {
                AssertDirExists $paramname $paramvalue
                return $paramvalue
            }
        }
        MOODLE_DOCKER_PHP_VERSION               = @{
            Default    = '7.4'
            Validation = {
                AssertInSet $paramname $paramvalue $VALID_PHP_VERSION
                return $paramvalue
            }
        }
        MOODLE_DOCKER_BROWSER                   = @{
            Default    = 'firefox:3'
            Validation = {
                if ($paramvalue -notmatch $VALID_BROWSER) {
                    throw "Invalid $paramname ($paramvalue)"
                }
                return $paramvalue
            }
        }
        MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES = @{
            Default    = $null
            Validation = {
                return ([boolean]$paramvalue ? 'true' : $null)
            }
        }
        MOODLE_DOCKER_BEHAT_FAILDUMP            = @{
            Default    = $null
            Validation = {
                if ($paramvalue) {
                    AssertDirExists $paramname $paramvalue
                    return $paramvalue
                }
                else {
                    return $null
                }
            }
        }
        MOODLE_DOCKER_WEB_HOST                  = @{
            Default    = 'localhost'
            Validation = {
                return $paramvalue
            }
        }
        MOODLE_DOCKER_WEB_PORT                  = @{
            Default    = $null
            Validation = {
                if ($paramvalue) {
                    return NormalizeHostPort $paramname $paramvalue
                }
                else {
                    return $null
                }
            }
        }
        MOODLE_DOCKER_SELENIUM_VNC_PORT         = @{
            Default    = $null
            Validation = {
                if ($paramvalue) {
                    return NormalizeHostPort $paramname $paramvalue
                }
                else {
                    return $null
                }
            }
        }
        MOODLE_DOCKER_APP_PATH                  = @{
            Default    = $null
            Validation = {
                if ($paramvalue) {
                    if ($StackParams.MOODLE_DOCKER_APP_VERSION) {
                        throw 'Cannot specify both MOODLE_DOCKERAPP_PATH and MOODLE_DOCKER_APP_VERSION'
                    }
                    AssertDirExists $paramname $paramvalue
                    return $paramvalue
                }
                else {
                    return $null
                }
            }
        }
        MOODLE_DOCKER_APP_VERSION               = @{
            Default    = $null
            Validation = {
                if ($paramvalue) {
                    try { $null = [version]$paramvalue }
                    catch { throw "$paramname ($paramvalue) is not a valid Moodle App version" }
                    return $paramvalue
                }
                else {
                    return $null
                }
            }
        }
        MOODLE_DOCKER_APP_RUNTIME               = @{
            Default    = $null
            Validation = {
                if ($StackParams.MOODLE_DOCKER_APP_PATH -or $StackParams.MOODLE_DOCKER_APP_VERSION) {
                    if ($paramvalue) {
                        AssertInSet $paramname $paramvalue $VALID_APP_RUNTIME
                    }
                    else {
                        # Infer runtime from version
                        $appversion = $null
                        if ($StackParams.MOODLE_DOCKER_APP_VERSION) {
                            $appversion = [version]$StackParams.MOODLE_DOCKER_APP_VERSION
                        }
                        elseif ($StackParams.MOODLE_DOCKER_APP_PATH) {
                            $pkgfile = Join-Path $StackParams.MOODLE_DOCKER_APP_PATH 'package.json'
                            $package = Get-Content $pkgfile | ConvertFrom-Json -AsHashtable -Depth 5 -ErrorAction Stop
                            if (-Not $package.Contains('version') -or (-Not $package.version)) {
                                throw "$pkgfile does not specify version"
                            }
                            $appversion = [version]$package.version
                        }

                        return ([version]$appversion -ge [version]'3.9.5' ? 'ionic5' : 'ionic3')
                    }
                }
                else {
                    return $null
                }
            }
        }
    }

    function GetBrowserNameAndTag([string]$paramvalue) {
        if ($paramvalue -match $VALID_BROWSER) {
            $name = $Matches.NAME
            $tag = switch ($Matches) {
                { $_.Contains('TAG') } { $_.TAG; break }
                { $_.NAME -eq 'firefox' } { '3'; break }
                { $_.NAME -eq 'chrome' } { '3'; break }
                default {
                    throw "Unsupported Browser $($_.NAME)"
                }
            }
            $name, $tag
        }
        else {
            throw "Invalid MOODLE_DOCKER_BROWSER ($MOODLE_DOCKER_BROWSER)"
        }
    }

    function GetParameterNames() {
        $ParameterDefs.keys.clone()
    }

    function NormalizeHostPort([string]$paramname, [string]$paramvalue) {
        if ($null -ne $paramvalue) {
            if ($paramvalue -match $VALID_HOST_PORT) {
                $ip = $Matches.Contains('HOST') ? $Matches.HOST : '127.0.0.1'
                $paramvalue = '{0}:{1}' -f $ip, $Matches.PORT
            }
            else {
                throw "$paramname ($paramvalue) is invalid port syntax"
            }

        }
        return $paramvalue
    }

    function AssertDirExists([string]$paramname, [string]$paramvalue) {
        if (-Not $paramvalue -or -Not (Test-Path $paramvalue -PathType Container)) {
            throw "$paramname references non-existing directory ($paramvalue)"
        }
    }

    function AssertInSet([string]$paramname, [string]$paramvalue, [string[]]$Set) {
        if (-Not ($Set -contains $paramvalue)) {
            throw "$paramname ($paramvalue) must be one of $($Set -join ', ')"
        }
    }

    # Set defaults
    $StackParams = @{}

    # Verify only accepted parameters are passed
    foreach ($paramname in $PassedParams.keys) {
        if (-Not $ParameterDefs.Contains($paramname)) {
            throw "Unrecognized parameter $paramname"
        }
    }

    # set value from passedparam, environment, then default
    foreach ($param in $ParameterDefs.GetEnumerator()) {
        $paramname = $param.name
        $defaultval = $param.value.Default
        $envval = (Test-Path "Env:$paramname") ? (Get-Item "Env:$paramname").Value : $null
        $passedval = $PassedParams.Contains($paramname) ? $PassedParams[$paramname] : $null
        $StackParams[$paramname] = $passedval ?? $envval ?? $defaultval
    }

    # Apply rules
    foreach ($paramname in (GetParameterNames)) {
        $paramvalue = $StackParams[$paramname]
        $StackParams[$paramname] = & $ParameterDefs[$paramname].Validation
    }

    # Derive browser name and tag
    $StackParams.MOODLE_DOCKER_BROWSER_NAME, $StackParams.MOODLE_DOCKER_BROWSER_TAG = GetBrowserNameAndTag $StackParams.MOODLE_DOCKER_BROWSER

    # Determine selenium suffix
    $StackParams.MOODLE_DOCKER_SELENIUM_SUFFIX = ''
    if ($StackParams.MOODLE_DOCKER_SELENIUM_VNC_PORT) {
        $StackParams.MOODLE_DOCKER_SELENIUM_SUFFIX = '-debug'
    }

    return $StackParams
}
