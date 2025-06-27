# =============================================================================
# 🔁 Resolve-PathFormulaGraphForJsonArray (Declarative Signal Graph Builder)
#  License: MIT License • Copyright (c) 2025 Silicon Dream Artists / BDDB
#  Authors: Shadow PhanTom ☠️🧁👾️/🤖 • Neural Alchemist ⚗️☣️🐲 • Last Generated: 05/20/2025
# =============================================================================
# This function generates a sovereign Signal graph from a JSON array, using
# declarative wire path references embedded in a scoped Signal Jacket.
#
# It is designed to be called within a FormulaGraphCondenser flow, where each
# plan signal contains:
#   - A SourceWirePath: path to the array of objects to convert to signals
#   - A SourcesWirePath: key or path in each item that declares its linked nodes
#
# Each item becomes a Signal node with a `.Pointer` chain constructed from
# cross-references defined in the SourcesWirePath. The graph is returned as a
# result pointer in a finalized Grid structure.
#
# This function adheres to the SDA Doctrine of nested sovereign memory:
# - Inputs are read from `%.@.Plan.*`
# - Source data is accessed via `%.%`
# - Output is returned in `.Result`
#
# All memory is recursively encapsulated, sovereign, and lineage-safe.


function Resolve-PathFormulaGraphForJsonArray {
    param (
        [Parameter(Mandatory)]
        [Signal]$ConductionSignal
    )

    $opSignal = [Signal]::Start("Resolve-PathFormulaGraphForJsonArray", $ConductionSignal) | Select-Object -Last 1

    $plan = Resolve-PathFromDictionary -Dictionary $ConductionSignal -Path "%.%.%.@.Plan" | Select-Object -Last 1
    if ($plan.Failure()) {
        $plan = Resolve-PathFromDictionary -Dictionary $ConductionSignal -Path "%.@.Plan" | Select-Object -Last 1
    }

    $sourcePath = $plan.GetResult().SourceWirePath
    $sourcesKey = $plan.GetResult().SourcesWirePath
    $idPath = $plan.GetResult().SourcesIdentifierWirePath

    $arraySignal = Resolve-PathFromDictionary -Dictionary $ConductionSignal -Path "%.%.%.@.$sourcesKey" | Select-Object -Last 1
    if ($arraySignal.Failure()) {
        $arraySignal = Resolve-PathFromDictionary -Dictionary $ConductionSignal -Path "%.@.$sourcesKey" | Select-Object -Last 1
    }

    if ($opSignal.MergeSignalAndVerifyFailure($arraySignal)) {
        $opSignal.LogCritical("❌ Failed to resolve object array at SourceWirePath '$sourcePath'.")
        return $opSignal
    }

    $flatArray = $arraySignal.GetResult()
    $graphSignal = [Graph]::Start("Graph:$sourcesKey", $opSignal, $true) | Select-Object -Last 1
    $graph = $graphSignal.GetResult()

    $signalMap = @{}
    foreach ($item in $flatArray) {
        $id = $item.Name
        
        if ($idPath) {
             $idSignal = (Resolve-PathFromDictionary -Dictionary $item -Path $idPath) | Select-Object -Last 1
            if ($idSignal.Failure()) {
                $opSignal.LogCritical("❌ Failed to resolve identifier path '$idPath' for item: $($item.Name)")
                return $opSignal
            }

            $id = $idSignal.GetResult()
        }

$itemSignal = [Signal]::Start("Node:$($id):Jacket", $item)
$itemSignal.SetResult($item)

        $nodeSignal = [Signal]::Start("Node:$id", $item) | Select-Object -Last 1
        $nodeSignal.SetJacket($itemSignal)
        $signalMap[$id] = $nodeSignal
        $graph.RegisterSignal($id, $nodeSignal)
    }

    if ($sourcesKey) {
        foreach ($node in $signalMap.Values) {
            $jacket = $node.GetJacket()
            $sourceIds = (Resolve-PathFromDictionary -Dictionary $jacket -Path $sourcesKey | Select-Object -Last 1).GetResult()

            $linked = @()
            foreach ($srcId in $sourceIds) {
                if ($signalMap.ContainsKey($srcId)) {
                    $linked += $signalMap[$srcId]
                }
            }

            if ($linked.Count -eq 1) {
                $node.SetPointer($linked[0])
            } elseif ($linked.Count -gt 1) {
                $node.SetPointer($linked)
            }
        }
    }

    $graph.Finalize()
    $opSignal.SetResult($graph)
    $opSignal.LogInformation("✅ Signal graph constructed from JSON array.")
    return $opSignal
}
