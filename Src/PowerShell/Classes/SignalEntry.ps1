class SignalEntry {
    [string]$Level
    [string[]]$Tags
    [string]$Message
    [Exception]$Exception
    [datetime]$CreatedDate
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
        $this.Message = "✨"+($message -replace "`r", '\r' -replace "`n", '\n')
        $this.Tags = $tags
        $this.CreatedDate = Get-Date
        $this.Exception = $exception
        $this.Signal = $signal
        $this.Meta = $meta ? $meta : $this.Meta

        if ($this.Tags) {
            $this.AddProperty("Tags", @($this.Tags))
        }

        $this.ProcessException($this.Exception)

        $this.ProcessReversePointer($this.Signal.ReversePointer)
    }

    # TODO: It should process Reverse Pointer details into meta externally, like during the plan?
    [void]ProcessReversePointer([object]$reversePointer)
    {

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

    [void]AddProperty([string]$key, [object]$value) {
        if (-not $this.Meta.PSObject.Properties[$key]) {
            Add-Member -InputObject $this.Meta -MemberType NoteProperty -Name $key -Value $value
        }
        else {
            $this.Meta.$key = $value
        }
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
