function Convert-ToDictionary {
    [CmdletBinding()]
    param(
        # Pipe your objects or CSV rows in here
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject] $InputObject,

        # Column/property to use as the key
        [string] $KeyProperty = 'Name',

        # Choose the value: the whole object (default), a single property, or a script
        [string] $ValueProperty,
        [scriptblock] $ValueScript,

        # Case sensitivity and duplicate-key behavior
        [switch] $CaseSensitive,
        [ValidateSet('Overwrite','Skip','Error','Append')]
        [string] $OnDuplicate = 'Overwrite'
    )

    begin {
        $comparer = if ($CaseSensitive) { [StringComparer]::Ordinal } else { [StringComparer]::OrdinalIgnoreCase }
        $dict = [System.Collections.Generic.Dictionary[string,object]]::new($comparer)
    }

    process {
        if (-not $InputObject.PSObject.Properties[$KeyProperty]) {
            throw "Key property '$KeyProperty' does not exist on: $($InputObject | Out-String)"
        }

        $key = [string]$InputObject.$KeyProperty
        if ([string]::IsNullOrWhiteSpace($key)) { return }

        $value =
            if ($PSBoundParameters.ContainsKey('ValueScript')) { & $ValueScript $InputObject }
            elseif ($PSBoundParameters.ContainsKey('ValueProperty')) { $InputObject.$ValueProperty }
            else { $InputObject }

        if ($dict.ContainsKey($key)) {
            switch ($OnDuplicate) {
                'Overwrite' { $dict[$key] = $value }
                'Skip'      { }
                'Error'     { throw "Duplicate key '$key' encountered." }
                'Append'    {
                    $existing = $dict[$key]
                    if ($existing -isnot [System.Collections.IList]) {
                        $list = [System.Collections.Generic.List[object]]::new()
                        [void]$list.Add($existing)
                        $dict[$key] = $list
                    }
                    [void]($dict[$key]).Add($value)
                }
            }
        } else {
            $dict[$key] = $value
        }
    }

    end { return $dict }
}
<#
$rows = @(
  [pscustomobject]@{ Name='Alpha'; Id=1; Path='/a' },
  [pscustomobject]@{ Name='Beta' ; Id=2; Path='/b' }
)
$byName = $rows | Convert-ToDictionary
$byName['alpha']  # returns the Alpha object (case-insensitive by default)

$json = ConvertTo-Json -InputObject $byName -Depth 20
$json = ConvertTo-Json -InputObject $byName -Depth 20
#>
