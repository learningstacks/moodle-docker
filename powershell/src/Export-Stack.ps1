function Export-Stack {
    [CmdletBinding()]
    param(
        [string]$Path = (Join-Path $PWD 'stack.json')
    )

    $Hash = @{
        Environment  = $Stack.Environment
        ComposeFiles = $Stack.ComposeFiles
    }

    $Hash | ConvertTo-Json | Out-File -FilePath $Path -Force

}
