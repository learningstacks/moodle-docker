<#
    .SYNOPSIS
    Create a new Stack instance.
#>
function New-Stack {
    param(
        [Parameter(Mandatory)]
        [hashtable]$StackArgs
    )

    [Stack]::New($StackArgs)
}