function Import-Stack {
    [CmdletBinding()]
    param(
        [string]$Path
    )

    if (-Not $Path) {
        $FileName = 'stack.json'
        $loc = Get-Location
        while (-Not $Path -and $loc) {
            $filepath = Join-Path $loc $FileName
            if (Test-Path $filepath -PatyType Container) {
                $Path = $filepath
            }
            else {
                $loc = Split-Path $loc -Parent
            }
        }
        if (-Not $Path) {
            throw 'Unable to find stack.json in current directory or any parent'
        }
    }

    $props = Get-Content $Path | ConvertFrom-Json

}