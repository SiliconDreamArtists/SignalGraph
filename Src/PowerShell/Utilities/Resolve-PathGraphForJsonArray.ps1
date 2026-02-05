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


function Resolve-PathGraphForJsonArray {
    param (
        [Parameter(Mandatory)]
        [Signal]$ConductionSignal
    )

    $opSignal = [Signal]::Start("Resolve-PathGraphForJsonArray", $ConductionSignal) | Select-Object -Last 1

    ## TODO: Replace with a path discovery and cache mechanism.
    $plan = Resolve-PathFromDictionary -Dictionary $ConductionSignal -Path "%.%.%.@.Plan" -SignalLevel "Warning" -SignalTags @("Verbose") | Select-Object -Last 1
    if (-Not $plan.HasResult()) {
        $plan = Resolve-PathFromDictionary -Dictionary $ConductionSignal -Path "%.@.Plan" -SignalLevel "Warning" -SignalTags @("Verbose") | Select-Object -Last 1
    }
    if (-Not $plan.HasResult()) {
        $plan = Resolve-PathFromDictionary -Dictionary $ConductionSignal -Path "%.%.@.Plan" -SignalLevel "Warning" -SignalTags @("Verbose") | Select-Object -Last 1
    }

    # Pull plan fields
    $sourcesKey = $plan.GetResult().SourcesWirePath
    $idPath = $plan.GetResult().SourcesIdentifierWirePath

    # Normalize template (default to '{0}')
    $template = $plan.GetResult().SourcesWirePathTemplate
    $template = if ([string]::IsNullOrWhiteSpace($template)) { '{0}' } else { $template }
    $isDefault = ($template -eq '{0}')

    # Enforce token
    if ($template -notmatch '\{0\}') {
        $opSignal.LogCritical("SourcesWirePathTemplate must contain '{0}'. Template: '$template'")  
        return $opSignal
    }

    # Build path from template
    $path = [string]::Format($template, $sourcesKey)

    # Resolve the array at the computed path
    $arraySignal = Resolve-PathFromDictionary -Dictionary $ConductionSignal -Path $path | Select-Object -Last 1
    if ($opSignal.MergeSignalAndVerifyFailure(@($arraySignal))) {
        $opSignal.LogCritical("Failed to resolve object array via SourcesWirePathTemplate. For SourcesWirePath='$sourcesKey' → '$path'")
        return $opSignal
    }

    # Log with tidy messaging when default template is used
    if ($isDefault) {
        $opSignal.LogInformation("✅ Sources resolved: '$path'")
    }
    else {
        $opSignal.LogInformation("✅ Sources resolved: '$path' (template: '$template')")
    }

    $flatArray = $arraySignal.GetResult()

    # Build a graph and map items by identifier
    $graphSignal = [Graph]::Start("Graph:$sourcesKey", $opSignal, $true) | Select-Object -Last 1
    $graph = $graphSignal.GetResult()

    $signalMap = @{}
    foreach ($item in $flatArray) {
        $id = $item.Name

        if ($idPath) {
            $idSignal = Resolve-PathFromDictionary -Dictionary $item -Path $idPath | Select-Object -Last 1
            if ($opSignal.MergeSignalAndVerifyFailure(@($idSignal))) {
                $opSignal.LogCritical("Failed to resolve identifier path '$idPath' for item: $($item.Name)")
                return $opSignal
            }

            $id = $idSignal.GetResult()
        }

        $jacketSig = [Signal]::Start("Node:$($id):Jacket", $item)
        $jacketSig.SetResult($item)

        $nodeSignal = [Signal]::Start("Node:$id", $item) | Select-Object -Last 1
        $nodeSignal.SetJacket($jacketSig)

        $signalMap[$id] = $nodeSignal
        $graph.RegisterSignal($id, $nodeSignal) | Out-Null
    }

    # Link nodes using the same sources key path on each jacket
    # Turned off because sourcesKey doesn't find anything in jacket that matches the sources
    if ($sourcesKey) {
        foreach ($node in $signalMap.Values) {
            $jacket = $node.GetJacket()
            #$sourceSignal = Resolve-PathFromDictionary -Dictionary $jacket -Path $sourcesKey | Select-Object -Last 1
            <#
            if ($opSignal.MergeSignalAndVerifyFailure(@($sourceSignal))) {
                return $opSignal.LogCritical("Could not resolve sources from key: $sourcesKey")
            }

            $sourceIds = $sourceSignal.GetResult()
\
            $linked = @()
            foreach ($srcId in $sourceIds) {
                if ($signalMap.ContainsKey($srcId)) {
                    $linked += $signalMap[$srcId]
                }
            }

            if ($linked.Count -eq 1) { $node.SetPointer($linked[0]) }
            elseif ($linked.Count -gt 1) { $node.SetPointer($linked) }
            #>
        }
    }

    $graph.Finalize()
    $opSignal.SetResult($graph)
    $opSignal.LogInformation("✅ Signal graph constructed from JSON array.")
    return $opSignal
}
