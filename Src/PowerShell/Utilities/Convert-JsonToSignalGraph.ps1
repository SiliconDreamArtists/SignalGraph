# =============================================================================
# ✅ Convert-JsonToSignalGraph (Generates a GSG from arbitrary JSON)
# =============================================================================
function Convert-JsonToSignalGraph {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][Signal]$Signal
    )

    $opSignal = [Signal]::Start("Convert-JsonToSignalGraph", $Signal) | Select-Object -Last 1
    $signalResult = [Signal]::Start("Result:Root", $opSignal) | Select-Object -Last 1
    $rootGraphSignal = [Graph]::Start("GSG:Root", $opSignal, $true) | Select-Object -Last 1
    $rootGraph = $rootGraphSignal.GetResult()
    $signalResult.SetPointer($rootGraph)
    $opSignal.MergeSignal(@($signalResult, $rootGraphSignal)) | Out-Null

    $signalMap = @{}

    function Register-RecursiveSignals {
        param (
            [object]$Object,
            [string]$Path,
            [Graph]$CurrentGraph
        )

        if ($null -eq $Object) { return }

        if ($Object -isnot [System.Collections.IDictionary] -and $Object -isnot [pscustomobject]) {
            return
        }

        $nodeSignal = [Signal]::Start("Node:$Path", $opSignal) | Select-Object -Last 1
        $nodeSignal.SetResult($Object)
        $CurrentGraph.RegisterSignal($nodeSignal.Name, $nodeSignal) | Out-Null

        foreach ($property in $Object.PSObject.Properties) {
            $value = $property.Value

            $isStructuredArray = $false
            if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
                foreach ($item in $value) {
                    if ($item -is [System.Collections.IDictionary] -or $item -is [pscustomobject]) {
                        $isStructuredArray = $true
                        break
                    }
                }
            }

            if ($isStructuredArray) {
                $valueArray = @($value)
                $childGraphSignal = [Graph]::Start("GSG:$Path.$($property.Name)", $opSignal, $true) | Select-Object -Last 1
                $childGraph = $childGraphSignal.GetResult()
                $opSignal.MergeSignal($childGraphSignal) | Out-Null

                $graphPointerSignal = [Signal]::Start("Pointer:$Path.$($property.Name)", $opSignal) | Select-Object -Last 1
                $graphPointerSignal.SetPointer($childGraph)
                $CurrentGraph.RegisterSignal($graphPointerSignal.Name, $graphPointerSignal) | Out-Null

                $i = 0
                foreach ($item in $valueArray) {
                    $childSignal = [Signal]::Start("Node:$Path.$($property.Name)[$i]", $opSignal) | Select-Object -Last 1
                    $childSignal.SetResult($item)
                    $childGraph.RegisterSignal($childSignal.Name, $childSignal) | Out-Null
                    $signalMap[$childSignal.Name] = $childSignal

                    if ($item -is [System.Collections.IDictionary] -or $item -is [pscustomobject] -or ($item -is [System.Collections.IEnumerable] -and -not ($item -is [string]))) {
                        Register-RecursiveSignals -Object $item -Path "$Path.$($property.Name)[$i]" -CurrentGraph $childGraph
                    }
                    $i++
                }
                continue
            }

            if ($value -is [System.Collections.IDictionary] -or $value -is [pscustomobject]) {
                Register-RecursiveSignals -Object $value -Path "$Path.$($property.Name)" -CurrentGraph $CurrentGraph
            }
        }
    }

    $root = if ($Signal.HasResult()) {
        $Signal.GetResult()
    } else {
        $jacketSignal = $Signal.GetJacketSignal() | Select-Object -Last 1
        if ($jacketSignal.HasResult()) {
            $jacketSignal.GetResult()
        } else {
            $opSignal.LogCritical("❌ No result found on Signal or Jacket.")
            return $opSignal
        }
    }

    Register-RecursiveSignals -Object $root -Path "Root" -CurrentGraph $rootGraph
    $signalResult.SetResult($root)
    $opSignal.SetResult($signalResult)
    Invoke-TraceSignalTree -Signal $signalResult -VisualizeFinal $true
    $opSignal.LogInformation("✅ GSG constructed recursively from arbitrary JSON.")
    return $opSignal
}
