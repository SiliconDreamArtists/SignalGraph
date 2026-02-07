# Globals for external use only.
$Global:SignalFeedbackLevel = @{
    Unspecified          = 0
    Information          = 1
    Warning              = 2
    Critical             = 3
}

$Global:EmojiMap = @{
    Unspecified         = ''
    Information         = '✅'
    Warning             = '⚠️'
    Critical            = '❌'
    Exception           = '🔥'
    Signal              = '⭐'
    SignalEntry         = '✨'
    Success             = '✅'
    Failure             = '❌'

    Conduction             = '⚡'
    ConductionPhase        = '〰️'
}


[Flags()]
enum SignalTags {
    Unspecified          = 0
    SensitiveInformation = 1
    Verbose              = 2
    Code                 = 4
    Diagram              = 8
    Operations           = 16
    Retry                = 32
    Recovery             = 64
    Mute                 = 128
    Security             = 256
    Content              = 512
    Heal                 = 1024   # caller may take healing action before retry
    PatchPlan            = 2048   # signal includes a plan patch overlay


    TelemetryScheduled   = 4096
    TelemetrySent        = 8192

}

class Signal {
    [string[]]$Tags
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

        if ($null -ne $reversePointer) {
            $opSignal.SetReversePointer($reversePointer) | Out-Null
        }

        return $opSignal
    }

    [string] get_EmojiTag() {
        $a = $Global:EmojiMap['Signal']
        $b = $Global:EmojiMap[$this.Level]

        $c = ''
        if ($this.GetProperty("SignalType") -and $Global:EmojiMap.ContainsKey($this.GetProperty("SignalType")))
        {
            $c = $Global:EmojiMap[$this.GetProperty("SignalType")]
        }

        $val = $a+$b+$c
        $this.AddProperty("EmojiTag", $val)

    #    return ""
        return $val
    }

    [object] CreateGraph()
    {
        return Resolve-Graph -Signal $this
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

        if ($Global:SignalTelemeter) {
            try {
                & $Global:SignalTelemeter.Invoke($this, $entry)
            }
            catch {}
        }

        if ($_level -eq "Critical") {
            $_level = "Critical"

            if ($exception)
            {
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

    $newValue     = $graph[$newLevel]
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
            
            if ($UnwrapSignal -and $this.Result -is [Signal])
            {
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

    [void] SetControl([object]$value) {
        $this.Control = $value
    }

    [bool] HasControl() {
        return $null -ne $this.Control
    }

    [Signal] GetControl([bool]$returnSelfForNullControl) {
        $value = $this.GetControl()
        if ($null -eq $value -and $returnSelfForNullControl)
        {
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
    $firstLength  = $firstElement.Length

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
