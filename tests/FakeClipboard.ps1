# An in-memory clipboard behind the same four-member interface as the real one (lib\Clipboard.ps1).
# Waits never sleep; they only count. OnWait lets a test act at a given second (copy something else,
# or throw to stand in for Ctrl+C).

function New-LiteFakeClipboard {
    $state = [pscustomobject]@{ Text = $null; Waited = 0; SetCount = 0; ClearCount = 0; OnWait = $null }
    $state | Add-Member -MemberType NoteProperty -Name Name -Value 'fake'
    $state | Add-Member -MemberType NoteProperty -Name Set -Value ({ param($Text) $state.Text = $Text; $state.SetCount++ }.GetNewClosure())
    $state | Add-Member -MemberType NoteProperty -Name Get -Value ({ $state.Text }.GetNewClosure())
    $state | Add-Member -MemberType NoteProperty -Name Clear -Value ({ $state.Text = $null; $state.ClearCount++ }.GetNewClosure())
    $state | Add-Member -MemberType NoteProperty -Name Wait -Value ({
        param($Seconds)
        $state.Waited += $Seconds
        if ($state.OnWait) { & $state.OnWait $state.Waited $state }
    }.GetNewClosure())
    return $state
}
