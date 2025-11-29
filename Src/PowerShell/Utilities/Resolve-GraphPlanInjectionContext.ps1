function Resolve-GraphPlanInjectionContext{
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

        if ($Plan.CondenserType -eq "Fab") {
            $opSignal.LogInformation("🔄 Executing Token Condenser for plan: $($Plan.Name)")
        }

        if ($Plan.Name -eq "AdapterGraphPerRole") {
            $opSignal.LogInformation("🔄 Executing Token Condenser for plan: $($Plan.Name)")
        }

        # ░▒▓█ Optional: Resolve Source Item for traceability █▓▒░
        if ($Plan.SourceWirePath) {
            # Normalize template (default to '{0}')
            $tpl = $Plan.SourceWirePathTemplate
            $tpl = if ([string]::IsNullOrWhiteSpace($tpl)) { '{0}' } else { $tpl }
            $isDefault = ($tpl -eq '{0}')

            # Enforce token presence
            if ($tpl -notmatch '\{0\}') {
                $opSignal.LogCritical("❌ SourceWirePathTemplate must contain '{0}'. Template: '$tpl'")
                return $opSignal
            }

            # Build concrete path from template
            $path = [string]::Format($tpl, $Plan.SourceWirePath)

            # Resolve the source item
            $sourceSig = Resolve-PathFromDictionary -Dictionary $Dynamic -Path $path | Select-Object -Last 1
            if ($opSignal.MergeSignalAndVerifyFailure(@($sourceSig))) {
                $opSignal.LogWarning("⚠️ Failed to resolve SourceWirePath via template. For SourceWirePath='$($Plan.SourceWirePath)' → '$path'")
                return $opSignal
            }

            $context.SourceItem = $sourceSig.GetResult()

            if ($isDefault) {
                $opSignal.LogInformation("✅ Source resolved: '$path'")
            }
            else {
                $opSignal.LogInformation("✅ Source resolved: '$path' (template: '$tpl')")
            }
        }
        else {
            $context.SourceItem = $Dynamic
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
            if ($null -ne $ParentPlan) {
                $parentPath = $ParentPlan.TargetWirePath
            }

            $basePath = if ($parentPath) {
                "$parentPath.*.#.$lookupKey"
            }
            else {
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
            }
            else {
                $basePath
            }

            $context.TargetSignal = $targetSig
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
