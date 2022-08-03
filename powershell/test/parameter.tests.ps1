Describe 'Parameter handling' {

    BeforeAll {
        $Defaults = @{
            MOODLE_DOCKER_WWWROOT                   = { TestDir MOODLE }
            COMPOSE_PROJECT_NAME                    = 'moodle-docker'
            MOODLE_DOCKER_PHP_VERSION               = '7.4'
            MOODLE_DOCKER_DB                        = 'pgsql'
            MOODLE_DOCKER_BROWSER                   = 'firefox:3'
            MOODLE_DOCKER_BROWSER_NAME              = 'firefox'
            MOODLE_DOCKER_BROWSER_TAG               = '3'
            MOODLE_DOCKER_WEB_HOST                  = 'localhost'
            MOODLE_DOCKER_WEB_PORT                  = $null
            MOODLE_DOCKER_APP_VERSION               = $null
            MOODLE_DOCKER_APP_RUNTIME               = $null
            MOODLE_DOCKER_APP_PATH                  = $null
            MOODLE_DOCKER_BEHAT_FAILDUMP            = $null
            MOODLE_DOCKER_SELENIUM_SUFFIX           = $null
            MOODLE_DOCKER_SELENIUM_VNC_PORT         = $null
            MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES = $null
        }

        $OverideTest = @{
            COMPOSE_PROJECT_NAME                    = 'p_env', 'p_param'
            MOODLE_DOCKER_WWWROOT                   = (TestDir MOODLE), (TestDir MOODLE2)
            MOODLE_DOCKER_PHP_VERSION               = '7.1', '7.2'
            MOODLE_DOCKER_DB                        = 'mysql', 'oracle'
            MOODLE_DOCKER_BROWSER                   = 'chrome:2', 'firefox:4'
            MOODLE_DOCKER_WEB_HOST                  = 'host1', 'host2'
            MOODLE_DOCKER_WEB_PORT                  = '6.6.6.6:8000', '7.7.7.7:8001'
            MOODLE_DOCKER_APP_VERSION               = '3.4', '3.5'
            MOODLE_DOCKER_APP_RUNTIME               = 'ionic3', 'ionic5'
            MOODLE_DOCKER_APP_PATH                  = (TestDir 'APP_3.9.4'), (TestDir 'APP_3.9.5')
            MOODLE_DOCKER_BEHAT_FAILDUMP            = (TestDir 'FAILDUMP'), (TestDir 'FAILDUMP2')
            MOODLE_DOCKER_SELENIUM_VNC_PORT         = '1000', '1001'
            MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES = 'a', 'b'
        }
    }

    Describe 'Parameter defaulting' {

        It 'Sets meaningful default' {
            $Stack = New-Stack @{
                MOODLE_DOCKER_WWWROOT = TestDir MOODLE
            }
            AssertStackEnvironment $Stack $Defaults
        }

        It "Environment variable overides default" {

        }

        It "Passed parameter overrides environment" {

        }

    }

    # Describe 'Value oassed parameter' -TestCases @(
    #     @{
    #         Name   = 'MOODLE_DOCKER_WWWROOT'
    #         Env    = { TestDir MOODLE }
    #         Param  = { TestDir MOODLE2 }
    #         Expect = { TestDir MOODLE2 }
    #     }
    # ) {

    # }
}

        Describe 'Compose file handling' {

            BeforeAll {
            }

            Describe 'Default Stack' {

            }

            Describe 'Minimal stack (webserver, mailhog, db' {

                BeforeAll {
                    $Stack = New-Stack @{
                        MOODLE_DOCKER_WWWROOT = TestDir MOODLE
                    }
                }

                It 'Files[<_.Pos>] = <_.Path>' -TestCases $ExpectFiles {
                    $Stack.ComposeFiles[$_.Pos] | Should -Be $_.Path
                }
            }

            Describe 'Configuring for Behat' {

                Describe 'Adding Selenium' {

                }

                Describe 'Map faildumps to a Host directory' {

                }

            }

            Describe 'Add External Services' {

            }


            It '<Scenario>' -TestCases @(
                @{
                    Scenario    = 'Minimal stack'
                    Arguments   = @{
                    }
                    ExpectFiles = @(
                        { BaseDir 'base.yml' }
                        { BaseDir 'service.mail.yml' }
                    )
                }
                @{
                    Scenario    = 'APP_PATH 3.9.3'
                    Arguments   = @{
                        MOODLE_DOCKER_APP_PATH = { TestDir 'APP_3.9.5' }
                    }
                    ExpectFiles = @(
                        { BaseDir 'base.yml' }
                        { BaseDir 'service.mail.yml' }
                        { BaseDir 'moodle-app-dev-ionic5.yml' }
                    )
                }
                @{
                    Scenario    = 'APP_PATH 3.9.4'
                    Arguments   = @{
                        MOODLE_DOCKER_APP_PATH = { TestDir 'APP_3.9.4' }
                    }
                    ExpectFiles = @(
                        { BaseDir 'base.yml' }
                        { BaseDir 'service.mail.yml' }
                        { BaseDir 'moodle-app-dev-ionic3.yml' }
                    )
                }
                @{
                    Scenario    = 'APP_VERSION, 3.9.5'
                    Arguments   = @{
                        MOODLE_DOCKER_APP_VERSION = '3.9.5'
                    }
                    ExpectFiles = @(
                        { BaseDir 'base.yml' }
                        { BaseDir 'service.mail.yml' }
                        { BaseDir 'moodle-app-ionic5.yml' }
                    )
                }
                @{
                    Scenario    = 'APP_VERSION, 3.9.4'
                    Arguments   = @{
                        MOODLE_DOCKER_APP_VERSION = '3.9.4'
                    }
                    ExpectFiles = @(
                        { BaseDir 'base.yml' }
                        { BaseDir 'service.mail.yml' }
                        { BaseDir 'moodle-app-ionic3.yml' }
                    )
                }
            ) {
                $Arguments.MOODLE_DOCKER_WWWROOT = TestDir MOODLE
                $Stack = New-Stack (GetParams $Arguments)
                AssertComposeFiles $Stack $ExpectFiles
            }

        }