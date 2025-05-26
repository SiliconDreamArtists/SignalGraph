# =============================================================================
# ⚙️ Invoke-GSGProcessingRules (Processes a GSG with structural checks)
# =============================================================================
function Invoke-GSGProcessingRules {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][Graph]$Graph,
        [Parameter()][hashtable]$Options = @{}
    )

    $opSignal = [Signal]::Start("Invoke-GSGProcessingRules") | Select-Object -Last 1

    foreach ($entry in $Graph.Grid.GetEnumerator()) {
        $signal = $entry.Value
        if (-not $signal.Pointer) {
            $opSignal.LogWarning("⚠️ Signal '$($signal.Name)' has no Pointer.")
        }

        if (-not $signal.Jacket.ContainsKey("Identifier")) {
            $opSignal.LogWarning("⚠️ Signal '$($signal.Name)' missing required 'Identifier'.")
        }

        # Insert rule processors here as needed
    }

    $opSignal.SetResult($Graph)
    $opSignal.LogInformation("✅ GSG processed with basic structural rules.")
    return $opSignal
}
