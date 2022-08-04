
$TestStacks = . (Join-Path $PSScriptRoot 'teststacks.ps1')
$TestFile = Join-Path $PSScriptRoot 'testastack.ps1'
$results = $TestStacks | ForEach-Object -ThrottleLimit 100 -Parallel {
    $config = New-PesterConfiguration @{
        run    = @{
            Path = @()
            Container = New-PesterContainer -Data $_ -Path ($using:TestFile)
            PassThru = $true
        }
        output = @{
            Verbosity = 'None'
        }
    }
    Invoke-Pester -Configuration $config
}

$results