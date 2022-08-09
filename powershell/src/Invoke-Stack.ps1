function Invoke-Stack {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [Stack]$Stack,

        [Parameter(Position = 0)]
        [string]$Command
    )

    Process {
        if (-Not $Stack) {
            $Stack = Get-Stack -ErrorAction Stop
        }
        $Stack.Invoke($Command)
    }
}
