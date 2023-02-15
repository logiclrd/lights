#!/usr/bin/env /powershell/pwsh

Set-Location (Split-Path $MyInvocation.MyCommand.Path)

$NextScheduleReload = [DateTime]::UtcNow

$Initializing = $true

while ($true)
{
	$Now = [DateTime]::Now
	$Today = $Now.Date

	if ([DateTime]::UtcNow -ge $NextScheduleReload)
	{
		$Schedule = [System.Collections.Generic.List[PSCustomObject]]::new()

		$ScheduleDescription = Get-Content "schedule.txt" | % { $_.Trim() }

		$NextScheduleReload = [DateTime]::UtcNow.AddHours(8)

		foreach ($ScheduleLine in $ScheduleDescription)
		{
			if ($ScheduleLine.StartsWith("#")) { continue }
			if ($ScheduleLine -eq "") { continue }

			$Parts = $ScheduleLine.Split(' ')

			$Time = $Parts[0]
			$Control = $Parts[1]
			$Light = $Parts[2]

			$Time = [DateTime]::Parse($Time)
			$Time = $Time - $Time.Date

			$ScheduleItem = [PSCustomObject]::new()

			Add-Member -InputObject $ScheduleItem -MemberType NoteProperty -Name Time -Value $Time
			Add-Member -InputObject $ScheduleItem -MemberType NoteProperty -Name Control -Value $Control
			Add-Member -InputObject $ScheduleItem -MemberType NoteProperty -Name Light -Value $Light

			$Schedule.Add($ScheduleItem)
		}

		$Schedule.Sort([Comparison[PSCustomObject]] { param($a, $b); $a.Time.CompareTo($b.Time) })

		while ($true)
		{
			$NextSwitch = $Today + $Schedule[0].Time

			if ($NextSwitch -ge $Now) { break }

			$Schedule.Add($Schedule[0])
			$Schedule.RemoveAt(0)
		}

		if ($Initializing)
		{
			$Initializing = $false

			Write-Host "Startup: Running through entire script to determine desired initial state"

			$LightState = @($false, $false, $false, $false)

			foreach ($ScheduleItem in $Schedule)
			{
				Write-Host "=> Light $($ScheduleItem.Light) $($ScheduleItem.Control) at $($ScheduleItem.Time)"
				$LightState[$ScheduleItem.Light] = ($ScheduleItem.Control -eq "ON")
			}

			Write-Host "Startup: Setting initial state"

			for ($Light = 0; $Light -lt 4; $Light++)
			{
				$State = $LightState[$Light]

				if ($State)
				{
					Write-Host "=> Light $Light`: ON"
					/lights/control/on $Light
				}
				else
				{
					Write-Host "=> Light $Light`: OFF"
					/lights/control/off $Light
				}
			}
		}
	}

	$Next = $Schedule[0]

	$NearestSwitch = $Today + $Next.Time
	$NearestControl = $Next.Control
	$NearestLight = $Next.Light

	$TimeToNext = $NearestSwitch - $Now

	Write-Host ""
	Write-Host "Current time: $Now"
	Write-Host "Next switch: Turn light # $NearestLight to the $NearestControl state at $NearestSwitch"

	if ($TimeToNext -gt [TimeSpan]::Zero)
	{
		$Delay = $TimeToNext / 2

		if ($Delay.TotalMinutes -lt 5) { $Delay = [TimeSpan]::FromMinutes(5) }
		if ($Delay -gt $TimeToNext) { $Delay = $TimeToNext }

		$DelayMilliseconds = $Delay.TotalMilliseconds

		if ($Delay.TotalSeconds -lt 300)
		{
			Write-Host "Sleeping for $([int]$Delay.TotalSeconds) seconds"
		}
		else
		{
			Write-Host "Sleeping for $([int]$Delay.TotalMinutes) minutes"
		}

		Start-Sleep -Milliseconds ($Delay.TotalMilliseconds)
	}

	$TimeToNext = $NearestSwitch - [DateTime]::Now

	if ($TimeToNext.TotalSeconds -lt 30)
	{
		Write-Host "Sending control $NearestControl to $NearestLight"

		if ($NearestControl -eq "ON") { $Command = "on" } else { $Command = "off" }

		$Command = "/lights/control/$Command"

		. $Command $NearestLight

		if ($TimeToNext -gt [TimeSpan]::Zero)
		{
			Write-Host "Pausing for $($TimeToNext.TotalSeconds) seconds"

			Start-Sleep -Milliseconds ($TimeToNext.TotalMilliseconds)
		}

		$Schedule.Add($Schedule[0])
		$Schedule.RemoveAt(0)
	}
}
