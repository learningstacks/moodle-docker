class Stack {
    [hashtable]$StackArgs
    [hashtable]$StackParams
    [System.Collections.ArrayList]$ComposeFiles = @()
    [string[]]$ComposeFilePaths = @(
        $PWD
        $BASEDIR
    )
    static hidden [hashtable]$BASE_INVOCATION = $null

    # Stack([hashtable]$StackParams, [string[]]$ComposeFiles) {
    #     $this.StackParams = $StackParams
    #     $this.ComposeFiles = $ComposeFiles
    # }

    Stack([hashtable]$StackArgs) {
        $ErrorActionPreference = 'Stop'
        $this.StackArgs = $StackArgs
        $this.StackParams = Get-StackParams $this.StackArgs
        $this.ComposeFiles = Get-ComposeFiles $this.StackParams $this.ComposeFilePaths
    }

    [boolean] IncludesApp() {
        return ($this.StackParams.MOODLE_DOCKER_APP_PATH -or $this.StackParams.MOODLE_DOCKER_APP_VERSION)
    }

    [void] start() {
        $this.Invoke('up -d')
        $this.WaitDb()
        $this.WaitApp()
        Write-Verbose 'Stack started'
    }

    [Object] Invoke($Command) {
        $Invocation = $this.GetInvocation($Command)
        $result = Invoke-Exec @Invocation
        return $result
    }

    [hashtable] GetInvocation([string]$Command) {
        $files = ($this.ComposeFiles | ForEach-Object { "-f $_" }) -join ' '
        $base = ([Stack]::GetBaseInvocation())
        return @{
            Command     = $base.ComposeExe
            CommandArgs = "$($base.ComposeCommandArgs) $files $Command"
            EnvVars     = $this.StackParams
        }
    }

    [void] WaitDb() {
        $DBType = $this.StackParams.MOODLE_DOCKER_DB

        if (!$DBType) {
            throw 'MOODLE_DOCKER_DB is not set'
        }

        if ($DBType -eq 'mssql') {
            $this.Invoke('exec db /wait-for-mssql-to-come-up.sh')
        }
        elseif ($DBType -eq 'oracle') {
            while (-Not ($this.Invoke('logs db') | Select-String -Pattern 'listening on IP')) {
                Write-Verbose 'Waiting for oracle to come up...'
                Start-Sleep -Seconds 15
            }
        }
        else {
            Start-Sleep 5
        }
    }

    [void] WaitApp() {
        if ($this.IncludesApp()) {
            while (-Not ($this.Invoke('logs moodleapp') | Select-String -Pattern 'dev server running: |Angular Live Development Server is listening|Configuration complete; ready for start up')) {
                Write-Verbose 'Waiting for Moodle app to come up...'
                Start-Sleep -Seconds 15
            }
        }
    }

    static [version] GetDockerComposeVersion() {
        $verstring = $null
        try {
            $Invocation = @{
                Command     = 'docker'
                CommandArgs = 'compose version'
            }
            $verstring = Invoke-Exec @Invocation
        }
        catch {
            $Invocation = @{
                Command     = 'docker-compose'
                CommandArgs = 'version'
            }
            $verstring = Invoke-Exec @Invocation
        }
        if ($verstring -match '^.* v(?<VERSION>.+)$') {
            return [version]$Matches.VERSION
        }
        else {
            throw "Unable to parse docker compose version from $verstring"
        }
    }

    static [hashtable] GetBaseInvocation() {
        if (-Not [Stack]::BASE_INVOCATION ) {
            if ([Stack]::GetDockerComposeVersion() -ge [version]'2.0') {
                [Stack]::BASE_INVOCATION = @{
                    ComposeExe         = 'docker'
                    ComposeCommandArgs = @('compose')
                }
            }
            else {
                [Stack]::BASE_INVOCATION = @{
                    ComposeExe         = 'docker-compose'
                    ComposeCommandArgs = @()
                }
            }
        }
        return [Stack]::BASE_INVOCATION
    }
}