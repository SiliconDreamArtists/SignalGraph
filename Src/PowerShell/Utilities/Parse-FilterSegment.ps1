#TODO: Make Signal Doctrine Compliant
function Parse-FilterSegment {
    param([string]$segment)

    $result = @{
        IsFilter = $false
        Raw = $segment
    }

    # Match the base key before any filters
    if ($segment -match '^([^\[]+)') {
        $result.ArrayKey = $matches[1]
    } else {
        return $result
    }

    # Match all [key op value] filters
    $filterPattern = "\[([^\[\]=!~]+?)(!?=|~=|~=i)\s*([""'])(.*?)\3\]"

    $matches = [regex]::Matches($segment, $filterPattern)

    if ($matches.Count -gt 0) {
        $result.IsFilter = $true
        $result.Filters = @()

        foreach ($m in $matches) {
            $op = switch ($m.Groups[2].Value) {
                '='     { '-eq' }
                '!='    { '-ne' }
                '~='    { '-like' }
                '~=i'   { '-ilike' }
                default { '-eq' }
            }

            $result.Filters += @{
                Key   = $m.Groups[1].Value.Trim()
                Op    = $op
                Value = $m.Groups[3].Value.Trim()
            }
        }
    }

    return $result
}