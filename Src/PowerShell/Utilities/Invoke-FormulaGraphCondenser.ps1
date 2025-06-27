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
            [object]$Item
        )

        if ($executedPlans.ContainsKey($Plan.Name)) {
            return
        }

        $executedPlans[$Plan.Name] = $true
        $planName = $Plan.Name

        if ($Plan.ForEachIn) {
            $arraySignal = Resolve-PathFromDictionary -Dictionary $Item -Path "%.%.@.$($Plan.ForEachIn)" | Select-Object -Last 1
            if ($opSignal.MergeSignalAndVerifyFailure($arraySignal)) {
                $opSignal.LogWarning("⚠️ Could not resolve array path for ForEachIn: $($Plan.ForEachIn)")
                return
            }

            foreach ($subItem in $arraySignal.GetResult()) {
                $injectionContext = Resolve-GraphPlanInjectionContext -Plan $Plan -AllPlans $plans -Signal $Signal -ParentItem $Item -Dynamic $subItem | Select-Object -Last 1
                if ($opSignal.MergeSignalAndVerifyFailure($injectionContext)) {
                    $opSignal.LogWarning("⚠️ Could not resolve injection context for item in $($Plan.Name)")
                    continue
                }

                $subItemSignal = [Signal]::Start("Item:$($subItem.Name):Jacket", $Item) | Select-Object -Last 1
                $subItemSignal.SetResult($subItem) | Out-Null

                $graphPlanResult = Invoke-GraphPlanOnItem -ParentSignal $Signal -Plan $Plan -Item $subItemSignal -PlanName $Plan.Name -PlanWirePathPrefix "%.@" | Select-Object -Last 1
                if ($opSignal.MergeSignalAndVerifyFailure($graphPlanResult)) {
                    $opSignal.LogWarning("⚠️ Graph plan failed for item in $($Plan.Name)")
                    continue
                }

                $wrappedSignal = $graphPlanResult.GetResult()

                if ($injectionContext.FullTargetPath) {
                    $injectSignal = Add-PathToDictionary -Dictionary $Signal -Path $injectionContext.FullTargetPath -Value $wrappedSignal | Select-Object -Last 1
                    if ($opSignal.MergeSignalAndVerifyFailure($injectSignal)) {
                        $opSignal.LogWarning("⚠️ Failed to inject graph result for plan: $($Plan.Name)")
                        continue
                    }
                    $opSignal.LogInformation("📍 Injected graph into '$($injectionContext.FullTargetPath)'")
                }

                foreach ($dependent in $plans | Where-Object { $_.DependsOn -eq $Plan.Name }) {
                    Invoke-PlanAndDependents -Signal $Signal -Plan $dependent -Item $subItem
                }
            }
        }
        else {
            $wrappedSignal = Invoke-GraphPlanOnItem -ParentSignal $Signal -Plan $Plan -Item $Item -PlanName $planName | Select-Object -Last 1
            if (-not $wrappedSignal) { return }

            foreach ($dependent in $plans | Where-Object { $_.DependsOn -eq $Plan.Name }) {
                Invoke-PlanAndDependents -Signal $Signal -Plan $dependent -Item $Item
            }

            $opSignal.SetResult($wrappedSignal.GetPointer())
        }
    }

    $rootItem = $Signal.GetJacket()
    foreach ($plan in $plans) {
        if (-not $plan.DependsOn) {
            Invoke-PlanAndDependents -Signal $Signal -Plan $plan -Item $rootItem
        }
    }

    $opSignal.LogInformation("✅ Completed all declared GraphPlans.")
    return $opSignal
}
