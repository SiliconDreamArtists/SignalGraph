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

    # ░▒▓█ RESOLVE SOURCE CONFIG PATHS █▓▒░
    $sourcePathSignal = Resolve-PathFromDictionary -Dictionary $ConductionSignal -Path "%.@.Plan.SourceWirePath" | Select-Object -Last 1
    $sourcesKeySignal = Resolve-PathFromDictionary -Dictionary $ConductionSignal -Path "%.@.Plan.SourcesWirePath" | Select-Object -Last 1
    $opSignal.MergeSignal(@($sourcePathSignal, $sourcesKeySignal)) | Out-Null

    if ($opSignal.MergeSignalAndVerifyFailure(@($sourcePathSignal, $sourcesKeySignal))) {
        $opSignal.LogCritical("❌ Missing SourceWirePath or SourcesWirePath in Jacket.")
        return $opSignal
    }

    $sourcePath = $sourcePathSignal.GetResult()
    $sourcesKey = $sourcesKeySignal.GetResult()

    # ░▒▓█ GET ROOT ARRAY FROM CONDUCTION SIGNAL RESULT █▓▒░
    $arraySignal = Resolve-PathFromDictionary -Dictionary $ConductionSignal -Path "%.%.@.$($sourcePath)" | Select-Object -Last 1
    $opSignal.MergeSignal(@($arraySignal)) | Out-Null

    if ($opSignal.MergeSignalAndVerifyFailure($arraySignal)) {
        $opSignal.LogCritical("❌ Failed to resolve object array at SourceWirePath '$sourcePath'.")
        return $opSignal
    }

    $flatArray = $arraySignal.GetResult()

    # ░▒▓█ CREATE GRAPH SIGNAL MESH █▓▒░
    $graphSignal = [Graph]::Start("GSG:ResolvedGraph", $opSignal, $true) | Select-Object -Last 1
    $graph = $graphSignal.Pointer
    $opSignal.MergeSignal($graphSignal) | Out-Null

    # ░▒▓█ BUILD SIGNALS AND REGISTER TO GRAPH █▓▒░
    $signalMap = @{}
    foreach ($item in $flatArray) {
        $id = $item.Identifier
        $signalMap[$id] = [Signal]::Start("Node:$id", $opSignal) | Select-Object -Last 1
        $signalMap[$id].SetJacket($item)
    }

    foreach ($signal in $signalMap.Values) {
        $jacket = $signal.GetJacket()
        $sources = @()

        if ($jacket.ContainsKey($sourcesKey)) {
            foreach ($srcId in $jacket[$sourcesKey]) {
                if ($signalMap.ContainsKey($srcId)) {
                    $sources += $signalMap[$srcId]
                } else {
                    $opSignal.LogWarning("⚠️ Source ID '$srcId' not found in signal map.")
                }
            }
        }

        if ($sources.Count -eq 1) {
            $signal.SetPointer($sources[0])
        } elseif ($sources.Count -gt 1) {
            $signal.SetPointer($sources)
        }

        $graph.RegisterSignal($signal.Name, $signal) | Out-Null
    }

    $graph.Finalize()
    $opSignal.SetResult($graph)
    $opSignal.LogInformation("✅ Signal graph constructed from JSON array.")
    return $opSignal
}
