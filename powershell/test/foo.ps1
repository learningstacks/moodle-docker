
# $rehostpart = '[a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]'
# $rehost = "(?<HOSTNAME>($rehostpart)(\.($rehostpart))*)"

# $ippart = '25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?'
# $reip = "(?<IPV4>($ippart)(\.($ippart)){3})"

# # $reip = '(?<IPV4>(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})'

# 'a.b.c.com' -match $rehost
# # '1.2.3.4' -match $reip
# $Matches


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
}

class StackParams: StackArgs {
    $COMPOSE_PROJECT_NAME = 'moodle-docker'
    $COMPOSE_CONVERT_WINDOWS_PATHS = 'true'
    $MOODLE_DOCKER_BROWSER_NAME = $null
    $MOODLE_DOCKER_BROWSER_TAG = $null
    $MOODLE_DOCKER_SELENIUM_SUFFIX = ''

    static $VALID_DB = 'pgsql', 'mysql', 'mssql', 'oracle', 'mariadb'
    static $VALID_PHP_VERSION = '5.6', '7.0', '7.1', '7.2', '7.3', '7.4', '8.0'
    static $VALID_APP_RUNTIME = 'ionic3', 'ionic5'
    static $VALID_HOST_PORT = '(?<HOST>\d+\.\d+\.\d+\.\d+:)?(?<PORT>[1-9]\d*)'
    static $VALID_BROWSER = '^(?<NAME>chrome|firefox)(:(?<TAG>.+))?$'

    static [void] AssertDirExists([string]$paramname, [string]$paramvalue) {
        if (-Not $paramvalue -or -Not (Test-Path $paramvalue -PathType Container)) {
            throw "$paramname references non-existing directory ($paramvalue)"
        }
        $true
    }

    static [void]  AssertInSet([string]$paramname, [string]$paramvalue, [string[]]$Set) {
        if (-Not ($Set -contains $paramvalue)) {
            throw "$paramname ($paramvalue) must be one of $($Set -join ', ')"
        }
        $true
    }

    static [string] NormalizeHostPort([string]$paramname, [string]$paramvalue) {
        if ($null -ne $paramvalue) {
            if ($paramvalue -match [StackParams]::VALID_HOST_PORT) {
                $ip = $Matches.Contains('HOST') ? $Matches.HOST : '127.0.0.1'
                $paramvalue = '{0}:{1}' -f $ip, $Matches.PORT
            }
            else {
                throw "$paramname ($paramvalue) is invalid port syntax"
            }

        }
        return $paramvalue
    }

    static [string[]] GetBrowserNameAndTag([string]$paramvalue) {
        if ($paramvalue -match [StackParams]::VALID_BROWSER) {
            $name = $Matches.NAME
            $tag = switch ($Matches) {
                { $_.Contains('TAG') } { $_.TAG; break }
                { $_.NAME -eq 'firefox' } { '3'; break }
                { $_.NAME -eq 'chrome' } { '3'; break }
                default {
                    throw "Unsupported Browser $($_.NAME)"
                }
            }
            return $name, $tag
        }
        else {
            throw "Invalid MOODLE_DOCKER_BROWSER ($paramvalue)"
        }
    }

}

function foo1 {
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

$d = @{
    MOODLE_DOCKER_DB       = 'mysqla'
    MOODLE_DOCKER_WWWROOT  = '.'
    MOODLE_DOCKER_WEB_PORT = '1'
}

# foo1 @d

# [ValidDb]::New().GetValidValues()

class a {
    $a
    $b
}

function b {
    param(
        $a,
        $b
    )
    "$a $b"
}

$a = [a]@{
    a = 1
    b = 2
}

$m = 'a'

$a[$m]
# $a | Get-Member -MemberType Property | Format-List *

$a = @(
    @(1,2)
    @(3,4)
)
$a.count

$sb = {
    param($a, $b)
    $a
    $b
}
$fx = @{a=34; b=32}
& $sb @fx



$a = @(
    'abc'
    ,@('def', 'defa')
)
foreach($item in $a) {
    Write-Output $item.GetType()
}