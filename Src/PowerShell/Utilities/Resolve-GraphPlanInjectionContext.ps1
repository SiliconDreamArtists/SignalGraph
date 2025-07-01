function Resolve-GraphPlanInjectionContext {
    [CmdletBinding()]
    param (
        [object]$ParentPlan,
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

        # ░▒▓█ Resolve target using identifier and ParentPlan for composed path █▓▒░
        if ($Plan.TargetWirePath -and $Plan.TargetIdentifierWirePath) {
            $idSig = Resolve-PathFromDictionary -Dictionary $Dynamic -Path $Plan.TargetIdentifierWirePath | Select-Object -Last 1
            if ($opSignal.MergeSignalAndVerifyFailure($idSig)) {
                $opSignal.LogWarning("⚠️ Failed to resolve TargetIdentifierWirePath: $($Plan.TargetIdentifierWirePath)")
                return $opSignal
            }

            $lookupKey = $idSig.GetResult()

            # Build composed path if ParentPlan exists
            $parentPath = $null            
            if ($null -ne $ParentPlan)
            {
                $parentPath = $ParentPlan.TargetWirePath
            }

            $basePath = if ($parentPath) {
                "$parentPath.*.#.$lookupKey"
            } else {
                "*.#.$lookupKey"
            }

            $targetSig = Resolve-PathFromDictionary -Dictionary $ParentItem -Path "$basePath" | Select-Object -Last 1
            if ($targetSig.Failure()) {
                $targetSig = Resolve-PathFromDictionary -Dictionary $ParentItem -Path "%.$basePath" | Select-Object -Last 1
            }
            
            if ($opSignal.MergeSignalAndVerifyFailure($targetSig)) {
                $opSignal.LogWarning("⚠️ Failed to resolve target signal at path: $basePath")
                return $opSignal
            }

            # Compose final target path for injecting child graph
            $finalPath = if ($Plan.TargetWirePath) {
                "$basePath.$($Plan.TargetWirePath)"
            } else {
                $basePath
            }

            $context.TargetSignal   = $targetSig
            $context.FullTargetPath = $finalPath
        }

        $opSignal.SetResult($context)
        $opSignal.LogInformation("✅ Injection context resolved for plan: $($Plan.Name)")
        return $opSignal
    }
    catch {
        $opSignal.LogCritical("🔥 Exception in Resolve-GraphPlanInjectionContext: $_")
        return $opSignal
    }
}
