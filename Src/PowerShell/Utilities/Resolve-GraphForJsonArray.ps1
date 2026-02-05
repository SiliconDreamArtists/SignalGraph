# =============================================================================
# 🔁 Resolve-PathGraphForJsonArray (Declarative Signal Graph Builder)
#  License: MIT License • Copyright (c) 2025 Silicon Dream Artists / BDDB
#  Authors: Shadow PhanTom ☠️🧁👾️/🤖 • Neural Alchemist ⚗️☣️🐲 • Last Generated: 05/20/2025
# =============================================================================
# This function generates a sovereign Signal graph from a JSON array, using
# declarative wire path references embedded in a scoped Signal Jacket.
#
# It is designed to be called within a GraphCondenser flow, where each
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


function Resolve-GraphForJsonArray {
    param (
        [Parameter(Mandatory)]
        [Signal]$ConductionSignal,

        [Parameter(Mandatory)]
        [object]$Plan,

        [string]$SourcePath = "%.@",

        [string]$GraphName,

        [Parameter(Mandatory)]
        [Signal]$ItemSignal
        )

    $opSignal = [Signal]::Start("Resolve-PathGraphForJsonArray", $ConductionSignal) | Select-Object -Last 1

    # Pull plan fields
 
    # Resolve the array at the computed path
    $arraySignal = Resolve-PathFromDictionary -Dictionary $ItemSignal -Path $SourcePath | Select-Object -Last 1
    if ($opSignal.MergeSignalAndVerifyFailure(@($arraySignal))) {
        $opSignal.LogCritical("Failed to resolve object array via SourcesWirePathTemplate. For SourcesWirePath='$sourcesKey' → '$path'")
        return $opSignal
    }

    $flatArray = $arraySignal.GetResult()

    # Build a graph and map items by identifier
    $graphSignal = [Graph]::Start("Graph:$GraphName", $opSignal, $true) | Select-Object -Last 1
    $graph = $graphSignal.GetResult()

    $NamePathSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "NamePath" -Default "Name" | Select-Object -Last 1
    $NamePath = $NamePathSignal.GetResult()

    foreach ($item in $flatArray) {
        if ($NamePath) {
            $idSignal = Resolve-PathFromDictionary -Dictionary $item -Path $NamePath | Select-Object -Last 1
            if ($opSignal.MergeSignalAndVerifyFailure(@($idSignal))) {
                $opSignal.LogCritical("Failed to resolve identifier path '$idPath' for item: $($item.Name)")
                return $opSignal
            }

            $id = $idSignal.GetResult()
        }

        $jacketSig = [Signal]::Start("Node:$($id):Signal", $item)
        $jacketSig.SetResult($item)
#        $graph.RegisterSignal($id, $jacketSig) | Out-Null

#        #The other version of this places the result in a jacket, to start, I'm going to do it with just using the result
        $nodeSignal = [Signal]::Start("Node:$id", $item) | Select-Object -Last 1
        $nodeSignal.SetJacket($jacketSig)
        $graph.RegisterSignal($id, $nodeSignal) | Out-Null
    }

    $graph.Finalize()
    $opSignal.SetResult($graph)
    $opSignal.LogInformation("✅ Signal graph constructed from JSON array.")
    return $opSignal
}
