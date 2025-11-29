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
        [string]$FailureLogLevel = "Critical"
    )

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
        
    function Expand-Symbols {
        param ([string[]]$segments)
        return $segments | ForEach-Object {
            if ($symbolMap.ContainsKey($_)) { $symbolMap[$_] } else { $_ }
        }
    }   

    try {
        $rawSegments = $Path -split '\.'
        $segments = Expand-Symbols $rawSegments
        $current = $Dictionary

        foreach ($segment in $segments) {
            if ($null -eq $current) {
                $opSignal.LogMessage($FailureLogLevel, "❌ Null encountered while traversing '$segment'")
                return $opSignal    
            }

            $processed = $false

            switch ($segment) {
                "Pointer" {
                    if ($current -is [Signal]) {
                        $current = $current.Pointer
                        $opSignal.LogVerbose("🔗 Dereferenced *Pointer")
                        $processed = $true
                        continue
                    }
                    else {
                        $opSignal.LogWarning("❌ Expected Signal for *Pointer, got $($current.GetType().Name)")
                    }
                }
                "Result" {
                    if ($current -is [Signal]) {
                        $current = $current.Result
                        $opSignal.LogVerbose("🎯 Dereferenced @Result")
                        $processed = $true
                        continue
                    }
                    else {
                        $opSignal.LogWarning("❌ Expected Signal for @Result, got $($current.GetType().Name)")
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
                        continue
                    }
                    else {
                        $opSignal.LogWarning("❌ Expected Signal for %Jacket, got $($current.GetType().Name)")
                    }
                }
                "Grid" {
                    if ($current -is [Graph]) {
                        $current = $current.Grid
                        $opSignal.LogVerbose("🧩 Accessed #Grid")
                        $processed = $true
                        continue
                    }
                    else {
                        $opSignal.LogWarning("❌ Expected Graph for #Grid, got $($current.GetType().Name)")
                    }
                }
            }

            if ($processed) {
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
                if ($null -eq $match) { return $opSignal }
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

                if ($key -is [int] -or ($key -as [int] -ne $null)) {
                    $index = [int]$key
                    $list = @($current)  # Ensure it's indexable

                    if ($index -ge 0 -and $index -lt $list.Count) {
                        $current = $list[$index]
                    }
                    else {
                        $opSignal.LogMessage($FailureLogLevel, "❌ Index '$index' out of bounds (0..$($list.Count - 1)).")
                        return $opSignal
                    }
                }
                else {
                    foreach ($item in $current) {
                        if (($item -is [pscustomobject] -or $item -is [hashtable]) -and ($item.Name -eq $key)) {
                            $found = $item
                            break
                        }
                        elseif (($item -is [signal]) -and ($item.Name -eq $key)) {
                            $found = $item
                            break
                        }
                    }
                    if ($found) {
                        $current = $found
                    }
                    else {
                        $opSignal.LogMessage($FailureLogLevel, "❌ Could not find item by name '$key' in collection.")
                        return $opSignal
                    }
                }
            }
            elseif ($current.GetType().IsClass -and $current.GetType().Namespace -ne "System") {
                $prop = $current.GetType().GetProperty($key)
                if ($null -eq $prop) {
                    $opSignal.LogMessage($FailureLogLevel, "❌ Property '$key' not found on '$($current.GetType().Name)'")
                    return $opSignal
                }
                $current = $prop.GetValue($current)
            }
            else {
                $opSignal.LogMessage($FailureLogLevel, "❌ Unsupported traversal type: $($current.GetType().FullName)")
                return $opSignal
            }
        }

        $opSignal.SetResult($current)
        $opSignal.LogInformation("✅ Successfully resolved path '$Path'")
    }
    catch {
        $opSignal.LogCritical("🔥 Exception during path resolution: $_")
    }

    return $opSignal
}
