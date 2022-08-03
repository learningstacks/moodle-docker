
function ValOrEval([object]$Value) {
    if ($Value -is [scriptblock]) {
        [string](& $Value)
    }
    else {
        [string]$Value
    }
}

function Expect([string]$type) {
    switch ($type) {
        'postgres' {
            @{
                webserver = @{
                    environment = @{
                        MOODLE_DOCKER_DBTYPE = 'pgsql'
                    }
                }
                db        = @{
                    Name    = 'db'
                    Image   = 'postgres:.*'
                    Ports   = $false
                    Volumes = $false
                }
            }
        }
    }
}

function webserver {
    param(
        $Php = '7.4',
        $DbType = 'pgsql',
        $Port,
        $wwwroot,
        $BrowserName = 'firefox',
        $BrowserTag = '3'
    )

    $Expect = @{
        Name        = 'webserver'
        Image       = "moodlehq/moodle-php-apache:$Php"
        Environment = @(
            @{Name = 'MOODLE_DOCKER_DBTYPE'; Value = $DbType }
            @{Name = 'MOODLE_DOCKER_DBNAME'; Value = 'moodle' }
            @{Name = 'MOODLE_DOCKER_DBUSER'; Value = 'moodle' }
            @{Name = 'MOODLE_DOCKER_DBPASS'; Value = 'm@0dl3ing' }
            @{Name = 'MOODLE_DOCKER_BROWSER'; Value = 'firefox' }
            @{Name = 'MOODLE_DOCKER_WEB_HOST'; Value = 'localhost' }
        )
        Volumes     = @(
            @{
                Target = '/var/www/html'
                Source = $wwwroot
                Type   = 'bind'
            }
        )
    }

    if ($Port) {

    }
}

function db {
    param(
        $Type = 'postgres'
    )

    switch ($Type) {
        'postgres' {
            @{
                Name        = 'db'
                Image       = 'postgres:.*'
                Environment = @{
                    POSTGRES_USER     = 'moodle'
                    POSTGRES_PASSWORD = 'm@0dl3ing'
                    POSTGRES_DB       = 'moodle'
                }
            }
        }
    }
}

function selenium {
    param(
        [ValidateSet('chrome', 'firefox')]$BrowserName = 'firefox',
        $BrowserTag = '3',
        $HostIp,
        $HostPort
    )

    $expect = @{
        Name  = 'selenium'
        Image = "selenium/standalone-$($BrowserName):$($BrowserTag)"
        Ports = $false
    }

    if ($Port) {
        $expect.Ports = @(
            @{ LocalPort = 5900; HostName = '127.0.0.1'; HostPort = 40 }
        )
    }
}

function exttests {
    @{
        Name    = 'exttests'
        Image   = 'moodlehq/moodle-exttests'
        Volumes = @(
            @{
                Target = '/etc/apache2/ports.conf'
                Source = { AssetDir 'exttests/apache2_ports.conf' }
                Type   = 'bind'
            }
            @{
                Target = 'etc/apache2/sites-enabled/000-default.conf'
                Source = { AssetDir 'exttests/apache2.conf' }
                Type   = 'bind'
            }
        )
        Ports   = $false
    }

}

function externalservices {

}

function mailhog {

}

$TestStacks = @(
    @{
        Scenario = 'Default Stack'
        Params   = @{}
        Expected = @{
            services = @(
                webserver -Php '7.4' -Db postgres -Port $null -wwwroot { TestDir MOODLE } -BrowserName 'firefox' -BrowserTag '3'
                db -Type 'postgres'
                mailhog
                exttests
            )
        }
    }
    @{
        Scenario = 'Default Stack with mapped port'
        Params   = @{
            MOODLE_DOCKER_WEB_PORT = 40
        }
        Expected = @{
            Services = @(
                webserver -Php '7.4' -Db postgres -Port $null -wwwroot { TestDir MOODLE } -BrowserName 'firefox' -BrowserTag '3'
                db -Type 'postgres'
                mailhog
                exttests
            )
        }
    }
)

$TestStacks