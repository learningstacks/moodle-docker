function Get-Stack {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [System.IO.FileInfo]
        [ValidateScript(
            {
                if (-Not (Test-Path $_ -PathType Leaf)) {
                    Throw "File $_ does not exist"
                }
                $true
            }
        )]
        $Path
    )

    if (-Not $Path) {
        # Look for stack.json or stack.env if current directory or any parent
        $loc = Get-Location
        while ($loc -and !$result) {
            foreach ($target in 'stack.json', 'stack.env') {
                $f = Join-Path $loc $target
                if (Test-Path $f -PathType Leaf) {
                    $Path = $f
                }
            }
            if (!$Path) {
                # Now look in parent dir
                $loc = Split-Path $loc -Parent
            }
        }
    }

    if ($Path) {
        if ($Path.Name -eq 'stack.json') {
            # Import previously exported stack definition
            Import-Stack $Path
        }
        elseif ($Path.Name -eq 'stack.env') {
            # Parse parameters from the file
            $data = Import-Csv $Path -Delimiter '=' -Header Name, Value
            $params = @{}
            foreach ($item in $data) {
                $params[$item.Name] = $item.Value
            }
            New-Stack @params
        }
    }
    else {
        # New-Stack will attempt to set parameters from environment variables and default values
        New-Stack -ErrorAction Stop
    }
}
