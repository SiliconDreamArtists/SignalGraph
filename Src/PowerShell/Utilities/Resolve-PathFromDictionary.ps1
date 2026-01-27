# ══════════════════════════════════════════════════════════════════════════════
# 📦 FUNCTION: Resolve-PathFromDictionary
# 🧠 Sovereign memory path resolver with symbolic and filtered access
# 🏷️ Slots: Memory | Lookup | Graph
# 🛠️ Authors: Shadow PhanTom 🤖/☠️🧁👾️ • Neural Alchemist ⚗️☣️🐲
# ══════════════════════════════════════════════════════════════════════════════

function Resolve-PathFromDictionary {
    param (
        [Parameter(Mandatory)] $Dictionary,
        [Parameter(Mandatory)] [string]$Path,
        [object]$Default,
        [string]$SignalLevel = "Critical",
        [string[]]$SignalTags = $null
    )

    $hasDefault = $PSBoundParameters.ContainsKey('Default')

    $opSignal = [Signal]::Start("Resolve-PathFromDictionary", $Dictionary) | Select-Object -Last 1

    # ░▒▓█ SYMBOL MAP █▓▒░
    $symbolMap = @{
        "%" = "Jacket"
        "*" = "Pointer"
        "@" = "Result"
        "$" = "Signal"
        "#" = "Grid"
        ":" = "Dimension"
        "&" = "Binding"
        "!" = "Polarity"
    }
        

    function Handle-NullWithDefault {
        param (
            [Parameter(Mandatory)]
            [Signal]$OperationSignal,

            [Parameter(Mandatory)]
            [bool]$HasDefault,

            $Default,

            [Parameter(Mandatory)]
            [string]$DefaultForNullMessage,

            [Parameter(Mandatory)]
            [string]$NullMessage,

            [string]$SignalLevel = "Critical",

            [string[]]$SignalTags = $null
        )

        if ($HasDefault) {
            $OperationSignal.SetResult($Default)
            $OperationSignal.LogInformation($DefaultForNullMessage, $SignalTags)
        }
        else {
            $OperationSignal.LogMessage($SignalLevel, $NullMessage, $SignalTags)
        }

        return $OperationSignal
    }

    function Expand-Symbols {
        param ([string[]]$segments)
        return $segments | ForEach-Object {
            if ($symbolMap.ContainsKey($_)) { $symbolMap[$_] } else { $_ }
        }
    }   

    try {
        $char = $Path -Contains '\:' ? '\:' : '\.'
        if ($char -eq '\:')
        {
            $char = $char
        }
        $rawSegments = $Path -split '\.'
        $segments = Expand-Symbols $rawSegments
        $current = $Dictionary

        $lastSegmentName = "" 
        foreach ($segment in $segments) {
            if ($null -eq $current) {
                return Handle-NullWithDefault -DefaultForNullMessage "Null encountered while traversing '$segment', applying default." -NullMessage "Null encountered while traversing '$segment'" -SignalLevel $SignalLevel -SignalTags $SignalTags  -HasDefault $hasDefault -Default $Default -OperationSignal $opSignal 
            }

            $processed = $false

            switch ($segment) {
                "Pointer" {
                    if ($current -is [Signal]) {
                        $current = $current.Pointer
                        $opSignal.LogVerbose("🔗 Dereferenced *Pointer")
                        $processed = $true
                    }
                    else {
                        $opSignal.LogWarning("⚠️ Expected Signal for *Pointer, got $($current.GetType().Name)", $SignalTags)
                    }
                }
                "Result" {
                    if ($current -is [Signal]) {
                        $current = $current.Result
                        $opSignal.LogVerbose("🎯 Dereferenced @Result")
                        $processed = $true
                    }
                    else {
                        $opSignal.LogWarning("⚠️ Expected Signal for @Result, got $($current.GetType().Name)", $SignalTags)
                    }
                }
                "Signal" {
                    # This segment is structural, let it use the below logic to determine how to return the Signal
                    #$processed = $true
                    continue
                }
                "Jacket" {
                    if ($current -is [Signal]) {
                        $current = $current.Jacket
                        $opSignal.LogVerbose("🧥 Accessed %Jacket")
                        $processed = $true
                    }
                    else {
                        $opSignal.LogWarning("⚠️ Expected Signal for %Jacket, got $($current.GetType().Name)", $SignalTags)
                    }
                }
                "Grid" {
                    if ($current -is [Graph]) {
                        $current = $current.Grid
                        $opSignal.LogVerbose("🧩 Accessed #Grid")
                        $processed = $true
                    }
                    else {
                        $opSignal.LogWarning("⚠️ Expected Graph for #Grid, got $($current.GetType().Name)", $SignalTags)
                    }
                }
            }

            if ($processed) {
                $lastSegmentName = $segment 
                continue
            }

            $parsed = Invoke-ParseFilterSegment $segment

            if ($parsed.IsFilter) {
                $arrayKey = $parsed.ArrayKey
                $array = $null
                if ($current -is [System.Collections.IDictionary] -and $current.ContainsKey($arrayKey)) {
                    $array = $current[$arrayKey]
                }
                elseif ($current -is [pscustomobject] -and $current.PSObject.Properties.Name -contains $arrayKey) {
                    $array = $current.$arrayKey
                }
                else {
                    $opSignal.LogCritical("❌ Array key '$arrayKey' not found.")
                    return $opSignal
                }

                $match = Resolve-FilteredArrayItem -Array $array -Filters $parsed.Filters -Signal $opSignal
                if ($null -eq $match) { 
                    return $opSignal 
                    
                }
                $current = $match
                continue
            }

            $key = $parsed.Raw

            if ($current -is [System.Collections.IDictionary] -and $current.Contains($key)) {
                $current = $current[$key]
            }
            elseif ($current -is [hashtable] -and $current.Contains($key)) {
                $current = $current[$key]
            }
            elseif ($current -is [pscustomobject] -and $current.PSObject.Properties.Name -contains $key) {
                $current = $current.$key
            }
            elseif ($current -is [System.Collections.IEnumerable] -and -not ($current -is [string])) {
                $found = $null
                # Todo: Review: Leaving this for reference, made change on 12-30-25 to not let it just convert it to an int since a string converts to a non-null int on the test.
                #                if ($key -is [int] -or ($null -ne $key -as [int])) {
                $inVal = $key -as [int]
                if ($segment -is [int] -or ($null -ne $inVal)) {
                    $index = [int]$segment
                    $list = @($current)  # Ensure it's indexable

                    if ($index -ge 0 -and $index -lt $list.Count) {
                        $current = $list[$index]
                    }
                    else {
                        $opSignal.LogMessage($SignalLevel, "Index '$index' out of bounds (0..$($list.Count - 1)).", $SignalTags)
                        return $opSignal
                    }
                }
                else {
                    # Determine selector property + value
                    $propertyName = 'Name'
                    $propertyValue = $key

                    if ($key -match '^(?<prop>[^=]+)=(?<val>.+)$') {
                        $propertyName = $matches['prop']
                        $propertyValue = $matches['val']
                    }

                    foreach ($item in $current) {
                        if ($null -eq $item) { continue }

                        # Allow selecting signals too (Name is common)
                        if ($item -is [Signal]) {
                            if ($propertyName -eq 'Name' -and $item.Name -eq $propertyValue) {
                                $found = $item
                                break
                            }
                            continue
                        }

                        $prop = $item.PSObject.Properties[$propertyName]
                        if ($null -ne $prop -and "$($prop.Value)" -eq $propertyValue) {
                            $found = $item
                            break
                        }
                    }
                    if ($found) {
                        $current = $found
                    }
                    else {
                        $message = if ($current -is [string]) {
                            $snippet = $current.Substring(0, [Math]::Min(40, $current.Length))
                            "❌ Unsupported traversal type: String ('$snippet') (lastSegmentName: $lastSegmentName)"
                        }
                        else {
                            $typeName = if ($null -eq $current) { '<null>' } else { $current.GetType().FullName }
                            "❌ Not Found sgment name in type: $typeName, lastSegmentName: $lastSegmentName"
                        }

                        return Handle-NullWithDefault -DefaultForNullMessage " $message, applying default." -NullMessage  $message -SignalLevel $SignalLevel -SignalTags $SignalTags  -HasDefault $hasDefault -Default $Default -OperationSignal $opSignal 
                    }
                }
            }
            elseif ($current -is [pscustomobject]) {
                $props = $current.PSObject.Properties.Name
                $match = $current.PSObject.Properties.Match($key)

                if (-not $match -or $null -eq ($value = $current.$key)) {
                    $message = "❌ Cannot access '$key' on 'PSCustomObject' (lastSegmentName: $lastSegmentName, available: $($props -join ', '))"
                    return Handle-NullWithDefault -DefaultForNullMessage " $message, applying default." -NullMessage  $message -SignalLevel $SignalLevel -SignalTags $SignalTags  -HasDefault $hasDefault -Default $Default -OperationSignal $opSignal 
                }

                $current = $value
            }
            elseif ($current.GetType().IsClass -and $current.GetType().Namespace -ne "System") {
                $type = $current.GetType()
                $prop = $type.GetProperty($key)
                $props = $type.GetProperties() | ForEach-Object Name

                if ($null -eq $prop -or $null -eq ($value = $prop.GetValue($current))) {
                    $message = "Cannot access '$key' on '$($type.Name)' (lastSegmentName: $lastSegmentName, available: $($props -join ', '))"
                    return Handle-NullWithDefault -DefaultForNullMessage " $message, applying default." -NullMessage  $message -SignalLevel $SignalLevel -SignalTags $SignalTags  -HasDefault $hasDefault -Default $Default -OperationSignal $opSignal 
                }

                $current = $value
            }
            else {
                $opSignal.LogMessage($SignalLevel, "Unsupported traversal type: $($current.GetType().FullName) (lastSegmentName: $lastSegmentName)", $SignalTags)
                return $opSignal
            }

            $lastSegmentName = $segment 
        }

        $opSignal.SetResult($current)
        $opSignal.LogInformation("✅ Successfully resolved path '$Path'")
    }
    catch {
        $opSignal.LogMessage($SignalLevel, "Exception during path resolution: $_  (lastSegmentName: $lastSegmentName)", $SignalTags)
    }

    return $opSignal
}
