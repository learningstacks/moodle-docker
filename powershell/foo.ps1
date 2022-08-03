class StackParams {
    [string]$COMPOSE_PROJECT_NAME
    [string]$MOODLE_DOCKER_WWWROOT
    [string]$MOODLE_DOCKER_WEB_HOST
    [string]$MOODLE_DOCKER_WEB_PORT
    [string]$MOODLE_DOCKER_PHP_VERSION
    [string]$MOODLE_DOCKER_BEHAT_FAILDUMP
    [string]$MOODLE_DOCKER_DB
    [string]$MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES
    [string]$MOODLE_DOCKER_SELENIUM_VNC_PORT
    [string]$MOODLE_DOCKER_BROWSER
    [string]$MOODLE_DOCKER_APP_PATH
    [string]$MOODLE_DOCKER_APP_VERSION
    [string]$MOODLE_DOCKER_APP_RUNTIME

    StackParams() {

    }


}

function GetParams($PassedParams, $ParamDefaults, [string]$Name) {

    $envpath = "Env:$Name"
    $defaultval = $ParamDefaults.ContainsKey($Name) ? $ParamDefaults[$Name] : (throw "Unrecognized parameter $name")
    $envval = (Test-Path $envpath) ? (Get-Item $envpath).Value : $null
    $passedval = $PassedParams.ContainsKey($name) ? $PassedParams[$Name] : $null
    $paramval = $passedval ?? $envval ?? $defaultval


    function MOODLE_DOCKER_WWWROOT($paramval) {

    }
}


$h = @{ a = 1 }
($h.b) -eq $null