class StackArgs {
    $MOODLE_DOCKER_DB = 'pgsql'
    $MOODLE_DOCKER_WWWROOT = $null
    $MOODLE_DOCKER_PHP_VERSION = '7.4'
    $MOODLE_DOCKER_BROWSER = 'firefox:3'
    $MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES = $null
    $MOODLE_DOCKER_BEHAT_FAILDUMP = $null
    $MOODLE_DOCKER_WEB_HOST = 'localhost'
    $MOODLE_DOCKER_WEB_PORT = $null
    $MOODLE_DOCKER_SELENIUM_VNC_PORT = $null
    $MOODLE_DOCKER_APP_PATH = $null
    $MOODLE_DOCKER_APP_VERSION = $null
    $MOODLE_DOCKER_APP_RUNTIME = $null

    [void] Set_MOODLE_DOCKER_WWWROOT([string]$Value) {
        [Rules]::AssertDirExists('MOODLE_DOCKER_WWWROOT', $Value)
        $this.MOODLE_DOCKER_WWWROOT = $Value
    }
}

class StackParams: StackArgs {
    $COMPOSE_PROJECT_NAME = 'moodle-docker'
    $COMPOSE_CONVERT_WINDOWS_PATHS = 'true'
    $MOODLE_DOCKER_BROWSER_NAME = $null
    $MOODLE_DOCKER_BROWSER_TAG = $null
    $MOODLE_DOCKER_SELENIUM_SUFFIX = ''

    [void] SetBrowserNameAndTag() {
        if ($this.MOODLE_DOCKER_BROWSER -match [StackParams]::VALID_BROWSER) {
            $name = $Matches.NAME
            $tag = switch ($Matches) {
                { $_.Contains('TAG') } { $_.TAG; break }
                { $_.NAME -eq 'firefox' } { '3'; break }
                { $_.NAME -eq 'chrome' } { '3'; break }
                default {
                    throw "Unsupported Browser $($_.NAME)"
                }
            }
            $this.MOODLE_BROWSER_NAME = $name
            $this.MOODLE_BROWSER_TAG = $tag
        }
        else {
            throw "Invalid MOODLE_DOCKER_BROWSER ($this.MOODLE_DOCKER_BROWSER)"
        }
    }

    [void] NormalizePorts([string]$paramname, [string]$paramvalue) {
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



}

class ParamRules {
    static $VALID_DB = 'pgsql', 'mysql', 'mssql', 'oracle', 'mariadb'
    static $VALID_PHP_VERSION = '5.6', '7.0', '7.1', '7.2', '7.3', '7.4', '8.0'
    static $VALID_APP_RUNTIME = 'ionic3', 'ionic5'
    static $VALID_HOST_PORT = '((?<HOST>\d+\.\d+\.\d+\.\d+):)?(?<PORT>[1-9]\d*)'
    static $VALID_BROWSER = '^(?<NAME>chrome|firefox)(:(?<TAG>.+))?$'

    [void] AssertDirExists([string]$paramname, [string]$paramvalue) {
        if (-Not $paramvalue -or -Not (Test-Path $paramvalue -PathType Container)) {
            throw "$paramname references non-existing directory ($paramvalue)"
        }
    }

    [void] AssertInSet([string]$paramname, [string]$paramvalue, [string[]]$Set) {
        if (-Not ($Set -contains $paramvalue)) {
            throw "$paramname ($paramvalue) must be one of $($Set -join ', ')"
        }
    }
}

function StackParams {
    param(
        [ValidateScript({ [StackParams]::AssertInSet('MOODLE_DOCKER_APP_RUNTIME', $_, [StackParams]::VALID_APP_RUNTIME) })]
        [string]$MOODLE_DOCKER_DB = 'pgsql',

        [Parameter(Mandatory)]
        [ValidateScript({ [StackParams]::AssertDirExists('MOODLE_DOCKER_WWWROOT', $_) })]
        [string]$MOODLE_DOCKER_WWWROOT,

        [ValidateScript({ [StackParams]::AssertInSet('MOODLE_DOCKER_PHP_VERSION', $_, [StackParams]::VALID_PHP_VERSION) })]
        [string]$MOODLE_DOCKER_PHP_VERSION = '7.4',

        [ValidateScript({ [StackParams]::AssertInSet('MOODLE_DOCKER_PHP_VERSION', $_, [StackParams]::VALID_BROWSER) })]
        [string]$MOODLE_DOCKER_BROWSER = 'firefox:3',

        [string]$MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES,

        [ValidateScript({ [StackParams]::AssertDirExists('MOODLE_DOCKER_BEHAT_FAILDUMP', $_) })]
        [string]$MOODLE_DOCKER_BEHAT_FAILDUMP,

        [string]$MOODLE_DOCKER_WEB_HOST = 'localhost',

        [string][ValidateScript({ [StackParm]::AssertValidHostPort('MOODLE_DOCKER_WEB_PORT', $_) })]
        $MOODLE_DOCKER_WEB_PORT,

        [ValidateScript({ [StackParm]::AssertValidHostPort('MOODLE_DOCKER_SELENIUM_VNC_PORT', $_) })]
        [string]$MOODLE_DOCKER_SELENIUM_VNC_PORT,

        [ValidateScript({ [StackParams]::AssertDirExists('MOODLE_DOCKER_WWWROOT', $_) })]
        [string]$MOODLE_DOCKER_APP_PATH,

        [string]$MOODLE_DOCKER_APP_VERSION,

        [ValidateScript({ [StackParams]::AssertInSet('MOODLE_DOCKER_APP_RUNTIME', $_, [StackParams]::VALID_APP_RUNTIME) })]
        [string]$MOODLE_DOCKER_APP_RUNTIME
    )

    $MOODLE_DOCKER_WEB_PORT = [StackParams]::NormalizeHostPort($MOODLE_DOCKER_WEB_PORT)
    $MOODLE_DOCKER_SELENIUM_VNC_PORT = [StackParams]::NormalizeHostPort($MOODLE_DOCKER_SELENIUM_VNC_PORT)
    $MOODLE_DOCKER_BROWSER_NAME, $MOODLE_DOCKER_BROWSER_TAG = [StackParams]::GetBrowserNameAndTag($MOODLE_DOCKER_BROWSER)

}

function Get-StackParams([hashtable]$PassedParams) {
    $ErrorActionPreference = 'stop'
    $DebugPreference = 'continue'

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
                return (($paramvalue) ? 'true' : $null)
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


    # Set defaults

    $DefaultArgs = [StackArgs]::New()

    # # Verify only accepted parameters are passed
    # foreach ($paramname in $PassedParams.keys) {
    #     if (-Not $ParameterDefs.Contains($paramname)) {
    #         throw "Unrecognized parameter $paramname"
    #     }
    # }

    $StackArgs = @{}

    # set value from passedparam, environment, then default
    foreach ($member in ($DefaultArgs | Get-Member -MemberType Property)) {
        $paramname = $member.name
        $defaultval = $DefaultArgs.$paramname
        $envval = (Test-Path "Env:$paramname") ? (Get-Item "Env:$paramname").Value : $null
        $passedval = $PassedParams.Contains($paramname) ? $PassedParams[$paramname] : $null
        $StackArgs[$paramname] = $passedval ?? $envval ?? $defaultval
    }

    $StackParams = StackParams @StackArgs

    return $StackParams
}
