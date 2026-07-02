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

    try {
        # Comma-delimited fallback path list:
        #   "Meta.Title,Identity.Title,Meta.Name,Identity.Name"
        $paths = $Path -split ','

        if ($null -eq $paths -or $paths.Count -eq 0) {
            if ($hasDefault) {
                $opSignal.SetResult($Default)
                $opSignal.LogInformation("No paths supplied. Applying default.", $SignalTags)
            }
            else {
                $opSignal.LogMessage($SignalLevel, "No paths supplied.", $SignalTags)
            }

            return $opSignal
        }

        # Sentinel is used as the inner default so failed inner lookups
        # do not become real results.
        $sentinel = [pscustomobject]@{
            __ResolveMultiPathSentinel = [guid]::NewGuid().ToString()
        }

        $attemptedPaths = @()

        if ($paths.Count -eq 1) {
            return Resolve-InnerPathFromDictionary -Dictionary $Dictionary -Path $Path -Default $Default -SignalLevel $SignalLevel -SignalTags $SignalTags
        }

        foreach ($candidatePath in $paths) {
            if ($null -eq $candidatePath) {
                continue
            }

            $candidatePath = $candidatePath.Trim()

            if ([string]::IsNullOrWhiteSpace($candidatePath)) {
                continue
            }

            $attemptedPaths += $candidatePath

            $candidateSignal = Resolve-InnerPathFromDictionary `
                -Dictionary $Dictionary `
                -Path $candidatePath `
                -Default $sentinel `
                -SignalLevel "Warning" `
                -SignalTags $SignalTags | Select-Object -Last 1

            if ($candidateSignal -is [Signal]) {
                # Merge entries from every inner attempt into the outer signal.
                $opSignal.MergeSignal(@($candidateSignal)) | Out-Null

                if ($candidateSignal.HasResult()) {
                    $candidateResult = $candidateSignal.GetResult()

                    # First non-sentinel, non-null result wins.
                    if ($null -ne $candidateResult -and
                        -not [object]::ReferenceEquals($candidateResult, $sentinel)) {

                        $opSignal.SetResult($candidateResult)
                        $opSignal.LogInformation("Resolved multi-path using '$candidatePath'.", $SignalTags)

                        return $opSignal
                    }
                }
            }
            else {
                $opSignal.LogWarning("Resolve-PathFromDictionary did not return a Signal for path '$candidatePath'.", $SignalTags)
            }
        }

        $message = if ($attemptedPaths.Count -gt 0) {
            "None of the supplied paths resolved: $($attemptedPaths -join ', ')"
        }
        else {
            "No usable paths were supplied."
        }

        if ($hasDefault) {
            $opSignal.SetResult($Default)
            $opSignal.LogInformation("$message Applying default.", $SignalTags)
        }
        else {
            $opSignal.LogMessage($SignalLevel, $message, $SignalTags)
        }
    }
    catch {
        $opSignal.LogMessage(
            $SignalLevel,
            "Exception during multi-path resolution: $_",
            $SignalTags,
            $_.Exception
        )
    }

    return $opSignal
}