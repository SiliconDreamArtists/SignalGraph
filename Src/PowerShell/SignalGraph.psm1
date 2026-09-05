# Load the Signal and SignalEntry classes


# Embedded from SignalEntry.ps1
class SignalEntry {
    static [string] RemoveLeadingEmoji([string]$Text) {
        if ([string]::IsNullOrEmpty($Text)) {
            return $Text
        }

        $enumerator = [System.Globalization.StringInfo]::GetTextElementEnumerator($Text)
        if (-not $enumerator.MoveNext()) {
            return $Text
        }

        $firstElement = $enumerator.GetTextElement()
        if ($firstElement -notmatch '\p{So}|\p{Cs}') {
            return $Text
        }

        return $Text.Substring($firstElement.Length)
    }

    [string]$Level
    [string[]]$Tags
    [string]$Message
    [Exception]$Exception
    [datetime]$CreatedDate
    [datetime]$ModifiedDate
    [datetime]$LastModifiedDate
    [string]$CreatedBy
    [string]$LastModifiedBy
    [bool]$IsReadOnly
    [object]$Signal

    [object]$Meta = [PSCustomObject]@{}

    SignalEntry() {
        $this.CreatedDate = Get-Date
    }

        SignalEntry([object]$signal, [string]$level, [string]$message, [string[]]$tags = $null, [Exception]$exception = $null, $meta = $null) {
        $this.Level = $level
        $this.Message = [SignalEntry]::RemoveLeadingEmoji(($message -replace "`r", '\r' -replace "`n", '\n'))
        $this.Tags = $tags
        $this.CreatedDate = Get-Date
        $this.ModifiedDate = Get-Date
        $this.Exception = $exception
        $this.Signal = $signal
        $this.Meta = $meta ? $meta : $this.Meta

        if ($this.Tags) {
            $this.AddProperty("Tags", @($this.Tags))
        }

        $this.AddProperty("Type", "SignalEntry")
        $this.ProcessException($this.Exception)
        $this.get_EmojiTag()
    }

    [string] get_EmojiTag() {
        $a = $Global:EmojiMap['SignalEntry']
        $b = $Global:EmojiMap[$this.Level]
        if ($this.Exception) {
            $b = $Global:EmojiMap['Exception']
        }

        $c = ''
        if ($this.Signal.GetProperty("SignalType") -and $Global:EmojiMap.ContainsKey($this.Signal.GetProperty("SignalType")))
        {
            $c = $Global:EmojiMap[$this.Signal.GetProperty("SignalType")]
        }

        $val = $a+$b+$c

        $this.AddProperty("EmojiTag", $val)
        #return ""

        return $val
    }

    [bool]ContainsTag([string]$tag) {
        return $this.Tags -contains $tag
    }

    # TODO: It should process Exception  exception details into meta externally, like during the plan?
    [void]ProcessException([Exception]$exception)
    {
        if ($exception)
        {
            $this.AddProperty("ExceptionMessage", $exception.Message)

            $invocationInfo = $exception.ErrorRecord.InvocationInfo
            if ($invocationInfo) {
             #   $this.AddProperty("InvocationInfo", ($invocationInfo | ConvertTo-Json -Depth 4))
            }

            $stackTrace = $exception.ErrorRecord ? $exception.ErrorRecord.ScriptStackTrace : $exception.StackTrace

            $this.AddProperty("ExceptionStackTrace", $stackTrace)

            $exceptionCategoryInfo = $exception.ErrorRecord.CategoryInfo
            if ($exceptionCategoryInfo) {
             #   $this.AddProperty("ExceptionCategoryInfo", ($exceptionCategoryInfo | ConvertTo-Json -Depth 4))
            }
        }

    }

    [void]AddTag([string]$tag) {
        if (-not $this.Tags)
        {
            $this.Tags = @()
        }

        if (-not ($this.Tags -contains $tag)) {
            $this.Tags += $tag
        }

        $this.AddProperty("Tags", @($this.Tags))
    }

    [object]AddProperty([string]$key, [object]$value) {
        if (-not $this.Meta.PSObject.Properties[$key]) {
            Add-Member -InputObject $this.Meta -MemberType NoteProperty -Name $key -Value $value
        }
        else {
            $this.Meta.$key = $value
        }

        return $value
    }
    
    [string] get_MetaContent() {
        return $this.Meta | ConvertTo-Json -Depth 10
    }

    [int] get_LevelValue() {
        if ($Global:SignalFeedbackLevel.ContainsKey($this.Level)) {
            return $Global:SignalFeedbackLevel[$this.Level]
        }

        return $Global:SignalFeedbackLevel.Unspecified
    }
}


# Embedded from Signal.ps1
# Globals for external use only.
$Global:SignalFeedbackLevel = @{
    Unspecified = 0
    Information = 1
    Warning     = 2
    Critical    = 3
}

$Global:EmojiMap = @{
    Unspecified     = ''
    Information     = '✅'
    Warning         = '⚠️'
    Critical        = '❌'
    Exception       = '🔥'
    Signal          = '⭐'
    SignalEntry     = '✨'
    Success         = '✅'
    Failure         = '❌'

    Conductor       = '🔥'
    Conduction      = '⚡'
    ConductionPhase = '〰️'
}


[Flags()]
enum SignalTags {
    Unspecified = 0
    SensitiveInformation = 1
    Verbose = 2
    Code = 4
    Diagram = 8
    Operations = 16
    Retry = 32
    Recovery = 64
    Mute = 128
    Security = 256
    Content = 512
    Heal = 1024   # caller may take healing action before retry
    PatchPlan = 2048   # signal includes a plan patch overlay


    TelemetryScheduled = 4096
    TelemetrySent = 8192

}

class Signal {
    [string[]]$Tags
    [datetime]$CreatedDate
    [datetime]$ModifiedDate
    [object]$Pointer = $null
    [object]$ReversePointer = $null
    [object]$Jacket = $null
    [object]$Result = $null
    [object]$Control = $null
    [string]$Name
    [string]$Id = [guid]::NewGuid().ToString()
    [string]$Level = 'Information'
    [int]$LevelId = 4
    [object]$Meta = [PSCustomObject]@{}

    [System.Collections.Generic.List[SignalEntry]]$Entries = [System.Collections.Generic.List[SignalEntry]]::new()

    Signal() {}

    static [Signal] Start(
        [string]$name
    ) {
        return [Signal]::Start($name, $null)
    }

    static [Signal] Start(
        [string]$name,
        [object]$reversePointer = $null
    ) {
        $opSignal = [Signal]::new()
        $opSignal.Name = $name

        $opSignal.CreatedDate = Get-Date
        $opSignal.ModifiedDate = Get-Date

        if ($null -ne $reversePointer) {
            $opSignal.SetReversePointer($reversePointer) | Out-Null
        }

        return $opSignal
    }

    [string] get_EmojiTag() {
        $a = $Global:EmojiMap['Signal']
        $b = $Global:EmojiMap[$this.Level]

        $c = ''
        if ($this.GetProperty("SignalType") -and $Global:EmojiMap.ContainsKey($this.GetProperty("SignalType"))) {
            $c = $Global:EmojiMap[$this.GetProperty("SignalType")]
        }

        $val = $a + $b + $c
        $this.AddProperty("EmojiTag", $val)

        #    return ""
        return $val
    }

    [object] CreateGraph() {
        return Resolve-Graph -Signal $this
    }


    [void]AddTag([string]$tag) {
        if (-not $this.Tags) {
            $this.Tags = @()
        }

        if (-not ($this.Tags -contains $tag)) {
            $this.Tags += $tag
        }

        $this.AddProperty("Tags", @($this.Tags))
    }

    [object]AddProperty([string]$key, [object]$value) {
        $current = $this.Meta
        if (-not $current.PSObject.Properties[$key]) {
            Add-Member -InputObject $current -MemberType NoteProperty -Name $key -Value $Value
        }
        else {
            $current.$key = $Value
        }

        return $value
    }

    [object]GetProperty([string]$key) {
        $current = $this.Meta
        if (-not $current.PSObject.Properties[$key]) {
            return $null
        }
        else {
            return $current.$key
        }
    }

    [string[]] GetTags() {
        return $this.Tags
    }

    [string] get_MetaContent() {
        return $this.Meta | ConvertTo-Json -Depth 10
    }

    [Signal] LogMessage([string]$level, [string]$message) {
        return $this.LogMessage($level, $message, $null)
    }

    [Signal] LogMessage([string]$level, [string]$message, [string[]]$tags) {
        return $this.LogMessage($level, $message, $tags, $null)
    }

    [Signal] LogMessage([string]$_level, [string]$message, [string[]]$tags, [Exception]$exception = $null) {
        $entry = [SignalEntry]::new($this, $_level, $message, $tags, $exception, $null)
        $this.Entries.Add($entry)
        $this.UpdateLevel($_level, $tags)

        $signalAll = $false
        if ($signalAll -and $Global:SignalTelemeter) {
            try {
                & $Global:SignalTelemeter.Invoke($this, $entry)
            }
            catch {}
        }

        if ($_level -eq "Critical") {
            if (-not ($signalAll) -and $Global:SignalTelemeter) {
                try {
                    & $Global:SignalTelemeter.Invoke($this, $entry)
                }
                catch {}
            }


             $_level = "Critical"

            if ($exception) {
                $a = ""
            }

        }

        return $this
    }

    [Signal] LogInformation([string]$message) {
        return $this.LogMessage("Information", $message)
    }

    [Signal] LogInformation([string]$message, [string[]]$tags) {
        return $this.LogMessage("Information", $message, $tags)
    }

    [Signal] LogWarning([string]$message) {
        return $this.LogMessage("Warning", $message)
    }

    [Signal] LogWarning([string]$message, [string[]]$tags) {
        return $this.LogMessage("Warning", $message, $tags)
    }

    [Signal] LogCritical([string]$message) {
        return $this.LogMessage("Critical", $message)
    }

    [Signal] LogCritical([string]$message, [string[]]$tags, [Exception]$exception) {
        return $this.LogMessage("Critical", $message, $tags, $exception)
    }

    [Signal] LogCritical([string]$message, [string[]]$tags, [System.Management.Automation.ErrorRecord]$err) {
        $ex = if ($err) { $err.Exception } else { $null }
        return $this.LogMessage("Critical", $message, $tags, $ex)
    }

    [Signal] LogCritical([string]$message, [string[]]$tags) {
        return $this.LogMessage("Critical", $message, $tags)
    }

    # TODO: Review removing the tags portion of these shortcut methods.
    [Signal] LogVerbose([string]$message) {
        return $this.LogMessage("Information", $message, @("Verbose"))
    }

    [Signal] LogDiagram([string]$message) {
        return $this.LogMessage("Information", $message, @("Diagram"))
    }

    [Signal] LogRetry([string]$message) {
        return $this.LogMessage("Information", $message, @("Retry"))
    }

    [Signal] LogRecovery([string]$message) {
        return $this.LogMessage("Information", $message, @("Recovery"))
    }

    [Signal] LogMute([string]$message) {
        return $this.LogMessage("Information", $message, @("Mute"))
    }

    [void] UpdateLevel([string]$newLevel, [string[]]$tags) {
        $graph = @{
            "Unspecified" = 0
            "Information" = 4
            "Warning"     = 16
            "Critical"    = 64
        }

        $newValue = $graph[$newLevel]
        $currentValue = $graph[$this.Level]

        switch ($true) {
            { $tags -contains "Recovery" } {
                if ($this.Level -eq "Critical") {
                    $this.Level = "Warning"
                }
                break
            }
            { $tags -contains "Mute" } {
                if ($this.Level -eq "Critical") {
                    $this.Level = "Warning"
                }
                break
            }
            { $tags -contains "Diagram" } {
                # Diagram is non-intrusive; do nothing.
                break
            }
            default {
                if ($newValue -gt $currentValue) {
                    $this.Level = $newLevel
                }
            }
        }
    }

    [bool] Failure() {
        return $this.Level -eq 'Critical'
    }

    [bool] Success() {
        return $this.Level -ne 'Critical'
    }

    [Signal] MergeSignal([Signal[]]$signals, [string]$includeFilter, [string]$excludeFilter ) {
        foreach ($sig in $signals) {
            if ($null -ne $sig -and $this -ne $sig) {
                foreach ($entry in $sig.Entries) {
                    if ((-not $excludeFilter) -or !$entry.ContainsTag($excludeFilter)) {
                        $this.Entries.Add($entry)
                        $entry.Signal = $this
                        $entry.get_EmojiTag()
                        $this.UpdateLevel($entry.Level, $entry.Tags)
                    }
                }
            }
        }
        return $this
    }

    [Signal] MergeSignal([Signal[]]$signals) {
        foreach ($sig in $signals) {
            if ($null -ne $sig -and $this -ne $sig) {
                foreach ($entry in $sig.Entries) {
                    $this.Entries.Add($entry)
                    $entry.Signal = $this
                    $entry.get_EmojiTag()
                    $this.UpdateLevel($entry.Level, $entry.Tags)
                }
            }
        }
        return $this
    }

    [bool] MergeSignalAndVerifyFailure([Signal[]]$signals) {
        $this.MergeSignal($signals)
        return $this.Failure()
    }

    [bool] MergeSignalAndVerifySuccess([Signal[]]$signals) {
        return $this.MergeSignalAndVerifySuccess($signals, $false)
    }

    [bool] MergeSignalAndVerifySuccess([Signal[]]$signals, [bool]$MuteCritical = $false) {
        return $this.MergeSignalAndVerifySuccess($signals, $MuteCritical, $null)
    }

    [bool] MergeSignalAndVerifySuccess([Signal[]]$signals, [bool]$MuteCritical = $false, [string] $MuteMessage = $null) {
        $this.MergeSignal($signals)

        if ($this.Level -eq "Critical" -and $MuteCritical) {
            if ($null -ne $MuteMessage) {
                $this.LogMute($MuteMessage)
            }
            else {
                $this.LogMute("🔇 Critical signal merged with mute intent, local flow blocked — severity downgraded.")
            }

            return $false
        }

        return $this.Success()
    }

    [string] ToJson() {
        return $this | ConvertTo-Json -Depth 20 -Compress
    }

    static [Signal] FromJson([string]$json) {
        return $json | ConvertFrom-Json -Depth 20
    }

    
    [System.Collections.Generic.List[SignalEntry]] GetEntries() {
        if ($null -ne $this.Entries) {
            #           $this.LogInformation("🧵 Retrieved Entries from signal.")
            return $this.Entries
        }
        else {
            #          $this.LogWarning("No Entries present on signal.")
            return $null
        }
    }

    [bool] HasJacketResult() {
        return $this.HasJacket() -and $this.GetJacket().HasResult()
    }

    [object] GetJacketResult() {
        return $this.GetJacketResult($false)
    }

    [object] GetJacketResult([bool]$UnwrapSignal) {
        return $this.GetJacket().GetResult($UnwrapSignal)
    }

    [Signal] SetJacketResult([object]$value) {
        $thisJacket = $this.HasJacket() ? $this.GetJacket() : [Signal]::Start("$this.Name Jacket") | Select-Object -Last 1
        $this.SetJacket($thisJacket)
        $thisJacket.SetResult($value, $false)

        return $thisJacket
    }

    [void] SetMeta([object]$value) {
        $this.Meta = $value
    }

    [void] SetResult([object]$value) {
        $this.SetResult($value, $false)
    }

    [void] SetResult([object]$value, [bool]$unwrap) {
        if ($unwrap) {
            while ($value -is [Signal]) {
                $value = $value.GetResult() | Select-Object -Last 1
            }
        }

        $this.Result = $value
    }
        
    [object] GetResult() {
        return $this.GetResult($false)
    }
        
    [object] GetResult([bool]$UnwrapSignal) {
        if ($null -ne $this.Result) {
            #           $this.LogInformation("✅ Retrieved result from signal.")
            
            if ($UnwrapSignal -and $this.Result -is [Signal]) {
                return $this.Result.GetResult($UnwrapSignal)
            }
            return $this.Result
        }
        else {
            #           $this.LogCritical("Attempted to retrieve result but no result is present in signal.")
            return $null
        }
    }
        
    [bool] HasResult() {
        return $null -ne $this.Result
    }

    [bool] HasPointer() {
        return $null -ne $this.Pointer
    }

    [void] SetControl([object]$value) {
        $this.Control = $value
    }

    [bool] HasControl() {
        return $null -ne $this.Control
    }

    [Signal] GetControl([bool]$returnSelfForNullControl) {
        $value = $this.GetControl()
        if ($null -eq $value -and $returnSelfForNullControl) {
            $value = $this
        }

        return $value
    }

    [Signal] GetControl() {
        return $this.Control
    }

    [Signal] GetResultSignal() {
        $opSignal = [Signal]::Start("GetResultSignal:$($this.Name)") | Select-Object -Last 1
        if ($null -ne $this.Result) {
            $opSignal.SetResult($this.Result)
            $opSignal.LogInformation("✅ Result present and returned in new signal.")
        }
        else {
            $opSignal.LogCritical("Result is missing in parent signal.")
        }
        return $opSignal
    }

    [Signal] SetReversePointer([object]$value) {
        $opSignal = [Signal]::Start("SetReversePointer:$($this.Name)") | Select-Object -Last 1

        #Not done currently, waiting to look for the condition it's required before using it.
        #        while ($value -is [Signal]) {
        #            $value = $value.GetResult()
        #        }

        $this.ReversePointer = $value
        $opSignal.LogInformation("🔄 ReversePointer set on signal '$($this.Name)'.")
        $opSignal.SetResult($this)

        return $opSignal
    }

    [object] GetReversePointer() {
        if ($null -ne $this.ReversePointer) {
            #         $this.LogInformation("✅ Retrieved ReversePointer from signal.")
            return $this.ReversePointer
        }
        else {
            #        $this.LogWarning("No ReversePointer content present in signal.")
            return $null
        }
    }

    [Signal] GetReversePointerSignal() {
        $opSignal = [Signal]::Start("GetReversePointerSignal:$($this.Name)") | Select-Object -Last 1
        if ($null -ne $this.ReversePointer) {
            $opSignal.SetReversePointer($this.ReversePointer)
            $opSignal.LogInformation("✅ ReversePointer present and returned in new signal.")
        }
        else {
            $opSignal.LogCritical("ReversePointer is missing in parent signal.")
        }
        return $opSignal
    }

    [Signal] SetPointer([object]$value) {
        $opSignal = [Signal]::Start("SetPointer:$($this.Name)") | Select-Object -Last 1

        while ($value -is [Signal]) {
            $value = $value.GetResult()
        }

        $this.Pointer = $value
        $opSignal.LogInformation("📦 Pointer content set on signal '$($this.Name)'.")
        $opSignal.SetResult($this)

        return $opSignal
    }

    [object] GetPointer() {
        if ($null -ne $this.Pointer) {
            #            $this.LogInformation("✅ Retrieved Pointer from signal.")
            return $this.Pointer
        }
        else {
            #           $this.LogWarning("No Pointer content present in signal.")
            return $null
        }
    }

    [Signal] GetPointerSignal() {
        $opSignal = [Signal]::Start("GetPointerSignal:$($this.Name)") | Select-Object -Last 1
        if ($null -ne $this.Pointer) {
            $opSignal.SetPointer($this.Pointer)
            $opSignal.LogInformation("✅ Pointer present and returned in new signal.")
        }
        else {
            $opSignal.LogCritical("Pointer is missing in parent signal.")
        }
        return $opSignal
    }

    [Signal] SetJacket([object]$value) {
        $opSignal = [Signal]::Start("SetJacket:$($this.Name)") | Select-Object -Last 1

        if ($null -eq $value) {
            $opSignal.LogWarning("Jacket value is null; skipping set.")
            $opSignal.SetResult($this)
            return $opSignal
        }

        #        while ($value -is [Signal]) {
        #            $value = $value.GetResult()
        #        }

        $this.Jacket = $value
        $opSignal.LogInformation("🧥 Jacket set on signal '$($this.Name)'.")
        $opSignal.SetResult($this)

        return $opSignal
    }
        
    [bool] HasJacket() {
        return $null -ne $this.Jacket
    }

    [object] GetJacket() {
        if ($null -ne $this.Jacket) {
            #       $this.LogInformation("🧵 Retrieved Jacket from signal.")
            return $this.Jacket
        }
        else {
            #      $this.LogWarning("No Jacket present on signal.")
            return $null
        }
    }

    [Signal] GetJacketSignal() {
        $opSignal = [Signal]::Start("GetJacketSignal:$($this.Name)") | Select-Object -Last 1
        if ($null -ne $this.Jacket) {
            $opSignal.SetResult($this.Jacket)
            $opSignal.LogInformation("✅ Jacket returned in new signal.")
        }
        else {
            $opSignal.LogCritical("Jacket is missing in parent signal.")
        }
        return $opSignal
    }

    [Signal[]] GetLineage() {
        $lineage = @()

        if ($this.Pointer -is [Signal]) {
            $lineage += $this.Pointer
            $lineage += $this.Pointer.GetLineage()
        }
        elseif ($this.Pointer -is [System.Collections.IEnumerable]) {
            foreach ($parent in $this.Pointer) {
                if ($parent -is [Signal]) {
                    $lineage += $parent
                    $lineage += $parent.GetLineage()
                }
            }
        }

        return $lineage
    }
}

function Start-Signal(
    [string]$Name,
    [object]$ReversePointer = $null
) {
    return [Signal]::Start($Name, $ReversePointer) | Select-Object -Last 1
}

function Remove-LeadingEmoji {
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) {
        return $Text
    }

    if (-not (Resolve-StartsWithEmoji $Text)) {
        return $Text
    }

    $enumerator = [System.Globalization.StringInfo]::GetTextElementEnumerator($Text)
    $null = $enumerator.MoveNext()

    $firstElement = $enumerator.GetTextElement()
    $firstLength = $firstElement.Length

    return $Text.Substring($firstLength)
}

function Resolve-StartsWithEmoji {
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return $false }

    $enumerator = [System.Globalization.StringInfo]::GetTextElementEnumerator($Text)
    if (-not $enumerator.MoveNext()) { return $false }

    $firstElement = $enumerator.GetTextElement()

    # Emoji live mostly in Unicode Symbol categories
    foreach ($ch in $firstElement.ToCharArray()) {
        $cat = [char]::GetUnicodeCategory($ch)
        if ($cat -eq [System.Globalization.UnicodeCategory]::OtherSymbol) {
            return $true
        }
    }

    return $false
}


# Embedded from Graph.ps1
# =============================================================================
# 🧠 Graph (Working Memory using a Grid)
#  License: MIT License • Copyright (c) 2025 Silicon Dream Artists / BDDB
#  Authors: Shadow PhanTom ☠️🧁👾️/🤖 • Neural Alchemist ⚗️☣️🐲 • Last Generated: 05/02/2025
# =============================================================================
# The Graph object represents the live working memory during a conduction which can have an infiniate amount of internal conductions, so a user or ai may open a conduction with a graph and then perform a series of .
# The Graph is a ordered dictionary of Signals, which are the building blocks of the Graph. The Graph has a central Signal itself for tracking current state.
# The Signals in the grid have a Result which is a jacket for the hidden object in the Signal a _Memory which holds the memory of the signal and is transparently accessed with Resolve-PathFromDictionary and Add-PathToDictionary.
# The Result contains the settings for the signal in a dictionary, such as a physical file path, a VirtualPath that provides the wire hierarchy and anything else required, also easily accessible via Resolve-PathFromDictionary and Add-PathToDictionary.

class Graph {
    [object]$ReversePointer = $null
    [Signal]$Signal
    [ordered]$Grid

    Graph() {
        $this.Grid = [ordered]@{}
    }

    static [Signal] Start(
        [string]$name = "Graph",
        [object]$reversePointer = $null,
        [bool]$setPointer = $false
    ) {
        $opSignal = [Signal]::Start("Graph.Start:$name", $reversePointer) | Select-Object -Last 1

        $graph = [Graph]::new()
        $graph.ReversePointer = $reversePointer
        $graph.Signal = [Signal]::Start($name, $reversePointer) | Select-Object -Last 1
        $graph.Signal.LogVerbose("🧠 Graph '$name' initialized via Start().")

        $resultSignal = [Signal]::Start("Graph.Instance:$name", $graph.Signal) | Select-Object -Last 1
        if ($setPointer) {
            $resultSignal.SetPointer($graph)
        } else {
            $resultSignal.SetResult($graph)
        }

        $opSignal.MergeSignal(@($resultSignal)) | Out-Null
        $opSignal.SetResult($graph)
        $opSignal.LogInformation("🧠 Graph created and returned from Start().")

        return $opSignal
    }

    [Signal] Finalize() {
        $opSignal = [Signal]::Start("Graph.Finalize", $this.Signal) | Select-Object -Last 1
        $opSignal.LogInformation("✅ Graph condensation finalized. Total registered signals: $($this.Grid.Count)")
        $this.Signal.MergeSignal($opSignal)
        return $opSignal
    }

    [Signal] RegisterSignal([string]$Key, [Signal]$Signal) {
        $opSignal = [Signal]::Start("RegisterSignal:$Key", $this.Signal) | Select-Object -Last 1

        if ($this.Grid.Contains($Key)) {
            $opSignal.LogWarning("Overwriting existing signal at key: $Key")
        }

        $this.Grid[$Key] = $Signal
        $opSignal.LogVerbose("🔗 Signal registered under key: $Key")

        $this.Signal.MergeSignal($opSignal)
        return $opSignal
    }

    [Signal] UnRegisterSignal([string]$Key) {
        $opSignal = [Signal]::Start("UnRegisterSignal:$Key", $this.Signal) | Select-Object -Last 1

        if ($this.Grid.Contains($Key)) {
            $this.Grid.Remove($Key)
            $opSignal.LogVerbose("🔓 Signal unregistered at key: $Key")
        } else {
            $opSignal.LogWarning("Attempted to unregister missing signal at key: $Key")
        }

        $this.Signal.MergeSignal($opSignal)
        return $opSignal
    }

    [Graph] CreateGraphForSignal([Signal]$Signal)
    {
        $Signal.Graph = [Graph]::Start("Graph", $Signal, $true)
        return $Signal.Graph
    }

    [Signal] RegisterResultAsSignal([string]$Key, [object]$Result) {
        $opSignal = [Signal]::Start("RegisterResultAsSignal:$Key", $this.Signal) | Select-Object -Last 1
        $resultSignal = [Signal]::Start($Key, $this.Signal) | Select-Object -Last 1
        $resultSignal.SetResult($Result)
        $opSignal.MergeSignal($this.RegisterSignal($Key, $resultSignal))
        return $opSignal
    }

    [object[]] GetKeys() {
        return $this.Grid.Keys
    }

    [Signal] Resolve([string]$Key) {
        $opSignal = [Signal]::Start("Graph.Resolve:$Key", $this.Signal) | Select-Object -Last 1

        if ($this.Grid.Contains($Key)) {
            $resolved = $this.Grid[$Key]
            $opSignal.SetResult($resolved.GetResult())
            $opSignal.LogInformation("✅ Resolved signal at key '$Key'.")
        } else {
            $opSignal.LogWarning("No signal registered at key '$Key'.")
        }

        return $opSignal
    }

    [string] ToJson([bool]$IgnoreInternalObjects = $false) {
        $opSignal = [Signal]::Start("Graph.ToJson", $this.Signal) | Select-Object -Last 1

        try {
            $jsonObjectSignal = Convert-GraphToJsonObject -Graph $this -IgnoreInternalObjects:$IgnoreInternalObjects | Select-Object -Last 1
            if ($opSignal.MergeSignalAndVerifyFailure($jsonObjectSignal)) {
                $opSignal.LogCritical("Failed to convert Graph to JSON object.")
                return $null
            }

            $json = $jsonObjectSignal.GetResult() | ConvertTo-Json -Depth 25
            return $json
        }
        catch {
            $opSignal.LogCritical("🔥 Exception during Graph.ToJson(): $($_.Exception.Message)", $null, $_)
            return $null
        }
    }

    static [Signal] FromJson([string]$json, [bool]$IgnoreInternalObjects = $false) {
        $opSignal = [Signal]::Start("Graph.FromJson") | Select-Object -Last 1

        try {
            $jsonObject = $json | ConvertFrom-Json -Depth 25

            $conversionSignal = Convert-JsonObjectToGraph -JsonObject $jsonObject -IgnoreInternalObjects:$IgnoreInternalObjects | Select-Object -Last 1
            $opSignal.MergeSignal($conversionSignal)

            if ($conversionSignal.Failure()) {
                $opSignal.LogCritical("Failed to reconstruct Graph from JSON.")
                $opSignal.IsTerminal = $true
                return $opSignal
            }

            $graph = $conversionSignal.GetResult()
            $opSignal.SetResult($graph)
            $opSignal.LogInformation("✅ Successfully reconstructed Graph from JSON.")
        }
        catch {
            $opSignal.LogCritical("🔥 Exception in Graph.FromJson: $($_.Exception.Message)", $null, $_)
            $opSignal.IsTerminal = $true
        }

        return $opSignal
    }
}


function Resolve-Graph {
            [CmdletBinding()]
        param (
            [Signal]$Signal
        )

    $Signal.Pointer = ([Graph]::Start($Signal.Name, $Signal, $true) | Select-Object -Last 1).GetResult()
    return $Signal.Pointer
}
. "$PSScriptRoot/Utilities/Get-ResolvedValueFromPathSignal.ps1"
. "$PSScriptRoot/Utilities/Convert-JsonToSignalGraph.ps1"
. "$PSScriptRoot/Utilities/Add-PathToDictionary.ps1"
. "$PSScriptRoot/Utilities/Resolve-PathHydration.ps1"
. "$PSScriptRoot/Utilities/Resolve-InnerPathFromDictionary.ps1"
. "$PSScriptRoot/Utilities/Resolve-PathFromDictionary.ps1"
. "$PSScriptRoot/Utilities/Remove-PathFromDictionary.ps1"
. "$PSScriptRoot/Utilities/Resolve-GraphPlanInjectionContext.ps1"
. "$PSScriptRoot/Utilities/Move-PathInDictionary.ps1"
. "$PSScriptRoot/Utilities/Resolve-PathGraphForJsonArray.ps1"
. "$PSScriptRoot/Utilities/Resolve-GraphForJsonArray.ps1"
. "$PSScriptRoot/Utilities/Invoke-ParseFilterSegment.ps1"


. "$PSScriptRoot/Utilities/Convert-ToDictionary.ps1"

Export-ModuleMember -Function Get-ResolvedValueFromPathSignal
Export-ModuleMember -Function Convert-JsonToSignalGraph
Export-ModuleMember -Function Add-PathToDictionary
Export-ModuleMember -Function Resolve-PathHydration
Export-ModuleMember -Function Resolve-InnerPathFromDictionary
Export-ModuleMember -Function Resolve-PathFromDictionary
Export-ModuleMember -Function Resolve-GraphPlanInjectionContext
Export-ModuleMember -Function Move-PathInDictionary
Export-ModuleMember -Function Resolve-PathGraphForJsonArray
Export-ModuleMember -Function Convert-ToDictionary
Export-ModuleMember -Function Remove-PathFromDictionary

Export-ModuleMember -Function Resolve-GraphForJsonArray
Export-ModuleMember -Function Start-Signal



Export-ModuleMember -Function Remove-LeadingEmoji
