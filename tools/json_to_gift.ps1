param(
    [Parameter(Mandatory=$true)]
    [string]$InputJson,

    [Parameter(Mandatory=$true)]
    [string]$OutputGift

    ,
    [switch]$SingleLineStem,

    [switch]$UseAuthoritativeFirst40Key
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Normalize-Text {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }

    $t = $Text.ToLowerInvariant()
    $t = $t.Replace([char]0x00A0, ' ')
    $t = $t -replace '\s+', ' '
    return $t.Trim()
}

function Escape-Gift {
    param([string]$Text)
    if ($null -eq $Text) { return '' }

    $t = $Text
    $t = $t -replace '\\', '\\\\'
    $t = $t -replace '([{}~=#:])', '\\$1'
    return $t
}

function To-SingleLine {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    $t = $Text -replace '[\r\n]+', ' '
    $t = $t -replace '\s+', ' '
    return $t.Trim()
}

function Get-AuthoritativeFirst40Key {
    $map = @{}
    $map[1]  = @('b','d')
    $map[2]  = @('a','c')
    $map[3]  = @('c','d')
    $map[4]  = @('b','d','e')
    $map[5]  = @('d')
    $map[6]  = @('a','c','e')
    $map[7]  = @('d','e')
    $map[8]  = @('b','c')
    $map[9]  = @('d')
    $map[10] = @('c','d')
    $map[11] = @('b')
    $map[12] = @('d')
    $map[13] = @('b','c')
    $map[14] = @('e')
    $map[15] = @('a','b')
    $map[16] = @('c')
    $map[17] = @('d')
    $map[18] = @('b')
    $map[19] = @('b')
    $map[20] = @('a','d')
    $map[21] = @('c')
    $map[22] = @('b')
    $map[23] = @('b','d')
    $map[24] = @('c')
    $map[25] = @('b','e')
    $map[26] = @('b','f')
    $map[27] = @('b','e')
    $map[28] = @('d')
    $map[29] = @('a')
    $map[30] = @('b','c')
    $map[31] = @('b','e')
    $map[32] = @('a','d')
    $map[33] = @('b')
    $map[34] = @('e')
    $map[35] = @('a','b','e')
    $map[36] = @('b','d')
    $map[37] = @('b','e')
    $map[38] = @('d')
    $map[39] = @('e')
    $map[40] = @('a')
    return $map
}

function Get-CorrectOptionKeys {
    param(
        [object]$Question,
        [string[]]$OptionKeys
    )

    $correct = New-Object System.Collections.Generic.List[string]
    $rightAnswer = ''
    if ($Question.PSObject.Properties.Name -contains 'rightAnswer') {
        $rightAnswer = [string]$Question.rightAnswer
    }

    $rightNorm = Normalize-Text $rightAnswer

    foreach ($key in $OptionKeys) {
        $optText = [string]$Question.$key
        $optNorm = Normalize-Text $optText
        if ($optNorm.Length -lt 6) { continue }

        if ($rightNorm.Contains($optNorm)) {
            $correct.Add($key)
        }
    }

    # Fallback to selectedOptions when rightAnswer matching fails.
    if ($correct.Count -eq 0 -and $Question.PSObject.Properties.Name -contains 'selectedOptions') {
        foreach ($k in @($Question.selectedOptions)) {
            $kk = [string]$k
            if ($OptionKeys -contains $kk) {
                $correct.Add($kk)
            }
        }
    }

    # Last-resort fallback for "Aucune des réponses proposées" style answers.
    if ($correct.Count -eq 0 -and $rightNorm.Contains('aucune des réponses proposées')) {
        foreach ($key in $OptionKeys) {
            $optNorm = Normalize-Text ([string]$Question.$key)
            if ($optNorm.Contains('aucune des réponses proposées')) {
                $correct.Add($key)
                break
            }
        }
    }

    # Deduplicate while preserving order.
    $seen = @{}
    $deduped = New-Object System.Collections.Generic.List[string]
    foreach ($k in $correct) {
        if (-not $seen.ContainsKey($k)) {
            $seen[$k] = $true
            $deduped.Add($k)
        }
    }

    return @($deduped.ToArray())
}

if (-not (Test-Path -LiteralPath $InputJson)) {
    throw "Input JSON not found: $InputJson"
}

$raw = Get-Content -LiteralPath $InputJson -Raw -Encoding UTF8
$questions = $raw | ConvertFrom-Json

if ($questions -isnot [System.Array]) {
    throw 'Input JSON must be an array of question objects.'
}

$giftLines = New-Object System.Collections.Generic.List[string]
$index = 0
$authoritativeMap = if ($UseAuthoritativeFirst40Key) { Get-AuthoritativeFirst40Key } else { @{} }

foreach ($q in $questions) {
    $index++

    $propNames = @($q.PSObject.Properties.Name)
    $optionKeys = @($propNames | Where-Object { $_ -match '^[a-z]$' } | Sort-Object)

    if ($optionKeys.Count -lt 2) {
        continue
    }

    $number = if ($propNames -contains 'number') { [string]$q.number } else { "Question $index" }
    $fullQuestion = if ($propNames -contains 'fullQuestion') { [string]$q.fullQuestion } else { '' }

    if (-not [string]::IsNullOrWhiteSpace($fullQuestion) -and (Normalize-Text $fullQuestion) -ne 'n/a') {
        $stem = $fullQuestion.Trim()
    } else {
        $scene = if ($propNames -contains 'scene') { [string]$q.scene } else { '' }
        $mission = if ($propNames -contains 'mission') { [string]$q.mission } else { '' }

        $stemParts = New-Object System.Collections.Generic.List[string]
        $stemParts.Add($number)
        if (-not [string]::IsNullOrWhiteSpace($scene) -and (Normalize-Text $scene) -ne 'n/a') {
            $stemParts.Add($scene)
        }
        if (-not [string]::IsNullOrWhiteSpace($mission) -and (Normalize-Text $mission) -ne 'n/a') {
            $stemParts.Add($mission)
        }

        $stem = ($stemParts -join "`n`n")
    }
    if ($SingleLineStem) {
        $stem = To-SingleLine $stem
    }

    $id = if ($propNames -contains 'id') { [string]$q.id } else { "q-$index" }
    $inputType = if ($propNames -contains 'inputType') { [string]$q.inputType } else { 'checkbox' }

    $correctKeys = @(Get-CorrectOptionKeys -Question $q -OptionKeys $optionKeys)
    if ($UseAuthoritativeFirst40Key -and $authoritativeMap.ContainsKey($index)) {
        $manual = @($authoritativeMap[$index] | ForEach-Object { ([string]$_).ToLowerInvariant() })
        $filtered = @($manual | Where-Object { $optionKeys -contains $_ })
        if ($filtered.Count -gt 0) {
            $correctKeys = $filtered
        } else {
            Write-Warning "Question $index has no matching authoritative options in available keys: $($optionKeys -join ', ')"
        }
    }

    if ($correctKeys.Count -eq 0) {
        continue
    }

    $isMultiple = ($inputType -eq 'checkbox' -or $correctKeys.Count -gt 1)

    $giftLines.Add("::$(Escape-Gift $id)::$(Escape-Gift $stem){")

    if ($isMultiple) {
        $pct = [math]::Round(100.0 / $correctKeys.Count, 5)
        foreach ($key in $optionKeys) {
            $optText = Escape-Gift ([string]$q.$key)
            if ($correctKeys -contains $key) {
                $giftLines.Add("~%$pct%$optText")
            } else {
                $giftLines.Add("~$optText")
            }
        }
    } else {
        foreach ($key in $optionKeys) {
            $optText = Escape-Gift ([string]$q.$key)
            if ($correctKeys -contains $key) {
                $giftLines.Add("=$optText")
            } else {
                $giftLines.Add("~$optText")
            }
        }
    }

    $giftLines.Add('}')
    $giftLines.Add('')
}

$giftContent = ($giftLines -join "`r`n")
[System.IO.File]::WriteAllText($OutputGift, $giftContent, [System.Text.UTF8Encoding]::new($false))

Write-Host "Wrote GIFT file: $OutputGift"
Write-Host "Question count exported: $([regex]::Matches($giftContent, '^::', 'Multiline').Count)"
