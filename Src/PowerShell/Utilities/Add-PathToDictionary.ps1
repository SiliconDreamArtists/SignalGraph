function Add-PathToDictionary {
    param (
        $Dictionary,
        [Parameter(Mandatory)] [string]$Path,
        [Parameter()] $Value
    )

    $opSignal = [Signal]::Start("Add-PathToDictionary", $Dictionary) | Select-Object -Last 1

    $symbolMap = @{
        "%" = "Jacket"
        "*" = "Pointer"
        "!" = "ReversePointer"
        "@" = "Result"
        "$" = "Signal"
        "#" = "Grid"
    }

    function Expand-Symbols {
        param ([Parameter(Mandatory)][string[]]$segments)

        if ($segments -isnot [System.Array]) {
            $segments = @($segments)
        }

        return $segments | ForEach-Object {
            if ($symbolMap.ContainsKey($_)) { $symbolMap[$_] } else { $_ }
        }
    }

    function Expand-SymbolsF {
        param ([Parameter(Mandatory)][string[]]$segments)

        return @($segments) | ForEach-Object {
            if ($symbolMap.ContainsKey($_)) { $symbolMap[$_] } else { $_ }
        }
    }

    function Update-ContextFromSegment {
        param (
            [object]$CurrentContext,
            [string]$Key
        )

        switch ($Key) {
            "Signal" { return $CurrentContext }
            #"Pointer" { return "Pointer" }
            "Grid" { return $CurrentContext }
            #"Result" { return "Result" }
            #"Jacket" { return "Jacket" }
            default { return $CurrentContext }
        }
    }

    try {
        $rawSegments = $Path -split '\.'
        $segments = Expand-Symbols -segments $rawSegments
        $currentContext = $null

        if ($segments.Count -lt 1) {
            $opSignal.LogCritical("❌ Path too short or empty.")
            return $opSignal
        }

        $current = $Dictionary
        $segments = @($segments) 

        for ($i = 0; $i -lt $segments.Count; $i++) {
            $key = $segments[$i]

            $currentContext = Update-ContextFromSegment -CurrentContext $currentContext -Key $key
            $isFinal = ($i -eq $segments.Count - 1)

            if ($null -eq $current) {
                $opSignal.LogCritical("❌ Null encountered at segment '$key'")
                return $opSignal
            }

            # Auto-unwrap Signal/Graph
            #if ($current -is [Signal]) { $current = $current.GetResult() }
            #if ($current -is [Graph])  { $current = $current.Grid }

            $processed = $false

            # ░▒▓█ SYMBOLIC STRUCTURE STEPS █▓▒░
            switch ($key) {
                "Jacket" {
                    if ($current -is [Signal]) {
                        $current = $current.GetJacket()
                        $processed = $true
                        continue
                    }
                    else {
                        $opSignal.LogCritical("❌ 'Jacket' expected Signal, got $($current.GetType().Name)")
                        return $opSignal
                    }
                }
                "Pointer" {
                    if ($current -is [Signal]) {
                        if (-not $current.Pointer) {
                            $current.SetPointer(([Graph]::Start("AutoCreated", $current, $true) | select-Object -Last 1).GetResult())
                        }
                        $current = $current.GetPointer()
                        $currentContext = $current
                        $processed = $true
                        continue
                    }
                    else {
                        $opSignal.LogCritical("❌ 'Pointer' expected Signal, got $($current.GetType().Name)")
                        return $opSignal
                    }
                }
                "Result" {
                    if ($current -is [Signal]) {
                        if ($isFinal) {
                            $current.SetResult($Value)
                            $opSignal.LogInformation("📥 Wrote '$key' → $($Value.GetType().Name)")
                        }
                        else {
                            if (-not $current.HasResult()) {
                                $current.SetResult(@{})
                            }
                            $current = $current.GetResult()
                        }

                        $processed = $true
                        continue
                    }
                    elseif ($current -is [Graph]) {
                        if (-not $current.Grid) {
                            $current.Grid = [Signal]::Start("AutoCreated")
                        }
                        $current = $current.Grid
                        $processed = $true
                        continue
                    }
                    else {
                        $opSignal.LogCritical("❌ 'Result' segment unsupported on $($current.GetType().Name)")
                        return $opSignal
                    }
                }
                "Grid" {
                    if ($current -is [Graph]) {
                        if (-not $current.Grid) {
                            $current.Grid = @{}
                        }
                        $current = $current.Grid
                        $processed = $true
                        continue
                    }
                    else {
                        #$graph = [Graph]::Start("AutoCreated")
                        $current.SetPointer(([Graph]::Start("AutoCreated", $current, $true) | select-Object -Last 1).GetResult())
                        $current = $current.GetPointer()
                        <#
                        if ($current -is [System.Collections.IDictionary]) {
                            $current["Grid"] = $graph.Grid
                            $current = $graph.Grid
                            continue
                        }
                        else {
                            $opSignal.LogCritical("❌ 'Grid' requires Graph or dictionary host.")
                            return $opSignal
                        }
                        #>
                    }
                }
                "Signal" {
                    if ($current -is [System.Collections.IDictionary]) {
                        if (-not $current.Contains("Signal")) {
                            $current["Signal"] = [Signal]::Start("AutoCreated")
                        }
                        $current = $current["Signal"]
                        $processed = $true
                        continue
                    }
                    else {
                        $opSignal.LogCritical("❌ 'Signal' key requires dictionary host.")
                        return $opSignal
                    }
                }
            }

            if ($processed) {
                continue
            }

            # ░▒▓█ FINAL WRITE █▓▒░
            if ($isFinal) {
                if ($currentContext -is [Graph]) {
                    if ($Value -is [Signal]) {
                        $currentContext.RegisterSignal($key, $Value)
                    }
                    else {
                        $currentContext.RegisterResultAsSignal($key, $Value)
                    }

                    $processed = $true
                }
                elseif ($current -is [System.Collections.IDictionary]) {
                    $current[$key] = $Value
                }
                elseif ($current -is [System.Object[]]) {
                    $current[$key] = $Value
                }
                elseif ($current -is [PSCustomObject] -or $current -is [System.Management.Automation.PSObject]) {
                    if (-not $current.PSObject.Properties[$key]) {
                        Add-Member -InputObject $current -MemberType NoteProperty -Name $key -Value $Value
                    }
                    else {
                        $current.$key = $Value
                    }
                }
                elseif ($current.GetType().IsClass -and $current.GetType().Namespace -ne "System") {
                    $prop = $current.GetType().GetProperty($key)
                    if ($null -eq $prop -or -not $prop.CanWrite) {
                        $opSignal.LogCritical("❌ Cannot write '$key' on class '$($current.GetType().Name)'")
                        return $opSignal
                    }
                    $prop.SetValue($current, $Value)
                }
                elseif ($current -is [System.Object[]]) {
                    $current[$key] = $Value
                }
                else {
                    $opSignal.LogCritical("❌ Unsupported type at final write: $($current.GetType().FullName)")
                    return $opSignal
                }

                $opSignal.LogInformation("📥 Wrote '$key' → $($Value.GetType().Name)")
                $opSignal.SetResult($Dictionary)
                return $opSignal
            }

            if ($processed) {
                continue
            }

            # ░▒▓█ INTERMEDIATE OBJECTS █▓▒░
            if ($current -is [System.Collections.IDictionary]) {
                #    if (-not $current.Contains($key)) {

                if ($currentContext -is [Graph]) {
                    # ░▒▓█ GRAPH CONTEXT → LOOKUP OR REGISTER SOVEREIGN SIGNAL █▓▒░
                    $grid = $currentContext.Grid

                    if ($grid.Contains($key) -and $grid[$key] -is [Signal]) {
                        $current = $grid[$key]
                    }
                    else {
                        $newSignal = [Signal]::Start($key)
                        $currentContext.RegisterSignal($key, $newSignal)
                        $current = $newSignal
                    }
                }
                else {
                    # ░▒▓█ GENERIC DICTIONARY █▓▒░
                    if (-not $current.Contains($key)) {
                        $current[$key] = @{}
                    }

                    $current = $current[$key]
                }
                #
                #    } else {
                #        $current = $current[$key]
                #    }
            }
            elseif ($current -is [PSCustomObject] -or $current -is [System.Management.Automation.PSObject]) {
                if (-not $current.PSObject.Properties[$key]) {
                    try {   
                        Add-Member -InputObject $current -MemberType NoteProperty -Name $key -Value (@{})                        
                    }
                    catch {
                        $opSignal.LogCritical("Exception adding member '$key': $_")
                        return $opSignal
                    }
                }
                $current = $current.$key
            }
            elseif ($current.GetType().IsClass -and $current.GetType().Namespace -ne "System") {
                $prop = $current.GetType().GetProperty($key)
                if ($null -eq $prop) {
                    $opSignal.LogCritical("❌ Class '$($current.GetType().Name)' missing property '$key'")
                    return $opSignal
                }
                $next = $prop.GetValue($current)
                if ($null -eq $next) {
                    $next = New-Object -TypeName $prop.PropertyType
                    $prop.SetValue($current, $next)
                }
                $current = $next
            }

            # ░▒▓█ ARRAY NAME SELECTOR (NON-NUMERIC) █▓▒░
            # Navigate into an array by selecting an element with .Name == $key.
            # Does NOT create/append. If missing, caller should append separately.
            elseif (($current -is [System.Collections.IEnumerable]) -and -not ($current -is [string]) -and ($key -notmatch '^\d+$')) {
                $match = $null

                # Determine selector property + value
                $propertyName = 'Name'
                $propertyValue = $key

                if ($key -match '^(?<prop>[^=]+)=(?<val>.+)$') {
                    $propertyName = $matches['prop']
                    $propertyValue = $matches['val']
                }

                foreach ($item in $current) {
                    if ($null -eq $item) { continue }

                    $prop = $item.PSObject.Properties[$propertyName]
                    if ($null -ne $prop -and "$($prop.Value)" -eq $propertyValue) {
                        $match = $item
                        break
                    }
                }

                if ($null -eq $match) {
                    $opSignal.LogCritical(
                        "❌ Array navigation failed: no element with $propertyName='$propertyValue' found. Append the object to the array in a separate step, then retry path navigation."
                    )
                    return $opSignal
                }

                $current = $match
                continue
            }

            else {
                $opSignal.LogCritical("❌ Unsupported type at '$key': $($current.GetType().FullName)")
                return $opSignal
            }
        }
    }
    catch {
        $opSignal.LogCritical("❌ Exception during Add-PathToDictionary: $_")
        return $opSignal
    }

    return $opSignal
}
