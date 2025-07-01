function Invoke-FormulaGraphCondenser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Signal]$Signal
    )

    $opSignal = [Signal]::Start("Invoke-FormulaGraphCondenser", $Signal) | Select-Object -Last 1

    $plansSignal = Resolve-PathFromDictionary -Dictionary $Signal -Path "%.%.%.@.GraphPlans" | Select-Object -Last 1
    if ($opSignal.MergeSignalAndVerifyFailure($plansSignal)) {
        $opSignal.LogCritical("❌ No GraphPlans defined in Signal jacket.")
        return $opSignal
    }

    $plans = $plansSignal.GetResult()
    $planMap = @{}
    foreach ($plan in $plans) {
        $planMap[$plan.Name] = $plan
    }

    $executedPlans = @{}

    function Invoke-PlanAndDependents {
        param (
            [Signal]$Signal,
            [object]$Plan,
            [object]$Item,
            [object]$ParentPlan = $null
        )

        $planSignal = [Signal]::Start("GraphPlan:$($Plan.Name)", $Signal) | Select-Object -Last 1

        if ($executedPlans.ContainsKey($Plan.Name)) {
            return $planSignal
        }
        $executedPlans[$Plan.Name] = $true

        if ($Plan.ForEachIn) {
            $arraySignal = Resolve-PathFromDictionary -Dictionary $Item -Path "%.%.@.$($Plan.ForEachIn)" | Select-Object -Last 1
            if ($arraySignal.Failure()) {
                $arraySignal = Resolve-PathFromDictionary -Dictionary $Item -Path "%.@.$($Plan.ForEachIn)" | Select-Object -Last 1
            }

            if ($planSignal.MergeSignalAndVerifyFailure($arraySignal)) {
                $planSignal.LogWarning("⚠️ Could not resolve array path for ForEachIn: $($Plan.ForEachIn)")
                return $planSignal
            }

            foreach ($subItem in $arraySignal.GetResult()) {
                $injectionContextSignal = Resolve-GraphPlanInjectionContext -ParentPlan $ParentPlan -Plan $Plan -AllPlans $plans -Signal $Signal -ParentItem $Item -Dynamic $subItem | Select-Object -Last 1
                if ($planSignal.MergeSignalAndVerifyFailure($injectionContextSignal)) {
                    $planSignal.LogWarning("⚠️ Could not resolve injection context for item in $($Plan.Name)")
                    continue
                }

                $subItemSignal = [Signal]::Start("Item:$($subItem.Name):Wrapper", $Item) | Select-Object -Last 1
                $subItemSignal.SetResult($subItem) | Out-Null

                $graphPlanResult = Invoke-GraphPlanOnItem -ParentSignal $Signal -Plan $Plan -Item $subItemSignal -PlanName $Plan.Name -PlanWirePathPrefix "%.@" | Select-Object -Last 1
                if ($planSignal.MergeSignalAndVerifyFailure($graphPlanResult)) {
                    $planSignal.LogWarning("⚠️ Graph plan failed for item in $($Plan.Name)")
                    continue
                }

                $wrappedSignal = $graphPlanResult.GetResult()
                $injectionContext = $injectionContextSignal.GetResult()
                if ($injectionContext.FullTargetPath) {
                    $injectSignal = Add-PathToDictionary -Dictionary $Item -Path $injectionContext.FullTargetPath -Value $wrappedSignal | Select-Object -Last 1
                    if ($planSignal.MergeSignalAndVerifyFailure($injectSignal)) {
                        $planSignal.LogWarning("⚠️ Failed to inject graph result for plan: $($Plan.Name)")
                        continue
                    }
                    $planSignal.LogInformation("📍 Injected graph into '$($injectionContext.FullTargetPath)'")
                }

                $subItemJacketSignal = [Signal]::Start("Item:$($subItem.Name):Jacket", $Item) | Select-Object -Last 1
                $subItemJacketSignal.SetJacket($subItemSignal) | Out-Null

                foreach ($dependent in $plans | Where-Object { $_.DependsOn -eq $Plan.Name }) {
                    $dependentResult = Invoke-PlanAndDependents -Signal $Signal -Plan $dependent -Item $subItemJacketSignal -ParentPlan $Plan | Select-Object -Last 1
                    if ($planSignal.MergeSignalAndVerifyFailure($dependentResult)) {
                        $planSignal.LogWarning("⚠️ Dependent '$($dependent.Name)' failed for item in $($Plan.Name)")
                        continue
                    }
                }
            }
        }
        else {
            $wrappedSignal = Invoke-GraphPlanOnItem -ParentSignal $Signal -Plan $Plan -Item $Item -PlanName $Plan.Name | Select-Object -Last 1
            if (-not $wrappedSignal) { return $planSignal }

            foreach ($dependent in $plans | Where-Object { $_.DependsOn -eq $Plan.Name }) {
                Invoke-PlanAndDependents -Signal $Signal -Plan $dependent -Item $Item -ParentPlan $Plan | Out-Null
            }

            $planSignal.SetResult($wrappedSignal.GetPointer())
        }

        return $planSignal
    }

    $rootItem = $Signal.GetJacket()
    foreach ($plan in $plans) {
        if (-not $plan.DependsOn) {
            Invoke-PlanAndDependents -Signal $Signal -Plan $plan -Item $rootItem -ParentPlan $null | Out-Null
        }
    }

    $finalGraph = Resolve-PathFromDictionary -Dictionary $Signal -Path "%" | Select-Object -Last 1

    $opSignal.SetResult($finalGraph.GetResult())
    $opSignal.LogInformation("✅ Completed all declared GraphPlans.")
    return $opSignal
}
