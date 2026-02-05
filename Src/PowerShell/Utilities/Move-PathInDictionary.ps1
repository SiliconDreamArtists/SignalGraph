function Move-PathInDictionary {
    param (
        [Parameter(Mandatory)] $Dictionary,
        [Parameter(Mandatory)] [string]$SourcePath,
        [Parameter(Mandatory)] [string]$DestinationPath
    )

    $signal = [Signal]::Start("Move-PathInDictionary", $Dictionary)

    # Step 1: Resolve source value
    $sourceSignal = Resolve-PathFromDictionary -Dictionary $Dictionary -Path $SourcePath -IgnoreInternalObjects:$IgnoreInternalObjects -SkipFinalInternalUnwrap:$SkipFinalInternalUnwrap
    if ($signal.MergeSignalAndVerifyFailure($sourceSignal)) {
        return $signal.LogCritical("Failed to resolve source at '$SourcePath'")
    }

    $valueToMove = $sourceSignal.GetResult()

    # Step 2: Add to destination
    $addSignal = Add-PathToDictionary -Dictionary $Dictionary -Path $DestinationPath -Value $valueToMove
    if ($signal.MergeSignalAndVerifyFailure($addSignal)) {
        return $signal.LogCritical("Failed to add value to destination path '$DestinationPath'")
    }

    # Step 3: Remove source (if destination write succeeded)
    $removeSignal = Remove-PathFromDictionary -Dictionary $Dictionary -Path $SourcePath -IgnoreInternalObjects:$IgnoreInternalObjects -SkipFinalInternalUnwrap:$SkipFinalInternalUnwrap
    $signal.MergeSignal($removeSignal)

    if ($removeSignal.Failure()) {
        $signal.LogWarning("Move succeeded but could not remove original at '$SourcePath'")
    } else {
        $signal.LogInformation("🔀 Successfully moved value from '$SourcePath' to '$DestinationPath'")
    }

    $signal.SetResult($Dictionary)
    return $signal
}
