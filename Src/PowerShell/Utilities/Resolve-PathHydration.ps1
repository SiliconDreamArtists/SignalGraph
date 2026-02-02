function Resolve-PathHydration {
    param (
        [Parameter(Mandatory)] [string]$CompactPath,
        [bool]$SignalFirst = $true
    )

    $opSignal = [Signal]::Start("Resolve-PathHydration") | Select-Object -Last 1

    try {
        $segments = $CompactPath -split '\.'

        if ($segments.Count -lt 1) {
            $opSignal.LogWarning("⚠️ CompactPath was empty or invalid.")
            $opSignal.SetResult("")
            return $opSignal
        }

        $symbolicPath = if ($SignalFirst) { '$.*.#' } else { '' }

        # All but the last two segments get .*.# traversal
        for ($i = 0; $i -lt $segments.Count - 2; $i++) {
            if ($symbolicPath -ne "") { $symbolicPath += "." }
            $symbolicPath += "$($segments[$i]).*.#"
        }

        # Penultimate segment assumed to be a signal
        if ($segments.Count -ge 2) {
            if ($symbolicPath -ne "") { $symbolicPath += "." }
            $symbolicPath += $segments[-2]
        }

        # Final segment (unwrap into result → signal → pointer → grid → target)
        $lastSegment = $segments[-1]
        $symbolicPath += ".@.$.*.#.$lastSegment"

        $opSignal.SetResult($symbolicPath)
        $opSignal.LogInformation("✅ Resolved hydration path: '$symbolicPath'")
    }
    catch {
        $opSignal.LogCritical("❌ Exception during Resolve-PathHydration: $_", $null, $_)
        $opSignal.SetResult("")
    }

    return $opSignal
}


Resolve-PathHydration -CompactPath "Adapters.MappedCondenser.GraphCondenser"