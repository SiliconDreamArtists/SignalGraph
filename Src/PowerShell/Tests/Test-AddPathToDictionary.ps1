# Test-AddPathToDictionary.ps1

. "$PSScriptRoot/../Classes/Signal.ps1"
. "$PSScriptRoot/../Classes/Graph.ps1"
. "$PSScriptRoot/../Utilities/Resolve-PathFromDictionary.ps1"
. "$PSScriptRoot/../Utilities/Add-PathToDictionary.ps1"

Import-Module $PSScriptRoot/../SignalGraph.psd1 -Force

Write-Host "🧪 Running SovereignTrust Mutation Tests..." -ForegroundColor Cyan

function Test-Case {
    param (
        [string]$Title,
        [object]$Dictionary,
        [string]$Path,
        [object]$Value,
        [object]$Expected,
        [ScriptBlock]$GetResult
    )

    $opSignal = [Signal]::Start("TestCase:$Title") | Select-Object -Last 1
    $opSignal.LogInformation("🔸 $Title")

    # 🧠 Wrap dictionary in a sovereign signal
    $wrappedSignal = [Signal]::Start($Title)
    $wrappedSignal.SetResult($Dictionary)

    # 📝 Write value
    $writeSignal = Add-PathToDictionary -Dictionary $wrappedSignal -Path $Path -Value $Value | Select-Object -Last 1
    if ($writeSignal -isnot [Signal] -or $writeSignal.Failure()) {
        $opSignal.MergeSignal($writeSignal)
        $opSignal.LogCritical("❌ Write failed: $($writeSignal.Name)")
        return $opSignal
    }

    # 🔍 Read value back from original signal
    $readSignal = Resolve-PathFromDictionary -Dictionary $wrappedSignal -Path $Path | Select-Object -Last 1
    $opSignal.MergeSignal($readSignal)
    if ($readSignal.Failure()) {
        $opSignal.LogCritical("❌ Read failed: $($readSignal.Name)")
        return $opSignal
    }

    try {
        $actual = $readSignal.GetResult()
        $opSignal.SetResult($actual)

        if ($actual -eq $Expected) {
            $opSignal.LogInformation("✅ Passed: Got expected result '$Expected'")
        } else {
            $opSignal.LogCritical("❌ Mismatch: expected '$Expected', got '$actual'")
        }
    }
    catch {
        $opSignal.LogCritical("❌ Error while evaluating result: $_", $null, $_)
    }

    return $opSignal
}

# ░▒▓█ TEST CASES █▓▒░

#    -Path "$.#.$.Foo.@.Bar" `

# 1. Write to Result
# 2. Write To Jacket Signal Result
# 3. Write to Pointer (Graph) Named Signal Result
# 4. Write to Pointer (Graph) Named Signal Pointer Graph Signal


# 1. Plain hashtable write into the result of the passed in object
$testSignal = Test-Case -Title "Write into plain hashtable" `
    -Dictionary @{ Foo = @{ Bar = @{} } } `
    -Path "@.Foo" `
    -Value 42 `
    -Expected 42 `
    -GetResult { return $Dictionary["Foo"] } | Select-Object -Last 1

    Invoke-TraceSignalTree -Signal $testSignal -VisualizeFinal $true # -IncludeResultValue $true

# 2. Jacket segment write
$signal = [Signal]::Start("jacket-test")
Test-Case -Title "Write into %.Jacket.NewKey" `
    -Dictionary $signal `
    -Path "%.Jacket.NewKey" `
    -Value "ABC" `
    -Expected "ABC" `
    -GetResult { return $signal.GetJacket().NewKey }

# 3. Result path write (@)
$signal2 = [Signal]::Start("result-test")
$signal2.SetResult(@{})
Test-Case -Title "Write into result object @" `
    -Dictionary $signal2 `
    -Path "@.Info.Data" `
    -Value "X" `
    -Expected "X" `
    -GetResult { return $signal2.GetResult().Info.Data }

# 4. Graph → Grid write
$graph = [Graph]::Start("test-graph")
Test-Case -Title "Write into Graph.Grid.NewPath" `
    -Dictionary $graph `
    -Path "#.NewPath.Value" `
    -Value 3.14 `
    -Expected 3.14 `
    -GetResult { return $graph.Grid.NewPath.Value }

# 5. Create new PSObject branch
$signal3 = [Signal]::Start("object-test")
$signal3.SetResult([PSCustomObject]@{})
Test-Case -Title "Write into new object path @.Stats.Count" `
    -Dictionary $signal3 `
    -Path "@.Stats.Count" `
    -Value 7 `
    -Expected 7 `
    -GetResult { return $signal3.GetResult().Stats.Count }

Write-Host "✅ All tests complete." -ForegroundColor Cyan
