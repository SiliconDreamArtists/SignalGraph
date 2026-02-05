# =============================================================================
# ✅ Convert-JsonToSignalGraph (Generates a GSG from arbitrary JSON)
# =============================================================================
function Convert-JsonToSignalGraph {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][Signal]$Signal
    )

    $opSignal = [Signal]::Start("Convert-JsonToSignalGraph", $Signal) | Select-Object -Last 1
    $signalResult = [Signal]::Start("Root", $opSignal) | Select-Object -Last 1
    $rootGraphSignal = [Graph]::Start("Root", $opSignal, $true) | Select-Object -Last 1
    $rootGraph = $rootGraphSignal.GetResult()
    $signalResult.SetPointer($rootGraph)
    $opSignal.MergeSignal(@($signalResult, $rootGraphSignal)) | Out-Null

    $signalMap = @{}

    function Register-RecursiveSignals {
        param (
            [object]$Object,
            [string]$Path,
            [Graph]$ParentGraph
        )

        if ($null -eq $Object) { return }

        if ($Object -isnot [System.Collections.IDictionary] -and $Object -isnot [pscustomobject]) {
            return
        }

        $PathParts = $Path -split '\.'
        $PathPartName = $PathParts[-1]

        $nodeSignal = [Signal]::Start("$PathPartName", $opSignal) | Select-Object -Last 1
        $nodeSignal.SetResult($Object)
        $ParentGraph.RegisterSignal($nodeSignal.Name, $nodeSignal) | Out-Null

        $childGraphSignal = [Graph]::Start("$PathPartName", $nodeSignal, $true) | Select-Object -Last 1
        $childGraph = $childGraphSignal.GetResult()
        $nodeSignal.SetPointer($childGraph)

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
                $arrayGraphSignal = [Graph]::Start("$Path.$($property.Name)", $opSignal, $true) | Select-Object -Last 1
                $arrayGraph = $arrayGraphSignal.GetResult()
                $opSignal.MergeSignal($arrayGraphSignal) | Out-Null

                $graphPointerSignal = [Signal]::Start("$Path.$($property.Name)", $opSignal) | Select-Object -Last 1
                $graphPointerSignal.SetPointer($arrayGraph)
                $childGraph.RegisterSignal($graphPointerSignal.Name, $graphPointerSignal) | Out-Null

                $i = 0
                foreach ($item in $valueArray) {
                    $childSignal = [Signal]::Start("$Path.$($property.Name)[$i]", $opSignal) | Select-Object -Last 1
                    $childSignal.SetResult($item)
                    $arrayGraph.RegisterSignal($childSignal.Name, $childSignal) | Out-Null
                    $signalMap[$childSignal.Name] = $childSignal

                    if ($item -is [System.Collections.IDictionary] -or $item -is [pscustomobject] -or ($item -is [System.Collections.IEnumerable] -and -not ($item -is [string]))) {
                        Register-RecursiveSignals -Object $item -Path "$Path.$($property.Name)[$i]" -ParentGraph $arrayGraph
                    }
                    $i++
                }
                continue
            }

            if ($value -is [System.Collections.IDictionary] -or $value -is [pscustomobject]) {
                Register-RecursiveSignals -Object $value -Path "$Path.$($property.Name)" -ParentGraph $childGraph
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
            $opSignal.LogCritical("No result found on Signal or Jacket.")
            return $opSignal
        }
    }

    Register-RecursiveSignals -Object $root -Path "Root" -ParentGraph $rootGraph
    $signalResult.SetResult($root)

    $rootSignal = Resolve-PathFromDictionary -Dictionary $signalResult -Path "*.#.Root" | Select-Object -Last 1

    if ($opSignal.MergeSignalAndVerifyFailure($rootSignal)) {
        $opSignal.LogCritical("Failed to resolve root signal.")
        return $opSignal
    }

    $opSignal.SetResult($rootSignal.GetResult())

    $opSignal.LogInformation("✅ GSG constructed recursively from arbitrary JSON.")
    return $opSignal
}
