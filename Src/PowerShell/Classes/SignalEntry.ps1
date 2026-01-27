class SignalEntry {
    [string]$Level
    [string[]]$Tags
    [string]$Message
    [string]$Exception
    [datetime]$CreatedDate
    [datetime]$LastModifiedDate
    [string]$CreatedBy
    [string]$LastModifiedBy
    [bool]$IsReadOnly
    [object]$Signal

    SignalEntry() {
        $this.CreatedDate = Get-Date
    }

    SignalEntry([object]$signal, [string]$level, [string]$message, [string[]]$tags = $null, [string]$exception = $null) {
        $this.Level = $level
        $this.Message = $message
        $this.Tags = $tags
        $this.CreatedDate = Get-Date
        $this.Exception = $exception
        $this.Signal = $signal
    }
}
