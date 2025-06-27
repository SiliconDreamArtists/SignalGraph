function Resolve-GraphPlanInjectionContext {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)] [object]$Plan,
        [Parameter(Mandatory)] [object[]]$AllPlans,
        [Parameter(Mandatory)] [Signal]$Signal,
        [Parameter(Mandatory)] [object]$ParentItem,
        [Parameter(Mandatory)] [object]$Dynamic
    )

    $opSignal = [Signal]::Start("Resolve-GraphPlanInjectionContext", $Plan) | Select-Object -Last 1

    try {
        $context = @{
            SourceItem     = $null
            TargetSignal   = $null
            FullTargetPath = $null
            GraphPointer   = $null
        }

        # ░▒▓█ Optional: Resolve Source Item for traceability █▓▒░
        if ($Plan.SourceWirePath) {
            $sourceSig = Resolve-PathFromDictionary -Dictionary $Dynamic -Path $Plan.SourceWirePath | Select-Object -Last 1
            if ($opSignal.MergeSignalAndVerifyFailure($sourceSig)) {
                $opSignal.LogWarning("⚠️ Failed to resolve SourceWirePath: $($Plan.SourceWirePath)")
                return $opSignal
            }
            $context.SourceItem = $sourceSig.GetResult()
        }

        # ░▒▓█ Resolve dynamic target path or key-matched signal █▓▒░
        if ($Plan.TargetWirePath -and $Plan.TargetIdentifierWirePath) {
            $idSig = Resolve-PathFromDictionary -Dictionary $Dynamic -Path $Plan.TargetIdentifierWirePath | Select-Object -Last 1
            if ($opSignal.MergeSignalAndVerifyFailure($idSig)) {
                $opSignal.LogWarning("⚠️ Failed to resolve TargetIdentifierWirePath: $($Plan.TargetIdentifierWirePath)")
                return $opSignal
            }

            $lookupKey = $idSig.GetResult()
            $targetSig = Resolve-PathFromDictionary -Dictionary $ParentItem -Path "*.#.Agents.*.#.$lookupKey" | Select-Object -Last 1
            if ($opSignal.MergeSignalAndVerifyFailure($targetSig)) {
                $opSignal.LogWarning("⚠️ Failed to resolve target using key: $lookupKey")
                return $opSignal
            }

            $context.FullTargetPath = "*.#.$lookupKey"
            $context.TargetSignal   = $targetSig
        }

        # Return signal result with context dictionary as payload
        $opSignal.SetResult($context)
        $opSignal.LogInformation("✅ Injection context resolved for plan: $($Plan.Name)")
        return $opSignal
    }
    catch {
        $opSignal.LogCritical("🔥 Exception in Resolve-GraphPlanInjectionContext: $_")
        return $opSignal
    }
}
