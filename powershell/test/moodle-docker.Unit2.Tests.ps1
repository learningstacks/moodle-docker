using module '../moodle-docker.psm1'

 Describe 'moodle-docker.psm1' {

    BeforeAll {
        # Import-Module (Join-Path $PSScriptRoot '..' 'moodle-docker.psm1' ) -Force

        [string]$BaseDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..')

        function GetStackYaml([hashtable]$params) {
            $Stack = New-Stack $params
            $yaml = $Stack | Invoke-Stack 'convert' | ConvertFrom-Yaml
            $yaml
        }

        function ValOrEval([object]$Value) {
            if ($Value -is [scriptblock]) {
                $Value = & $Value
            }
            $Value
        }

        filter NormalizePath {
            $_.ToString() -replace '(/|\\)+', '/'
        }

        function TestDir([string]$Name) {
            Join-Path $TestDrive $name
        }

        function BaseDir([string]$Name) {
            Join-Path (Split-Path $PSScriptRoot) $name
        }

        function AssetDir([string]$Name) {
            Join-Path (BaseDir) 'assets' $name
        }

        function GetParams([hashtable]$Values) {
            $params = @{}
            foreach ($item in $Values.GetEnumerator()) {
                $val = if ($item.Value -is [scriptblock]) { & $item.Value } else { $item.Value }
                $params[$item.Name] = $val
            }
            return $params
        }

        function SetEnvironment([hashtable]$Environment) {
            foreach ($item in $Environment.GetEnumerator()) {
                $val = if ($item.Value -is [scriptblock]) { & $item.Value } else { $item.Value }
                Set-Item -Path "Env:$($item.Name)" -Value $val
            }
        }

        function AssertStackEnvironment([Object]$Stack, [hashtable]$Expect) {
            foreach ($item in $Expect.GetEnumerator()) {
                $val = if ($item.Value -is [scriptblock]) { & $item.Value } else { $item.Value }
                $Stack.Environment[$item.Name] | Should -Be $val
            }
        }

        function AssertComposeFiles([Object]$Stack, [array]$ExpectFiles) {
            $Stack.ComposeFiles | Should -HaveCount ($ExpectFiles.Count)
            $last = $Stack.ComposeFiles.Count - 1
            foreach ($i in 0..$last) {
                $expected = if ($ExpectFiles[$i] -is [scriptblock]) { & $ExpectFiles[$i] } else { $ExpectFiles[$i] }
                $Stack.ComposeFiles[$i] | Should -Be $expected
            }
        }

        function GetComposeFilesList([string[]]$Files) {
            $FileList = foreach ($pos in 0..($Files.Count - 1)) {
                @{
                    Pos  = $pos
                    Path = $Files[$pos]
                }
            }
            return $FileList
        }

        function VerifyStackEnvironment([hashtable]$Environment, [hashtable]$Pass, [hashtable]$Expect) {
            SetEnvironment $Environment
            $params = GetParams $Pass
            $Stack = New-Stack $params
            AssertStackEnvironment $Stack $Expect
        }

        foreach ($name in 'MOODLE', 'MOODLE2', 'APP_3.9.4', 'APP_3.9.5', 'FAILDUMP', 'FAILDUMP2') {
            New-Item -ItemType Directory -Path (TestDir $name)
        }
        @{version = '3.9.4' } | ConvertTo-Json | Set-Content (TestDir 'APP_3.9.4/package.json')
        @{version = '3.9.5' } | ConvertTo-Json | Set-Content (TestDir 'APP_3.9.5/package.json')

    }

    BeforeEach {
    }

    AfterEach {
        Get-ChildItem env: | Where-Object { $_.Name -match '^(MOODLE|COMPOSE)' } | ForEach-Object {
            Remove-Item "Env:$($_.Name)"
        }
    }

    AfterAll {
        #Delete all files and directories in TestDrive:
        Get-ChildItem 'TestDrive:/' | Remove-Item -Force -Recurse
    }

    Describe 'Self-test' {

        It 'Smoke test' {
            1 | Should -Be 1
        }

    }

    Describe 'Stack class' {


        Describe 'Stack Construction' {

            BeforeDiscovery {

                # function ServiceImageMatches([hashtable]$Stack, [string]$ServiceName, [string]$Expected) {
                #     It "Image matches $Expected" {
                #         $Stack.services.$ServiceName | Should -Match $Expected
                #     }
                # }

                # function ServiceEnvironmentIncludes([hashtable]$Stack, [string]$ServiceName, [hashtable]$Expected) {
                #     foreach ($variable in $Expected.GetEnumerator()) {
                #         $Name = $variable.Name
                #         $Value = $variable.Value

                #         It "Environment.$Name = $Value" {
                #             $Stack.$ServiceName.Environment.$Name | Should -Be $Value
                #         }
                #     }

                # }

                # function ServiceIncludesPort([hashtable]$Stack, [string]$ServiceName, [string]$LocalPort, [string]$HostName, [string]$HostPort) {
                #     It "Maps $($LocalPort) to $($HostName):$($HostPort)" {
                #         $port = $Stack.services.ServiceName.ports | Where-Object Source -EQ $HostPort
                #     }
                # }

                # function ServiceVolumesInclude([hashtable]$Stack, [string]$ServiceName, [hashtable]$Expected) {

                # }

                $TestStacks = @(
                    @{
                        Scenario        = 'Default Stack'
                        Params          = @{}
                        Expected = @{
                            services = @(
                                @{ Name = 'moodleapp'; Present = $false }
                                @{
                                    Name         = 'webserver'
                                    Image        = 'moodlehq/moodle-php-apache:7.4'
                                    Environment = @(
                                        @{Name = 'MOODLE_DOCKER_DBTYPE'; Value   = 'pgsql' }
                                        @{Name = 'MOODLE_DOCKER_DBNAME';Value   = 'moodle'}
                                        @{Name = 'MOODLE_DOCKER_DBUSER';Value   = 'moodle'}
                                        @{Name = 'MOODLE_DOCKER_DBPASS';Value   = 'm@0dl3ing'}
                                        @{Name = 'MOODLE_DOCKER_BROWSER';Value  = 'firefox'}
                                        @{Name = 'MOODLE_DOCKER_WEB_HOST';Value = 'localhost'}
                                    )
                                    Ports        = @()
                                    Volumes     = @(
                                        @{Target = '/var/www/html'; Source = { TestDir MOODLE }; Type   = 'bind' }
                                    )

                                }
                            )
                    }
                }
                    @{
                        Scenario        = 'Default Stack with mapped port'
                        Params          = @{
                            MOODLE_DOCKER_WEB_PORT = 40
                        }
                        Expected = @{
                        Services = @(
                            @{
                                Name         = 'webserver'
                                Image        = 'moodlehq/moodle-php-apache:7.4'
                                Environment = @(
                                    @{Name = 'MOODLE_DOCKER_DBTYPE';Value    = 'pgsql'}
                                    @{Name = 'MOODLE_DOCKER_DBNAME';Value    = 'moodle'}
                                    @{Name = 'MOODLE_DOCKER_DBUSER';Value    = 'moodle'}
                                    @{Name = 'MOODLE_DOCKER_DBPASS';Value    = 'm@0dl3ing'}
                                    @{Name = 'MOODLE_DOCKER_BROWSER';Value   = 'firefox'}
                                    @{Name = 'MOODLE_DOCKER_WEB_HOST';Value  = 'localhost'}
                                )
                                Ports        = @(
                                    @{ LocalPort = 80; HostName  = '127.0.0.1'; HostPort  = 40 }
                                )
                                Volumes     = @(
                                    @{ Target = '/var/www/html'; Source = { TestDir MOODLE }; Type   = 'bind' }
                                )
                            }
                        )
                        }
                    }
                )

            }

            Context '<_.Scenario>' -ForEach $TestStacks {

                BeforeDiscovery {
                    $TestStack = $_
                }


                BeforeAll {
                    $TestStack = $_
                    $Params = @{}
                    if (-Not $TestStack.Params.ContainsKey('MOODLE_DOCKER_WWWROOT')) {
                        $TestStack.Params.MOODLE_DOCKER_WWWROOT = TestDir MOODLE
                    }

                    $Stack = ([Stack]::New($TestStack.Params)).Invoke('convert') | ConvertFrom-Yaml
                }

                Context 'Service <Name>' -ForEach $TestStack.Expected.Services {

                    BeforeDiscovery {
                        $ExpectedService = $_
                    }

                    BeforeAll {
                        $ExpectedService = $_
                    }

                    if (!$ExpectedService.ContainsKey('Present') -or $ExpectedService.Present) {
                    It 'Service is included' {
                        $Stack.services.Keys | Should -Contain $ExpectedService.Name
                    }


                    It 'Image matches <Image>' {
                        $Stack.services.$($ExpectedService.Name).image | Should -Match $ExpectedService.Image
                    }

                    It 'environment.<Name> = <Value>' -TestCases $ExpectedService.Environment {
                        $Stack.services.$($ExpectedService.Name).environment.$Name | Should -Be $Value
                    }

                    It 'Port <LocalPort> => <HostName>:<HostPort>' -TestCases $ExpectedService.Ports {
                        $Stack.services.$($ExpectedService.Name).Keys | Should -Contain 'ports'
                        $port = $Stack.services.$($ExpectedService.Name).ports | Where-Object target -EQ $LocalPort
                        $port | Should -Not -BeNullOrEmpty
                        $port.host_ip | Should -Be $_.HostName
                        $port.published | Should -Be $_.HostPort
                    }
                }
                else {
                                      It 'Service is NOT included' {
                        $Stack.services.Keys | Should -Not -Contain $ExpectedService.Name
                    }
                }

                }

            }

        }

        Describe 'Webserver configuration' {

            It 'Defaults to 7.4' {

            }

            It 'Supports PHP "<Version>".' -TestCases @(
                @{Version = '5.6' }
                @{Version = '7.0' }
                @{Version = '7.1' }
                @{Version = '7.2' }
                @{Version = '7.3' }
                @{Version = '7.4' }
                @{Version = '8.0' }
            ) {
                $Stack = [Stack]::New(@{
                        MOODLE_DOCKER_WWWROOT     = TestDir 'MOODLE'
                        MOODLE_DOCKER_PHP_VERSION = $Version
                    })
                $yaml = $Stack.Invoke('convert') | ConvertFrom-Yaml
                $yaml.services.webserver.image | Should -Be "moodlehq/moodle-php-apache:$($Version)"
            }

            It 'rejects' {

            }

        }

        Describe 'DB configuration' {

            It 'Defaults to postgres' {

            }

            It 'Supports <Type>' {

            }

            It 'Rejects <Type>' {

            }

            It 'Adds PHP-specific compose file if found' {

            }

        }

        Describe 'Selenium configuration' {

            It 'Supports VNC debugging' {

            }

            It 'Defaults to Firefox' {

            }

            It 'Supports <Browser>' {
            }

        }

        Describe 'Moodle App configuration' {

            Context 'APP_VERSION' {

                It 'Configures stack for testing with the Moodle App' {

                }

                It 'Infers APP_RUNTIME from APP_VERSION' {

                }

            }

             Context 'APP_PATH' {

                It 'Configures stack for Moodle App development' {

                }

                It 'Infers APP_RUNTIME from APP package.json' {

                }

            }

            It 'Disallows specifying both APP_PATH and APP_VERSION' {

            }

        }

        Describe 'External services configuration' {

            It 'Includes all external services if Parameter MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES is true.' {
                $yaml = GetStackYaml @{
                    MOODLE_DOCKER_WWWROOT                   = TestDir 'MOODLE'
                    MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES = $true
                }

                $yaml.services.memcached0.image | Should -Match '^memcached:.*$'
                $yaml.services.memcached1.image | Should -Match '^memcached:.*$'
                $yaml.services.mongo.image | Should -Match '^mongo:.*$'
                $yaml.services.redis.image | Should -Match '^redis:.*$'
                $yaml.services.solr.image | Should -Match '^solr:.*$'
                $yaml.services.ldap.image | Should -Match 'openldap'

            }
        }

        Describe 'Compose file overriding' {

            It 'A file in current location overrides one from the base' {

            }

        }

        Describe 'Environment setup' {

        }

        Describe 'Stack invocation' {

            It 'Prepares and executes docker compose command' {
                Mock -ModuleName 'moodle-docker' -CommandName 'Invoke-Exec' { }
                $stack = [Stack]@{
                    Name         = 'aproject'
                    ComposeFiles = @(
                        'file1'
                        'file2'
                    )
                }
                $Stack.Invoke('a command')
                Should -Invoke -ModuleName 'moodle-docker' -CommandName 'Invoke-Exec' -Times 1 -Exactly -ParameterFilter {
                    $Command -eq 'docker' && $CommandARgs -eq 'compose -p aproject -f file1 -f file2 a command'
                }
            }

            It 'Returns string output from the command.' {
                Mock -ModuleName 'moodle-docker' -CommandName 'Invoke-Exec' {
                    Write-Output 'This is some output'
                }
                $stack = [Stack]@{
                    Name         = 'aproject'
                    ComposeFiles = @(
                        'file1'
                        'file2'
                    )
                }
                $Stack.Invoke('a command') | Should -Be 'this is some output'
            }

            It 'Returns string array output from the command.' {
                Mock -ModuleName 'moodle-docker' -CommandName 'Invoke-Exec' {
                    Write-Output @('Line 1', 'Line 2')
                }
                $stack = [Stack]@{
                    Name         = 'aproject'
                    ComposeFiles = @(
                        'file1'
                        'file2'
                    )
                }
                $out = $Stack.Invoke('a command')
                $out | Should -HaveCount 2
                $out[0] | Should -Be 'Line 1'
                $out[1] | Should -Be 'Line 2'
            }
        }

        Describe 'Starting the stack' {

            It 'Executes docker compose up -d on the stack' {
                Set-ItResult -Pending
            }

            It 'Waits for Db' {
                Set-ItResult -Pending
            }

            It 'Waits for the App if it is included' {
                Set-ItResult -Pending
            }

            It 'Does not wait for App if the app is not included' {
                Set-ItResult -Pending
            }

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

    }

    Describe 'New-Stack' {

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
            $a = @(
                @{
                    Name    = 'COMPOSE_PROJECT_NAME'
                    Default = 'moodle-docker'
                    Valid   = 'moodle-docker_1', 'moodle-docker_2'
                    Invalid = @()
                }
                @{
                    Name    = 'MOODLE_DOCKER_WWWROOT'
                    Default = $null
                    Valid   = (TestDir MOODLE), (TestDir MOODLE2)
                    Invalid = (TestDir 'nodir')
                }
            )



        }



        Describe 'Valid parameter values' {

            BeforeDiscovery {
                $ValidParameterValues = @(
                    @{
                        Name   = 'COMPOSE_PROJECT_NAME'
                        Values = 'moodle-docker-1', 'moodle-docker-2'
                    }
                    # MOODLE_DOCKER_WWWROOT                   = { TestDir MOODLE }, { TestDir MOODLE2 }
                    # MOODLE_DOCKER_PHP_VERSION               = '5.6', '7.0', '7.1', '7.2', '7.3', '7.4', '8.0'
                    # MOODLE_DOCKER_DB                        = 'mysql', 'mssql', 'oracle', 'mariadb', 'pgsql'
                    # MOODLE_DOCKER_BROWSER                   = 'chrome', 'chrome:3', 'firefox', 'firefox:3'
                    # MOODLE_DOCKER_WEB_HOST                  = 'host1', 'host2'
                    # MOODLE_DOCKER_WEB_PORT                  = 0, 1, '6.6.6.6:8000', '7.7.7.7:8001'
                    # MOODLE_DOCKER_APP_VERSION               = '3.9.4', '3.9.5'
                    # MOODLE_DOCKER_APP_RUNTIME               = 'ionic3', 'ionic5'
                    # MOODLE_DOCKER_APP_PATH                  = { TestDir 'APP_3.9.4' }, { TestDir 'APP_3.9.5' }
                    # MOODLE_DOCKER_BEHAT_FAILDUMP            = { TestDir 'FAILDUMP' }, { TestDir 'FAILDUMP2' }
                    # MOODLE_DOCKER_SELENIUM_VNC_PORT         = 0, 1, '2.2.2.2:2', '3.3.3.3:3'
                    # MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES = $null, $false, 0, 'true', 'anyval'
                )
            }

            Context '<_.Name>'-ForEach $ValidParameterValues {
                BeforeAll {
                    $Name = $_.Name
                    $Values = [string[]]$_.Value
                }

                It 'Accepts <_>' -TestCases $Values {
                    $Value = if ($_ -is [scriptblock]) { & $_ } else { $_ }
                    $param = @{
                        $Name = $Value
                    }
                    if ($Name -ne 'MOODLE_DOCKER_WWWROOT') {
                        $param.MOODLE_DOCKER_WWWROOT = ( TestDir 'MOODLE' )
                    }
                    { New-Stack $param } | Should -Not -Throw
                }
            }
        }

        Describe 'Invalid conditions' {

            It 'Requires MOODLE_DOCKER_WWWROOT parameter' {
                { New-Stack @{} } | Should -Throw
                { New-Stack @{MOODLE_DOCKER_WWWROOT = 'invaliddir' } } | Should -Throw
            }

            It 'Cannot s= <Value>' -TestCases @(
                @{Name = 'MOODLE_DOCKER_DB'; Value = 'invaliddb' }
                @{Name = 'MOODLE_DOCKER_PHP_VERSION'; Value = '5.0' }
                @{Name = 'MOODLE_DOCKER_APP_RUNTIME'; Value = 'ionic4' }
                @{Name = 'MOODLE_DOCKER_APP_PATH'; Value = 'nodir' }
                @{Name = 'MOODLE_DOCKER_BROwSER'; Value = 'safari' }
                @{Name = 'MOODLE_DOCKER_WEB_PORT'; Value = 'non-integer' }
                @{Name = 'MOODLE_DOCKER_WEB_PORT'; Value = '-1' }
            ) {
                $params = @{
                    MOODLE_DOCKER_WWWROOT = TestDir 'MOODLE'
                    $Name                 = $Value
                }
                { New-Stack $params } | Should -Throw
            }

            It 'Disallows Moodle app with non-chrome browser' -TestCases @(
                @{
                    MOODLE_DOCKER_WWWROOT  = { TestDir Moodle }
                    MOODLE_DOCKER_BROWSER  = 'firefox:3'
                    MOODLE_DOCKER_APP_PATH = { TestDir 'APP_3.9.5' }
                }
                @{
                    MOODLE_DOCKER_WWWROOT     = { TestDir Moodle }
                    MOODLE_DOCKER_BROWSER     = 'firefox:3'
                    MOODLE_DOCKER_APP_VERSION = '3.9.5'
                }
            ) {
                { New-Stack (GetParams $_) } | Should -Throw
            }

        }

        Describe 'Derivations' {

            Describe 'Derive MOODLE_DOCKER_BROWSER_NAME and MOODLE_DOCKER_BROWSER_TAG' {
            }

            Describe 'Derive MOODLE_DOCKER_APP_RUNTIME' {

                Context 'When MOODLE_DOCKER_APP_PATH is specified' {

                    It 'App ' -TestCases @(
                        @{Path = '3.9.5' }
                    ) {

                    }

                }

                Describe 'Derive MOODLE_DOCKER_SELENIUM_SUFFIX' {

                }

                Describe 'Derive MOODLE_DOCKER_SELENIUM_VNC_PORT' {

                    It 'Defaults host to 127.0.0.1 if only port # is provided' {

                    }
                }


            }

            Describe 'Parameter Validation' {

                It '<Name> accepts <Values>' -TestCases @(
                    @{
                        Name   = 'MOODLE_DOCKER_DB'
                        Values = 'pgsql', 'mysql', 'mssql', 'oracle', 'mariadb'
                    }
                    @{
                        Name   = 'MOODLE_DOCKER_PHP_VERSION'
                        Values = '5.6', '7.0', '7.1', '7.2', '7.3', '7.4', '8.0'
                    }
                    @{
                        Name   = 'MOODLE_DOCKER_BROWSER'
                        Values = 'chrome', 'chrome:2', 'chrome:3', 'firefox', 'firefox:2', 'firefox:3'
                    }
                ) {

                    $params = @{
                        MOODLE_DOCKER_WWWROOT = TestDir 'MOODLE'
                    }
                    foreach ($value in [array]$Values) {
                        $params.$Name = $Value
                        { New-Stack $params } | Should -Not -Throw -Because "$Name should accept $Value"
                    }
                }

                It 'Rejects <Scenario>' -TestCases @(
                    @{
                        Scenario = 'MOODLE_DOCKER_ROOT = null'
                        Params   = @{
                            MOODLE_DOCKER_WWWROOT = $null
                        }
                    }
                    @{
                        Scenario = 'MOODLE_DOCKER_ROOT = nodir'
                        Params   = @{
                            MOODLE_DOCKER_WWWROOT = 'nodir'
                        }
                    }
                    @{
                        Scenario = 'MOODLE_DOCKER_DB = invaliddb'
                        Params   = @{
                            MOODLE_DOCKER_WWWROOT = { TestDir MOODLE }
                            MOODLE_DOCKER_DB      = 'invaliddb'
                        }
                    }
                    @{
                        Scenario = 'MOODLE_DOCKER_APP_RUNTIME = invaliddb'
                        Params   = @{
                            MOODLE_DOCKER_WWWROOT = { TestDir MOODLE }
                            MOODLE_DOCKER_RUNTIME = 'ionic4'
                        }
                    }
                    @{
                        Scenario = 'Both MOODLE_DOCKER_APP_PATH and MOODLE_DOCKER_APP_VERSION set'
                        Params   = @{
                            MOODLE_DOCKER_WWWROOT     = { TestDir MOODLE }
                            MOODLE_DOCKER_APP_PATH    = { TestDir 'APP_3.9.4' }
                            MOODLE_DOCKER_APP_VERSION = '3.9.5'
                        }
                    }
                ) {
                    { Stack ( GetParams $Pass ) } | Should -Throw
                }

            }

        }
    }

    Describe 'Webserver service configuration' {

        Context 'PHP Version' {

            It 'Supports PHP "<Version>".' -TestCases @(
                @{Version = '5.6' }
                @{Version = '7.0' }
                @{Version = '7.1' }
                @{Version = '7.2' }
                @{Version = '7.3' }
                @{Version = '7.4' }
                @{Version = '8.0' }
            ) {
                $yaml = GetStackYaml @{
                    MOODLE_DOCKER_WWWROOT     = TestDir 'MOODLE'
                    MOODLE_DOCKER_PHP_VERSION = $Version
                }
                $yaml.services.webserver.image | Should -Be "moodlehq/moodle-php-apache:$($Version)"
            }

        }

        Describe 'Webserver port mapping' {

            It 'MOODLE_DOCKER_WEB_PORT = <MOODLE_DOCKER_WEB_PORT>' -TestCases @(
                @{
                    Scenario               = 'No mapping when port = $null'
                    MOODLE_DOCKER_WEB_PORT = $null
                    Expect                 = $null
                }
                @{
                    Scenario               = 'Port = 0 => no mapping'
                    MOODLE_DOCKER_WEB_PORT = 0
                    Expect                 = $null
                }
                @{
                    Scenario               = 'Port = port only => 127.0.0.1:port'
                    MOODLE_DOCKER_WEB_PORT = '8000'
                    Expect                 = @{
                        Host = '127.0.0.1'
                        Port = '8000'
                    }
                }
                @{
                    Scenario               = 'Port = $null => no mapping'
                    MOODLE_DOCKER_WEB_PORT = '6.6.6.6:8001'
                    Expect                 = @{
                        Host = '6.6.6.6'
                        Port = '8001'
                    }
                }
            ) {
                $params = @{
                    MOODLE_DOCKER_WWWROOT  = TestDir 'MOODLE'
                    MOODLE_DOCKER_WEB_PORT = $MOODLE_DOCKER_WEB_PORT
                }
                $yaml = GetStackYaml $params
                if ($null -eq $Expect) {
                    $yaml.services.webserver.Keys | Should -Not -Contain 'ports'
                }
                else {
                    $yaml.services.webserver.ports[0].Target | Should -Be '80'
                    $yaml.services.webserver.ports[0].host_ip | Should -Be $Expect.Host
                    $yaml.services.webserver.ports[0].published | Should -Be $Expect.Port
                }
            }


            # It 'If port is not specified, web server port is not mapped.' {
            #     $yaml = GetStackYaml @{
            #         MOODLE_DOCKER_WWWROOT = TestDir 'MOODLE'
            #     }
            #     $yaml.services.webserver.Keys | Should -Not -Contain 'ports'
            # }

            # It 'If port is 0, web server port is not mapped.' {
            #     $yaml = GetStackYaml @{
            #         MOODLE_DOCKER_WWWROOT  = TestDir 'MOODLE'
            #         MOODLE_DOCKER_WEB_PORT = 0
            #     }
            #     $yaml.services.webserver.Keys | Should -Not -Contain 'ports'
            # }

            # It 'If just the port is specified, web server port is mapped to 127.0.0.1:<port>.' {
            #     $yaml = GetStackYaml @{
            #         MOODLE_DOCKER_WWWROOT  = TestDir 'MOODLE'
            #         MOODLE_DOCKER_WEB_PORT = '8000'
            #     }
            #     $yaml.services.webserver.ports[0].Target | Should -Be '80'
            #     $yaml.services.webserver.ports[0].host_ip | Should -Be '127.0.0.1'
            #     $yaml.services.webserver.ports[0].published | Should -Be '8000'
            # }

            # It 'If IP and Port are specified, port 80 is mapped to <IP>:<port>.' {
            #     $yaml = GetStackYaml @{
            #         MOODLE_DOCKER_WWWROOT  = TestDir 'MOODLE'
            #         MOODLE_DOCKER_WEB_PORT = '172.1.1.1:8100'
            #     }
            #     $yaml.services.webserver.ports[0].Target | Should -Be '80'
            #     $yaml.services.webserver.ports[0].host_ip | Should -Be '172.1.1.1'
            #     $yaml.services.webserver.ports[0].published | Should -Be '8100'
            # }
        }

    }

    Describe 'Mail service (MailHog) configuration' {

        It 'Configures mailhog service by default.' {
            $yaml = GetStackYaml @{
                MOODLE_DOCKER_WWWROOT = TestDir 'MOODLE'
            }
            $yaml.services.mailhog.image | Should -Be 'mailhog/mailhog'
            $yaml.services.webserver.depends_on.mailhog | Should -Not -BeNullOrEmpty
            $vol = $yaml.services.webserver.volumes | Where-Object {
                $_.target -eq '/etc/apache2/conf-enabled/apache2_mailhog.conf'
            }
            $vol | Should -Not -BeNullOrEmpty
                ( $vol.source | NormalizePath) | Should -Be (BaseDir 'assets/web/apache2_mailhog.conf' | NormalizePath)
        }

    }

    Describe 'DB service Configuration' {

        It '<Scenario>.' -TestCases @(
            @{
                Scenario = 'Defaults to postgres'
                Image    = 'postgres:11'
                DBType   = 'pgsql'
            }
            @{
                Scenario = 'Supports Postgres'
                DB       = 'pgsql'
                Image    = 'postgres:11'
                DBType   = 'pgsql'
            }
            @{
                Scenario = 'Supports mariadb'
                DB       = 'mariadb';
                Image    = 'mariadb:10.5'
                DBType   = 'mariadb'
            }
            @{
                Scenario = 'Supports mysql'
                DB       = 'mysql'
                Image    = 'mysql:5'
                DBType   = 'mysqli'
            }
            @{
                Scenario = 'Supports SQL Server'
                DB       = 'mssql'
                Image    = 'moodlehq/moodle-db-mssql'
                DBType   = 'sqlsrv'
            }
            @{
                Scenario   = 'Supports SQL Server with PHP 5.6'
                DB         = 'mssql'
                PHPVersion = '5.6'
                Image      = 'moodlehq/moodle-db-mssql'
                DBType     = 'mssql'
            }
            @{
                Scenario = 'Supports Oracle'
                DB       = 'oracle'
                Image    = 'moodlehq/moodle-db-oracle-r2'
                DBType   = 'oci'
            }
        ) {
            $params = @{
                MOODLE_DOCKER_WWWROOT     = TestDir 'MOODLE'
                MOODLE_DOCKER_PHP_VERSION = $PHPVersion ? $PHPVersion : '7.3'
            }
            if ($DB) { $params.MOODLE_DOCKER_DB = $DB }
            $yaml = GetStackYaml $params
            $yaml.services.db.image | Should -Be $Image
            $yaml.services.webserver.environment.MOODLE_DOCKER_DBTYPE | Should -Be $DBType
        }

    }

    Describe 'Selenium service configuration' {

        It "Defaults to 'firefox:3." {
            $yaml = GetStackYaml @{
                MOODLE_DOCKER_WWWROOT = TestDir 'MOODLE'
            }
            $yaml.services.selenium.image | Should -Be 'selenium/standalone-firefox:3'
            $yaml.services.selenium.ports | Should -BeNullOrEmpty
        }

        It 'Supports <Browser>.' -TestCases @(
            @{Browser = 'firefox'; Name = 'firefox'; Tag = 3 }
            @{Browser = 'firefox:2'; Name = 'firefox'; Tag = 2 }
            @{Browser = 'firefox:3'; Name = 'firefox'; Tag = 3 }
            @{Browser = 'chrome'; Name = 'chrome'; Tag = 3 }
            @{Browser = 'chrome:2'; Name = 'chrome'; Tag = 2 }
            @{Browser = 'chrome:3'; Name = 'chrome'; Tag = 3 }
        ) {
            $yaml = GetStackYaml @{
                MOODLE_DOCKER_WWWROOT = TestDir 'MOODLE'
                MOODLE_DOCKER_BROWSER = $Browser
            }
            $yaml.services.selenium.image | Should -Be "selenium/standalone-$($Name):$($Tag)"
            $yaml.services.selenium.ports | Should -BeNullOrEmpty }

        It 'Can enable VNC debug (<Scenario>).' -TestCases @(
            @{Scenario = 'Port only'; Port = '8100'; HostIP = '127.0.0.1'; HostPort = 8100 }
            @{Scenario = 'ip:port'; Port = '172.1.1.1:8200'; HostIP = '172.1.1.1'; HostPort = 8200 }
        ) {
            $yaml = GetStackYaml @{
                MOODLE_DOCKER_WWWROOT           = TestDir 'MOODLE'
                MOODLE_DOCKER_BROWSER           = 'chrome'
                MOODLE_DOCKER_SELENIUM_VNC_PORT = $Port
            }
            $yaml.services.selenium.image | Should -Be 'selenium/standalone-chrome-debug:3'
            $yaml.services.selenium.ports | Where-Object {
                $_.target -eq 5900 `
                    -and $_.host_ip -eq $HostIP `
                    -and $_.published -eq $HostPort
            } | Should -HaveCount 1
        }

    }

    Describe 'Moodleapp service configuration' {

        Context 'MoodleApp Development' {

            It 'If MOODLE_DOCKER_APP_PATH is specified a development config is used (<Scenario>).' {
                @{version = '3.9.5' } | ConvertTo-Json | Set-Content "$appdir/package.json"
                $yaml = GetStackYaml @{
                    MOODLE_DOCKER_WWWROOT  = TestDir 'MOODLE'
                    MOODLE_DOCKER_BROWSER  = 'chrome'
                    MOODLE_DOCKER_APP_PATH = $appdir
                }
                $yaml.services.moodleapp.image | Should -Match '^node:[0-9]+$'
                $yaml.services.moodleapp.ports.count | Should -BeGreaterThan 0
            }

            It 'MOODLE_DOCKER_APP_PATH must be an existing directory.' {
                $params = @{
                    MOODLE_DOCKER_WWWROOT  = $PSScriptRoot
                    MOODLE_DOCKER_BROWSER  = 'chrome'
                    MOODLE_DOCKER_APP_PATH = "$TestDrive/nodir"
                }
                { New-Stack @params } | Should -Throw
            }

            It 'App package.json version determines MOODLE_DOCKER_APP_RUNTIME: (<Scenario>).' -TestCases @(
                @{
                    Scenario = 'Version -lt 3.9.5 => ionic3'
                    Version  = '3.9.4'
                    Expected = 'ionic3'
                }
                @{
                    Scenario = 'Version -eq 3.9.5 => ionic5'
                    Version  = '3.9.5'
                    Expected = 'ionic5'
                }
            ) {
                @{version = $Version } | ConvertTo-Json | Set-Content "$appdir/package.json"
                $yaml = GetStackYaml @{
                    MOODLE_DOCKER_WWWROOT  = TestDir 'MOODLE'
                    MOODLE_DOCKER_BROWSER  = 'chrome'
                    MOODLE_DOCKER_APP_PATH = $appdir
                }
                if ([version]$Version -ge [version]'3.9.5') {
                    $yaml.services.moodleapp.image | Should -Be 'node:14'
                }
                else {
                    $yaml.services.moodleapp.image | Should -Be 'node:11'
                }
            }

            It 'MOODLE_DOCKER_APP_RUNTIME overrides package.json version  (<Scenario>).' -TestCases @(
                @{
                    Scenario = 'Version 3.9.5 overridden to ionic3'
                    Version  = '3.9.5'
                    Runtime  = 'ionic3'
                }
                @{
                    Scenario = 'Version 3.9.4 overridden to ionic5'
                    Version  = '3.9.4'
                    Runtime  = 'ionic5'
                }
            ) {
                @{version = $Version } | ConvertTo-Json | Set-Content "$appdir/package.json"
                $yaml = GetStackYaml @{
                    MOODLE_DOCKER_WWWROOT     = TestDir 'MOODLE'
                    MOODLE_DOCKER_BROWSER     = 'chrome'
                    MOODLE_DOCKER_APP_PATH    = $appdir
                    MOODLE_DOCKER_APP_RUNTIME = $Runtime
                }
                $yaml.services.webserver.environment.MOODLE_DOCKER_APP | Should -Be 'true'
                if ($Runtime -eq 'ionic5') {
                    $yaml.services.moodleapp.image | Should -Be 'node:14'
                }
                else {
                    $yaml.services.moodleapp.image | Should -Be 'node:11'
                }
            }

        }

        Context 'MoodleApp Test' {

            It 'If MOODLE_DOCKER_APP_VERSION is specified a non-development config is used (<Scenario>).' -TestCases @(
                @{
                    Scenario = 'Version 3.9.4 => ionic3'
                    Version  = '3.9.4'
                    Expected = 'ionic3'
                }
                @{
                    Scenario = 'Version 3.9.5 => ionic5'
                    Version  = '3.9.5'
                    Expected = 'ionic5'
                }
            ) {
                $yaml = GetStackYaml @{
                    MOODLE_DOCKER_WWWROOT     = TestDir 'MOODLE'
                    MOODLE_DOCKER_BROWSER     = 'chrome'
                    MOODLE_DOCKER_APP_VERSION = $Version
                }
                $yaml.services.webserver.environment.MOODLE_DOCKER_APP | Should -Be 'true'
                $yaml.services.moodleapp.image | Should -Match "^moodlehq/moodleapp:$($Version)$"
                if ([version]$Version -ge [version]'3.9.5') {
                    $yaml.services.webserver.environment.MOODLE_DOCKER_APP_PORT | Should -Be 80
                    $yaml.services.moodleapp.ports[0].Target | Should -Be '80'
                    $yaml.services.moodleapp.ports[0].published | Should -Be '8100'
                }
                else {
                    $yaml.services.moodleapp.Keys | Should -Not -Contain 'ports'
                }
            }

            It 'Parameter MOODLE_DOCKER_APP_RUNTIME overrides version (<Scenario>).' -TestCases @(
                @{
                    Scenario = 'Version 3.9.5 overridden to ionic3'
                    Version  = '3.9.5'
                    Runtime  = 'ionic3'
                }
                @{
                    Scenario = 'Version 3.9.4 overridden to ionic5'
                    Version  = '3.9.4'
                    Runtime  = 'ionic5'
                }
            ) {
                $yaml = GetStackYaml @{
                    MOODLE_DOCKER_WWWROOT     = TestDir 'MOODLE'
                    MOODLE_DOCKER_BROWSER     = 'chrome'
                    MOODLE_DOCKER_APP_VERSION = $Version
                    MOODLE_DOCKER_APP_RUNTIME = $Runtime
                }
                $yaml.services.webserver.environment.MOODLE_DOCKER_APP | Should -Be 'true'
                $yaml.services.moodleapp.image | Should -Match "^moodlehq/moodleapp:$($Version)$"
                if ($Runtime -eq 'ionic5') {
                    $yaml.services.webserver.environment.MOODLE_DOCKER_APP_PORT | Should -Be 80
                    $yaml.services.moodleapp.ports[0].Target | Should -Be '80'
                    $yaml.services.moodleapp.ports[0].published | Should -Be '8100'
                }
                else {
                    $yaml.services.moodleapp.Keys | Should -Not -Contain 'ports'
                }

            }

        }

        It 'Disallows specifying both MOODLE_DOCKER_APP_PATH and MOODLE_DOCKER_APP_VERSION.' {
            @{version = '3.9.5' } | ConvertTo-Json | Set-Content "$appdir/package.json"
            $params = @{
                MOODLE_DOCKER_WWWROOT     = TestDir 'MOODLE'
                MOODLE_DOCKER_BROWSER     = 'chrome'
                MOODLE_DOCKER_APP_PATH    = $appdir
                MOODLE_DOCKER_APP_VERSION = '3.9.5'
            }
            { New-Stack @params } | Should -Throw
        }

        It 'If browser is not chrome, app will not be included.' {
            $yaml = GetStackYaml @{
                MOODLE_DOCKER_WWWROOT  = TestDir 'MOODLE'
                MOODLE_DOCKER_BROWSER  = 'firefox'
                MOODLE_DOCKER_APP_PATH = $appdir
            }

            $yaml.services.Keys | Should -Not -Contain 'moodleapp'
        }

    }

    Describe 'Get-Stack' -Skip {

        BeforeEach {
            $loc = Get-Location
            New-Item -ItemType Directory -Path 'TestDrive:/proj/subdir'
            Get-ChildItem 'TestDrive:/' -Recurse stackdef.* | Should -BeNullOrEmpty
        }

        AfterEach {
            Set-Location $loc
        }

        It 'Loads Stack config from stackdef.<Type> file in current working directory.' -TestCases @(
            @{Type = 'ps1' }
            @{Type = 'json' }
            @{Type = 'yml' }
        ) {
            $dir = 'TestDrive:/proj/subdir'
            switch ($Type) {
                'ps1' {
                    @(
                        '@{'
                        "   MOODLE_DOCKER_WWWROOT = 'TestDir 'MOODLE''"
                        '}'
                    ) | Set-Content "$dir/stackdef.ps1"
                }
                'json' {
                    @{
                        MOODLE_DOCKER_WWWROOT = TestDir 'MOODLE'
                    } | ConvertTo-Json | Set-Content "$dir/stackdef.json"
                }
                'yml' {
                    @{
                        MOODLE_DOCKER_WWWROOT = TestDir 'MOODLE'
                    } | ConvertTo-Yaml | Set-Content "$dir/stackdef.yml"
                }
            }
            Set-Location 'TestDrive:/proj/subdir'
            $stack = Get-Stack
            $stack | Should -Not -BeNullOrEmpty
            $stack.Env.MOODLE_DOCKER_WWWROOT | Should -Be TestDir 'MOODLE'
        }

        It 'Loads Stack config from Stack.<Type> file in any parent of current working directory.' -TestCases @(
            @{Type = 'ps1' }
            @{Type = 'json' }
            @{Type = 'yml' }
        ) {
            $dir = 'TestDrive:/proj'
            switch ($Type) {
                'ps1' {
                    @(
                        '@{'
                        "   MOODLE_DOCKER_WWWROOT = 'TestDir 'MOODLE''"
                        '}'
                    ) | Set-Content "$dir/stackdef.ps1"
                }
                'json' {
                    @{
                        MOODLE_DOCKER_WWWROOT = TestDir 'MOODLE'
                    } | ConvertTo-Json | Set-Content "$dir/stackdef.json"
                }
                'yml' {
                    @{
                        MOODLE_DOCKER_WWWROOT = TestDir 'MOODLE'
                    } | ConvertTo-Yaml | Set-Content "$dir/stackdef.yml"
                }
            }
            Set-Location 'TestDrive:/proj/subdir'
            $stack = Get-Stack
            $stack | Should -Not -BeNullOrEmpty
            $stack.Env.MOODLE_DOCKER_WWWROOT | Should -Be TestDir 'MOODLE'
        }

        It 'Loads Stack config from a specified file.' -TestCases @(
            @{Type = 'ps1' }
            @{Type = 'json' }
            @{Type = 'yml' }
        ) {
            $path = "TestDrive:/proj/foo.$Type"
            switch ($Type) {
                'ps1' {
                    @(
                        '@{'
                        "   MOODLE_DOCKER_WWWROOT = 'TestDir 'MOODLE''"
                        '}'
                    ) | Set-Content $path
                }
                'json' {
                    @{
                        MOODLE_DOCKER_WWWROOT = TestDir 'MOODLE'
                    } | ConvertTo-Json | Set-Content $path
                }
                'yml' {
                    @{
                        MOODLE_DOCKER_WWWROOT = TestDir 'MOODLE'
                    } | ConvertTo-Yaml | Set-Content $path
                }
            }
            $stack = Get-Stack -Path $path
            $stack | Should -Not -BeNullOrEmpty
            $stack.Env.MOODLE_DOCKER_WWWROOT | Should -Be TestDir 'MOODLE'
        }

        It 'resolves paths relative to the stackdef file location.' {
            $path = 'TestDrive:/proj/foo.json'
            New-Item -Type Directory -Path 'TestDrive:/proj/lms/moodle'
            New-Item -Type Directory -Path 'TestDrive:/proj/app'

            @{
                MOODLE_DOCKER_WWWROOT  = 'lms\moodle'
                MOODLE_DOCKER_APP_PATH = 'app'
            } | ConvertTo-Json | Set-Content 'TestDrive:/proj/foo.json'

            $stack = Get-Stack -Path $path
            $stack | Should -Not -BeNullOrEmpty
            $stack.Env.MOODLE_DOCKER_WWWROOT | Should -Be ("$(Convert-Path TestDrive:/)/proj/lms/moodle" | NormalizePath)
            $stack.Env.MOODLE_DOCKER_APP_PATH | Should -Be ("$(Convert-Path TestDrive:/)/proj/app" | NormalizePath)
        }

        It 'Throws if Path parameter does not reference an existing file.' {
            $path = 'TestDrive:/proj/foo.ps1'
            { Get-Stack -Path $path -ErrorAction Stop } | Should -Throw
        }

        It 'Throws if stackdef file not found in dir hierarchy.' {
            Set-Location 'TestDrive:/proj/subdir'
            { Get-Stack -ErrorAction Stop } | Should -Throw
        }

    }

    Describe 'Start-Stack' {

        It 'Executes docker compose up -d on the stack' {
            Set-ItResult -Pending
        }

        It 'Waits for Db' {
            Set-ItResult -Pending
        }

        It 'Waits for the App if it is included' {
            Set-ItResult -Pending
        }

    }

    Describe 'Invoke-Stack' {

        It 'Prepares and executes docker compose command' {
            Mock -ModuleName 'moodle-docker' -CommandName 'Invoke-Exec' { }
            $stack = [Stack]@{
                Name         = 'aproject'
                ComposeFiles = @(
                    'file1'
                    'file2'
                )
            }
            $Stack.Invoke('a command')
            Should -Invoke -ModuleName 'moodle-docker' -CommandName 'Invoke-Exec' -Times 1 -Exactly -ParameterFilter {
                $Command -eq 'docker' && $CommandARgs -eq 'compose -p aproject -f file1 -f file2 a command'
            }
        }

        It 'Returns string output from the command.' {
            Mock -ModuleName 'moodle-docker' -CommandName 'Invoke-Exec' {
                Write-Output 'This is some output'
            }
            $stack = [Stack]@{
                Name         = 'aproject'
                ComposeFiles = @(
                    'file1'
                    'file2'
                )
            }
            $Stack.Invoke('a command') | Should -Be 'this is some output'
        }

        It 'Returns string array output from the command.' {
            Mock -ModuleName 'moodle-docker' -CommandName 'Invoke-Exec' {
                Write-Output @('Line 1', 'Line 2')
            }
            $stack = [Stack]@{
                Name         = 'aproject'
                ComposeFiles = @(
                    'file1'
                    'file2'
                )
            }
            $out = $Stack.Invoke('a command')
            $out | Should -HaveCount 2
            $out[0] | Should -Be 'Line 1'
            $out[1] | Should -Be 'Line 2'
        }
    }

    Describe 'Wait-Db' {

        Context 'mssql' {

            It 'Executes container script.' {
                Mock -ModuleName 'moodle-docker' -CommandName 'Invoke-Exec' { }
                Mock -ModuleName 'moodle-docker' -CommandName 'Start-Sleep' { }
                $params = @{
                    MOODLE_DOCKER_WWWROOT = TestDir 'MOODLE'
                    MOODLE_DOCKER_DB      = 'mssql'
                }
                $stack = New-Stack @params
                $stack.WaitForDb()
                Should -Invoke -ModuleName 'moodle-docker' -CommandName 'Invoke-Exec' -ParameterFilter {
                    $CommandArgs -match 'exec --no-TTY db /wait-for-mssql-to-come-up.sh$'
                }
                Should -Not -Invoke -ModuleName 'moodle-docker' -CommandName 'Start-Sleep'
            }
        }

        Context 'Oracle' {

            It "Waits for db service log entry: 'listening on IP'." {
                $script:calls = 0
                Mock -ModuleName 'moodle-docker' -CommandName 'Invoke-Exec' {
                    $script:calls += 1
                    if ($script:calls -le 1) {
                        # Return log string that does not indicate app is up
                        'a string'
                    }
                    else {
                        @(
                            'a line'
                            'xxxlistening on IP...xxx'
                            'another line'
                        )
                    }

                }
                Mock -ModuleName 'moodle-docker' -CommandName 'Start-Sleep' { }
                $params = @{
                    MOODLE_DOCKER_WWWROOT = TestDir 'MOODLE'
                    MOODLE_DOCKER_DB      = 'oracle'
                }
                $stack = New-Stack @params
                $stack.WaitForDB()
                Should -Invoke -ModuleName 'moodle-docker' -CommandName 'Invoke-Exec' -Times 2 -ParameterFilter {
                    $CommandArgs -match 'logs db$'
                }
                Should -Invoke -ModuleName 'moodle-docker' -CommandName 'Start-Sleep' -Times 1 -Exactly

            }

        }

        Context 'All other DBs' {

            It 'Sleeps for 5 seconds.' -TestCases @(
                @{DB = 'pgsql' }
                @{DB = 'mysql' }
                @{DB = 'mariadb' }
            ) {
                Mock -ModuleName 'moodle-docker' -CommandName 'Invoke-Exec' { }
                Mock -ModuleName 'moodle-docker' -CommandName 'Start-Sleep' { }
                $params = @{
                    MOODLE_DOCKER_WWWROOT = TestDir 'MOODLE'
                    MOODLE_DOCKER_DB      = $DB
                }
                $stack = New-Stack @params
                $stack.WaitForDB()
                Should -Not -Invoke -ModuleName 'moodle-docker' -CommandName 'Invoke-Exec'
                Should -Invoke -ModuleName 'moodle-docker' -CommandName 'Start-Sleep' -Times 1 -ParameterFilter {
                    $Seconds -eq 5
                }
            }

        }
    }

    Describe 'Wait-App' -Skip {

        Context 'Moodle App not included' {

            It 'Does not wait if moodleapp service is not included.' {
                Mock -ModuleName 'moodle-docker' -CommandName 'Invoke-Exec' { }
                Mock -ModuleName 'moodle-docker' -CommandName 'Start-Sleep' { }
                $stack = [Stack]@{
                    Name = 'aproject'
                }

                $stack.WaitForApp()
                Should -Not -Invoke -ModuleName 'moodle-docker' -CommandName 'Invoke-Exec'
                Should -Not -Invoke -ModuleName 'moodle-docker' -CommandName 'Start-Sleep'
            }
        }

        It "For <Scenario> configuration, Considers test app to be up if moodleapp log contains '<String>'." -TestCases @(
            @{
                Scenario = 'Development'
                String   = 'dev server running: '
            }
            @{
                Scenario = 'Development'
                String   = 'Angular Live Development Server is listening'
            }
            @{
                Scenario = 'Development'
                String   = 'Configuration complete; ready for start up'
            }
            @{
                Scenario = 'Test'
                String   = 'dev server running: '
            }
            @{
                Scenario = 'Test'
                String   = 'Angular Live Development Server is listening'
            }
            @{
                Scenario = 'Test'
                String   = 'Configuration complete; ready for start up'
            }
        ) {
            $script:calls = 0
            Mock -ModuleName 'moodle-docker' -CommandName 'Invoke-Exec' {
                $script:calls += 1
                if ($script:calls -le 1) {
                    # Return log string that does not indicate app is up
                    'a string'
                }
                else {
                    @(
                        'a line'
                        "xxx$($String)xxx"
                        'another line'
                    )
                }
            }
            Mock -ModuleName 'moodle-docker' -CommandName 'Start-Sleep' { }
            @{version = '3.9.5' } | ConvertTo-Json | Set-Content "$appdir/package.json"
            $stack = New-Stack @{
                MOODLE_DOCKER_WWWROOT  = TestDir MOODLE
                MOODLE_DOCKER_APP_PATH = TestDir APP_3.9.5
            }
            $stack.WaitForApp()
            Should -Invoke -ModuleName 'moodle-docker' -CommandName 'Invoke-Exec' -Times 2 -Exactly
            Should -Invoke -ModuleName 'moodle-docker' -CommandName 'Start-Sleep' -Times 1 -Exactly
        }

    }

    Describe 'Import-Stack' -Skip {

        It 'Can be imported from JSON' -Skip {
            $hash = @{
                Environment  = @{

                }
                ComposeFiles = @(

                )

            }
            $Stack = [Stack]$hash
            $json = $Stack | ConvertTo-Json -Depth 5
            $Stack2 = [Stack](ConvertFrom-Json -InputObject $json -AsHashtable)
            VerifyStack $Stack2 $hash
        }

    }

    Describe 'Export-Stack' -Skip {

        It 'Can be serialized to JSON' -Skip {
            $Stack = New-Stack @{

            }
            $hash = @{
                Name              = 'stackname'
                MoodleServiceName = 'moodleservice'
                MoodleDir         = 'moodledir'
                BehatDataDir      = 'moodledir/behatdata'
                PhpunitDataDir    = 'moodledir/phpunitdata'
                MoodleDataDir     = 'moodledir/moodledata'
                RunDir            = 'moodledir/testrun'
                Env               = @{
                    Env1 = 'env1 value'
                    Env2 = 'env2 value'
                }
                ComposeFiles      = @(
                    'file1'
                    'file2'
                )
            }
            $Stack = [Stack]$hash
            $json = $Stack | ConvertTo-Json -Depth 5
            $Stack2 = [Stack](ConvertFrom-Json -InputObject $json -AsHashtable)
            VerifyStack $Stack2 $hash
        }

    }

    Describe 'Invoke-Exec' {

    }
}