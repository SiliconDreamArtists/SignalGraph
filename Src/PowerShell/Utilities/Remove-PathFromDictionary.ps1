# =============================================================================
# 🧹 FUNCTION: Remove-PathFromDictionary
#  Removes a key/property from a resolved parent object using symbolic pathing
#  License: MIT License • Copyright (c) 2025 Silicon Dream Artists / BDDB
#  Authors: Shadow PhanTom 🤖/☠️🧁👾️ • Neural Alchemist ⚗️☣️🐲 • Version: 2025.5.4.8
# =============================================================================

function Remove-PathFromDictionary {
    param (
        [Parameter(Mandatory)] $Dictionary,
        [Parameter(Mandatory)] [string]$Path
    )

    $opSignal = [Signal]::Start("Remove-PathFromDictionary", $Dictionary) | Select-Object -Last 1

    # ░▒▓█ EXPAND SYMBOLIC PATH SEGMENTS █▓▒░
    $symbolMap = @{
        "%" = "Jacket"; "*" = "Pointer"; "@" = "Result"; "$" = "Signal"; "#" = "Grid"
        ":" = "Dimension"; "&" = "Binding"; "!" = "Polarity"
    }
    $segments = ($Path -split '\.') | ForEach-Object {
        if ($symbolMap.ContainsKey($_)) { $symbolMap[$_] } else { $_ }
    }

    if ($segments.Count -lt 1) {
        $opSignal.LogCritical("Path must contain at least one segment.")
        return $opSignal
    }

    $targetKey = $segments[-1]
    $parentPath = if ($segments.Count -gt 1) { $segments[0..($segments.Count - 2)] -join '.' } else { '' }

    # ░▒▓█ RESOLVE PARENT OBJECT █▓▒░
    if ($parentPath) {

        $parentSignal = Resolve-PathFromDictionary -Dictionary $Dictionary -Path $parentPath | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($parentSignal)) {
            $opSignal.LogCritical("Failed to resolve parent at '$parentPath'")
            return $opSignal
        }

        $parent = $parentSignal.GetResult()
    }
    else {
        $parent = $Dictionary
        $targetKey = $Path
    }

    # ░▒▓█ PERFORM REMOVAL █▓▒░
    switch ($true) {
        { $parent -is [System.Collections.IDictionary] } {
            if ($parent.Contains($targetKey)) {
                $parent.Remove($targetKey)
                $opSignal.LogInformation("🗑️ Removed key '$targetKey' from dictionary.")
            }
            else {
                $opSignal.LogWarning("Key '$targetKey' not found in dictionary.")
            }
            break
        }
        { $parent -is [pscustomobject] -or $parent -is [System.Management.Automation.PSObject] } {
            if ($parent.PSObject.Properties[$targetKey]) {
                $parent.PSObject.Properties.Remove($targetKey)
                $opSignal.LogInformation("🗑️ Removed property '$targetKey' from PSCustomObject.")
            }
            else {
                $opSignal.LogWarning("Property '$targetKey' not found on PSCustomObject.")
            }
            break
        }
        { $parent.GetType().IsClass -and $parent.GetType().Namespace -ne "System" } {
            $prop = $parent.GetType().GetProperty($targetKey)
            if ($null -ne $prop -and $prop.CanWrite) {
                $prop.SetValue($parent, $null)
                $opSignal.LogInformation("🧼 Cleared property '$targetKey' on class '$($parent.GetType().Name)'.")
            }
            else {
                $opSignal.LogWarning("Property '$targetKey' not found or not writable.")
            }
            break
        }
        default {
            $opSignal.LogCritical("Unsupported parent type at '$targetKey': $($parent.GetType().FullName)")
            return $opSignal
        }
    }

    $opSignal.SetResult($Dictionary)
    return $opSignal
}
