$VALID_DB = 'pgsql', 'mysql', 'mssql', 'oracle', 'mariadb'
$VALID_PHP_VERSION = '5.6', '7.0', '7.1', '7.2', '7.3', '7.4', '8.0'
$VALID_APP_RUNTIME = 'ionic3', 'ionic5'
$VALID_BROWSER = 'chrome', 'firefox'
$DEFAULT_PHP_VERSION = '7.4'
$DEFAULT_DB = 'pgsql'

function default {
    @{
        Scenario = 'Default Stack'
        Params   = @{}
        expect   = @{
            services = @{
                webserver = @{
                    image       = 'moodlehq/moodle-php-apache:7.4'
                    environment = @{
                        MOODLE_DOCKER_DBTYPE         = 'pgsql'
                        MOODLE_DOCKER_DBNAME         = 'moodle'
                        MOODLE_DOCKER_DBUSER         = 'moodle'
                        MOODLE_DOCKER_DBPASS         = 'm@0dl3ing'
                        MOODLE_DOCKER_BROWSER        = 'firefox'
                        MOODLE_DOCKER_WEB_HOST       = 'localhost'
                        MOODLE_DOCKER_PHPUNIT_EXTRAS = $null
                        MOODLE_DOCKER_WEB_PORT       = $null
                        MOODLE_DOCKER_APP            = $null
                        MOODLE_DOCKER_APP_PORT       = $null
                    }
                    volumes     = @{
                        '/var/www/html' = @{Source = { TestDir MOODLE }; Type = 'bind' }
                    }
                    ports       = $false
                }
                mailhog   = @{ image = 'mailhog/mailhog' }
                exttests  = @{ image = 'moodlehq/moodle-exttests' }
                db        = @{
                    image   = 'postgres:.*'
                    ports   = $false
                    Volumes = $false
                }
                selenium  = @{
                    image = 'selenium/standalone-firefox:3'
                    ports = $false
                }
            }
        }
    }
}

function merge([hashtable]$hash1, [hashtable]$hash2) {

    if ($hash2 -is [hashtable]) {
        foreach ($item in $hash2.GetEnumerator()) {
            if ($item.value -is [hashtable] -and ($hash1[$item.key] -is [hashtable])) {
                $hash1[$item.key] = merge $hash1[$item.key] $hash2[$item.key]
            }
            elseif ($item.value -is [array] -and ($hash1[$item.key] -is [array])) {
                $hash1[$item.key] = $hash1[$item.key] + $hash2[$item.key]
            }
            else {
                $hash1[$item.key] = $hash2[$item.key]
            }
        }
    }
    $hash1
}

$stackspecs = & {
    (default)
    merge (default) @{
        Scenario = "MOODLE_DOCKER_WEB_PORT = '40'"
        Params   = @{
            MOODLE_DOCKER_WEB_PORT = '40'
        }
        expect   = @{
            services = @{
                webserver = @{
                    environment = @{
                        MOODLE_DOCKER_WEB_PORT = '127.0.0.1:40'
                    }
                    ports = @{
                        '80' = @{ HostName = '127.0.0.1'; HostPort = 40 }
                    }
                }
            }
        }
    }

    foreach ($php in ($VALID_PHP_VERSION | Where-Object { $_ -ne $DEFAULT_PHP_VERSION })) {
        merge (default) @{
            Scenario = "MOODLE_DOCKER_PHP_VERSION = $php"
            Params   = @{
                MOODLE_DOCKER_PHP_VERSION = $php
            }
            expect   = @{
                services = @{
                    webserver = @{
                        image = "moodlehq/moodle-php-apache:$php"
                    }
                }
            }
        }
    }

    foreach ($db in 'mysql', 'mssql', 'oracle', 'mariadb') {
        merge (default) @{
            Scenario = "Default Stack with $db"
            Tags = 'db'
            Params   = @{
                MOODLE_DOCKER_DB = $db
            }
            expect   = @{
                services = switch ($db) {
                    'mysql' {
                        @{
                            webserver = @{
                                environment = @{
                                    MOODLE_DOCKER_DBTYPE      = 'mysqli'
                                    MOODLE_DOCKER_DBCOLLATION = 'utf8mb4_bin'
                                }
                            }
                            db        = @{
                                image       = 'mysql:5'
                                environment = @{
                                    MYSQL_ROOT_PASSWORD = 'm@0dl3ing'
                                    MYSQL_USER          = 'moodle'
                                    MYSQL_PASSWORD      = 'm@0dl3ing'
                                    MYSQL_DATABASE      = 'moodle'
                                }
                            }
                        }
                    }
                    'mssql' {
                        @{
                            webserver = @{
                                environment = @{
                                    MOODLE_DOCKER_DBTYPE = 'sqlsrv'
                                    MOODLE_DOCKER_DBUSER = 'sa'
                                }
                            }
                            db        = @{
                                image       = 'moodlehq/moodle-db-mssql'
                                environment = @{
                                    ACCEPT_EULA = 'y'
                                    SA_PASSWORD = 'm@0dl3ing'
                                }
                            }
                        }
                    }
                    'oracle' {
                        @{
                            webserver = @{
                                environment = @{
                                    MOODLE_DOCKER_DBTYPE = 'oci'
                                    MOODLE_DOCKER_DBNAME = 'XE'
                                }
                            }
                            db        = @{
                                image = 'moodlehq/moodle-db-oracle-r2'
                            }
                        }
                    }
                    'mariadb' {
                        @{
                            webserver = @{
                                environment = @{
                                    MOODLE_DOCKER_DBTYPE      = 'mariadb'
                                    MOODLE_DOCKER_DBCOLLATION = 'utf8mb4_bin'
                                }
                            }
                            db        = @{
                                image       = 'mariadb:.*'
                                environment = @{
                                    MYSQL_ROOT_PASSWORD = 'm@0dl3ing'
                                    MYSQL_USER          = 'moodle'
                                    MYSQL_PASSWORD      = 'm@0dl3ing'
                                    MYSQL_DATABASE      = 'moodle'
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    merge (default) @{
        Scenario = 'Default Stack with mssql db and php 5.6'
        Params   = @{
            MOODLE_DOCKER_DB          = 'mssql'
            MOODLE_DOCKER_PHP_VERSION = '5.6'
        }
        expect   = @{
            services = @{
                webserver = @{
                    image       = 'moodlehq/moodle-php-apache:5.6'
                    environment = @{
                        MOODLE_DOCKER_DBTYPE = 'mssql'
                        MOODLE_DOCKER_DBUSER = 'sa'
                    }
                }
                db        = @{
                    image       = 'moodlehq/moodle-db-mssql'
                    environment = @{
                        ACCEPT_EULA = 'y'
                        SA_PASSWORD = 'm@0dl3ing'
                    }
                }
            }
        }

    }MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES

    merge (default) @{
        Scenario = 'Default Stack with external services'
        Params   = @{
            MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES = 'true'
        }
        expect   = @{
            services = @{
                webserver  = @{
                    environment = @{
                        MOODLE_DOCKER_PHPUNIT_EXTRAS = 'true'
                    }
                }
                memcached0 = @{ image = 'memcached:1.4' }
                memcached1 = @{ image = 'memcached:1.4' }
                mongo      = @{ image = 'mongo:4.0' }
                redis      = @{ image = 'redis:3' }
                solr       = @{ image = 'solr:6.5' }
                ldap       = @{ image = 'larrycai/openldap' }
            }
        }
    }
    merge (default) @{
        Scenario = 'Selenium Chrome'
        Tags = 'selenium'
        Params   = @{
            MOODLE_DOCKER_BROWSER = 'chrome'
        }
        expect   = @{
            services = @{
                webserver = @{
                    environment = @{
                        MOODLE_DOCKER_BROWSER = 'chrome'
                    }
                }
                selenium  = @{
                    image = 'selenium/standalone-chrome:3'
                }
            }
        }
    }
    merge (default) @{
        Scenario = 'Selenium Chrome debug'
        Params   = @{
            MOODLE_DOCKER_BROWSER = 'chrome'
            MOODLE_DOCKER_SELENIUM_VNC_PORT = '41'
        }
        expect   = @{
            services = @{
                webserver = @{
                    environment = @{
                        MOODLE_DOCKER_BROWSER = 'chrome'
                    }
                }
                selenium  = @{
                    image = 'selenium/standalone-chrome-debug:3'
                    ports = @{
                        '5900' = @{ HostName = '127.0.0.1'; HostPort = '41'}
                    }
                }
            }
        }
    }

}

$testfile = Join-Path $PSScriptRoot 'testastack.ps1'
# function TestAStack([hashtable]$stackspec) {
#     $container = New-PesterContainer -Data $stackspec -Path ($Using:testfile)
#         $config = New-PesterConfiguration @{
#             Run = @{
#                 Container = $container
#             }
#         }
#         # Invoke-Pester -Container $container -Output None
#         Invoke-Pester -Configuration $config
# }

if ($true) {
    $stackspecs[0..0] | ForEach-Object -ThrottleLimit ($stackspecs.count) -Parallel {
        $container = New-PesterContainer -Data $_ -Path ($Using:testfile)
        $config = New-PesterConfiguration @{
            Run = @{
                Container = $container
            }
        }
        # Invoke-Pester -Container $container -Output None
        Invoke-Pester -Configuration $config
    }
}

# With selenium debug
# With chrome browser

# $stackspecs