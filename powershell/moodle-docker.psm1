Set-StrictMode -Version 3

# Import source files
Get-ChildItem (Join-Path $PSScriptRoot 'src') | ForEach-Object {
    . $_
}

[string]$BASEDIR = Resolve-Path (Join-Path $PSScriptRoot '..' '..')

$VALID_DB = 'pgsql', 'mysql', 'mssql', 'oracle', 'mariadb'
$VALID_PHP_VERSION = '5.6', '7.0', '7.1', '7.2', '7.3', '7.4', '8.0'
$VALID_APP_RUNTIME = 'ionic3', 'ionic5'
$VALID_HOST_PORT = '(?<HOST>\d+\.\d+\.\d+\.\d+:)?(?<PORT>[1-9]\d*)'
$VALID_BROWSER = '^(?<NAME>chrome|firefox)(:(?<TAG>.+))?$'

$exports = @{
    Variable = '*'
    Function = @(
        'New-Stack'
        'Get-Stack'
    )
}

Export-ModuleMember @exports