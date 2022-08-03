$options = @{
    run = @{

    }
    output = @{
        Verbosity = 'Failed'
    }
}


$c = New-PesterContainer -Path './StackConstruction.tests.ps1'

Invoke-Pester -Container $c