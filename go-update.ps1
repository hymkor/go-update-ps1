function Get-GoZipUrl($web_client){
    $download_page = $web_client.DownloadString('https://golang.org/dl/')

    $re = New-Object regex('<a[^>]+href="([^"]*)"')
    $m = $re.Matches($download_page)
    if ( -not $m.Success ) {
        return $null
    }
    $latest_version = 0
    $latest_url = $null
    $m | foreach-object{
        $url = $_.Groups[1].Value
        if ( $url -match 
            "(?:https://golang\.org)?/dl/go(\d+)\.(\d+)(?:\.(\d+))?\.windows-amd64\.zip" ){
            $major = [int]$Matches[1]
            $minor = [int]$Matches[2]
            $patch = [int]$Matches[3]
            if ( $patch -eq $null ){
                $patch = [int]0
            }
            $version = ( $major * 100  + $minor ) * 100 + $patch
            if ( $version -gt $latest_version ){
                $latest_version = $version
                if ( -not ($url -match "^http://") ){
                    $url = "https://golang.org" + $url
                }
                $latest_url = $url
            }
        }
    }
    return @{
        version_number=$latest_version 
        url=$latest_url 
    }
}

function Get-CurrentGoVersion(){
    $go_exe_path = (where.exe go)
    if ($go_exe_path -eq "") {
        return @{
            version_number = "00000"
            goroot="C:\go"
            version_word="0.0.0"
        }
    }
    $last_go_version = (( go version ) -split " ")[2]
    $go_bin = (Split-Path -Parent $go_exe_path)
    $goroot = (Split-Path -Parent $go_bin)

    $s = $last_go_version.SubString(2)
    $s = ($s -split "\.")
    $v = (([int]$s[0] * 100) + [int]$s[1])*100
    if ( $s.Count -ge 3 ) {
        $v = $v + $s[2]
    }
    return @{
        version_number=$v
        goroot=$goroot
        version_word=$last_go_version
    }
}

function download-go($web_client,$url) {
    $filename = (Split-Path -leaf $url)
    Write-Host "Download $url -> $filename"
    $web_client.downloadFile($url,$filename)
    Write-Host "Done"
    return $filename
}

function main(){
    $web_client = New-Object System.Net.WebClient
    $web_client.Headers['User-Agent'] = 'go_update.ps1'

    $cur = (Get-CurrentGoVersion)
    $new = (Get-GoZipUrl $web_client)

    if ( $new -eq $null ){
        return "golang.org not found"
    }

    if ( $cur -ne $null ){
        Write-Host "Installed Version=" $cur.version_number
    }else{
        Write-Host "Installed Version= (not installed)"
    }
    Write-Host " Web Last Version=" $new.version_number

    if ( $cur -ne $null -and $new.version_number -le $cur.version_number ){
        return "Go is not updated."
    }

    if ( $cur -ne $null ){
        $parent = (Split-Path -Parent $cur.goroot)
        $goroot = $cur.goroot
        $goroot_bak = (Join-Path $parent $cur.version_word)
        if (Test-Path $goroot_bak) {
            $goroot_bak = $goroot_bak + "-" +
                (Get-Date -UFormat "%Y%m%d_%H%M%S")
        }
        Write-Host "Rename $goroot to $goroot_bak"
        Move-Item $goroot $goroot_bak
    }else{
        $parent = "C:\"
    }
    $filename = (download-go $web_client $new.url)
    Expand-Archive -Path $filename -DestinationPath $parent
    return $null
}

$err = (main)
if ( $err -ne $null ){
    Write-Host $err
}
