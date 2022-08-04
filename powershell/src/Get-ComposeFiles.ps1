function Get-ComposeFiles([hashtable]$StackParams, [string[]]$SearchPaths) {

    [System.Collections.ArrayList]$ComposeFiles = @()

    function FindComposeFile([string]$FileName) {
        $FilePaths = $SearchPaths | Join-Path -ChildPath $FileName
        $FoundFiles = $filePaths | Where-Object { Test-Path $_ -PathType Leaf }
        $FoundFiles | Select-Object -First 1
    }

    function AddComposeFile([string]$FileName, [scriptblock]$Condition) {
        $ComposeFile = FindComposeFile $FileName
        $ShouldInclude = & $Condition
        if ($ShouldInclude) {
            if (-Not $ComposeFile) { throw "$FileName not found" }
            $null = $ComposeFiles.Add($ComposeFile)
        }
    }

    $ComposeFileRules = @(
        @{
            FileName  = 'base.yml'
            Condition = { $true }
        }
        @{
            FileName  = 'service.mail.yml'
            Condition = { $true }
        }
        @{
            FileName  = "db.$($this.StackParams.MOODLE_DOCKER_DB).yml"
            Condition = { $this.StackParams.MOODLE_DOCKER_DB -ne 'pgsql' }
        }
        @{
            FileName  = "db.$($this.StackParams.MOODLE_DOCKER_DB).$($this.StackParams.MOODLE_DOCKER_PHP_VERSION).yml"
            Condition = { $ComposeFile -and (Test-Path $ComposeFile -PathType Leaf) }
        }
        @{
            FileName  = "selenium.$($this.StackParams.MOODLE_DOCKER_BROWSER_NAME).yml"
            Condition = { $this.StackParams.MOODLE_DOCKER_BROWSER_NAME -ne 'firefox' }
        }
        @{
            FileName = 'selenium.debug.yml'
            Condition = { $this.StackParams.MOODLE_DOCKER_SELENIUM_VNC_PORT }
        }
        @{
            FileName  = "moodle-app-dev-$($this.StackParams.MOODLE_DOCKER_APP_RUNTIME).yml"
            Condition = { $this.StackParams.MOODLE_DOCKER_APP_PATH }
        }
        @{
            FileName  = "moodle-app-$($this.StackParams.MOODLE_DOCKER_APP_RUNTIME).yml"
            Condition = { $this.StackParams.MOODLE_DOCKER_APP_VERSION }
        }
        @{
            FileName  = 'phpunit-external-services.yml'
            Condition = { $this.StackParams.MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES }
        }
        @{
            FileName  = 'webserver.port.yml'
            Condition = { $this.StackParams.MOODLE_DOCKER_WEB_PORT }
        }
        @{
            FileName  = 'volumes-cached.yml'
            Condition = { $global:IsMacOs }
        }
    )

    foreach ($rule in $ComposeFileRules) {
        AddComposeFile @rule
    }

    [array]$ComposeFiles

}