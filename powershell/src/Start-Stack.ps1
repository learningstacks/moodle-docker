function Start-Stack {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [Stack]$Stack
    )

    Process {
        if (-Not $Stack) {
            $Stack = Get-Stack -ErrorAction Stop
        }
        $Stack.Start() | Invoke-Stack 'up -d'
    }
}

