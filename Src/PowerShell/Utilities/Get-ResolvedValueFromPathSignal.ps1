function Get-ResolvedValueFromPathSignal {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$Dictionary,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $opSignal = [Signal]::Start("Resolve-ValueAsSignal:$Path") | Select-Object -Last 1

    $resolvedSignal = Resolve-PathFromDictionary -Dictionary $Dictionary -Path $Path | Select-Object -Last 1
    $opSignal.MergeSignal($resolvedSignal) | Out-Null

    if ($resolvedSignal.IsFailure) {
        $opSignal.LogCritical("Failed to resolve path '$Path'.")
        return $opSignal
    }

    $result = $resolvedSignal.GetResult()
    $opSignal.SetResult($result)

    if ($null -eq $result) {
        $opSignal.LogWarning("Resolved value is null at path '$Path'.")
    }
    else {
        $opSignal.LogInformation("✅ Value resolved and returned for path '$Path'.")
    }

    return $opSignal
}
