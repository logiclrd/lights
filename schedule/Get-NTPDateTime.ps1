<#
Majority of code is from:
Chris Warwick, @cjwarwickps, August 2012
chrisjwarwick.wordpress.com

Modernized by Jonathan Gilbert
#>

param
(
	[string] $sNTPServer = "pool.ntp.org"
)

$StartOfEpoch = [DateTime]::new(1900, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
[byte[]]$NtpData = ,0 * 48
$NtpData[0] = 0x1B # NTP Request header in first byte
$Socket = [System.Net.Sockets.Socket]::new("InterNetwork", "Dgram", "Udp")
$Socket.Connect($sNTPServer, 123)

$t1 = [DateTime]::UtcNow # Start of transaction... the clock is ticking...
[void]$Socket.Send($NtpData)
[void]$Socket.Receive($NtpData)
$t4 = [DateTime]::UtcNow # End of transaction time
$Socket.Close()

# t3
$IntPart = [BitConverter]::ToUInt32($NtpData[43..40], 0)
$FracPart = [BitConverter]::ToUInt32($NtpData[47..44], 0)
$t3ms = $IntPart * 1000 + $FracPart * 1000 / 0x100000000

# t2
$IntPart = [BitConverter]::ToUInt32($NtpData[35..32], 0)
$FracPart = [BitConverter]::ToUInt32($NtpData[39..36], 0)
$t2ms = $IntPart * 1000 + $FracPart * 1000 / 0x100000000

$t1ms = ($t1 - $StartOfEpoch).TotalMilliseconds
$t4ms = ($t4 - $StartOfEpoch).TotalMilliseconds

$Offset = (($t2ms - $t1ms) + ($t3ms - $t4ms)) / 2

Write-Output $StartOfEpoch.AddMilliseconds($t4ms + $Offset)


