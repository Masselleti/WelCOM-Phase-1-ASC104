<#
.SYNOPSIS
    Local HTTP Server - Pure PowerShell
.DESCRIPTION
    A simple HTTP server that requires no installation.
.NOTES
    Version: 1.0.0
#>

param(
    [int]$Port = 5550,
    [string]$Path = "."
)

function Get-AvailablePort {
    param(
        [int]$PreferredPort = 5550
    )
    
    $testListener = [System.Net.HttpListener]::new()
    try {
        $testListener.Prefixes.Add("http://localhost:$PreferredPort/")
        $testListener.Start()
        $testListener.Stop()
        return $PreferredPort
    }
    catch {
        Write-Host ""
        Write-Host " Port $PreferredPort is in use!" -ForegroundColor Yellow
        Write-Host " Finding available port..." -ForegroundColor Cyan
        
        for ($i = 0; $i -lt 100; $i++) {
            $randomPort = Get-Random -Minimum 5551 -Maximum 10000
            
            try {
                $newListener = [System.Net.HttpListener]::new()
                $newListener.Prefixes.Add("http://localhost:$randomPort/")
                $newListener.Start()
                $newListener.Stop()
                
                Write-Host " Found available port: $randomPort" -ForegroundColor Green
                return $randomPort
            }
            catch {
                continue
            }
        }
        
        throw "Could not find available port after 100 attempts"
    }
}

$Port = Get-AvailablePort -PreferredPort $Port

$Host.UI.RawUI.WindowTitle = "Local HTTP Server - Port $Port"

Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Local HTTP Server v1.0" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

Set-Location $Path
$AbsolutePath = (Get-Location).Path

$http = [System.Net.HttpListener]::new()
$http.Prefixes.Add("http://localhost:$Port/")

try {
    $http.Start()
    
    $url = "http://localhost:$Port"
    Write-Host " Server running at:" -ForegroundColor Green
    Write-Host "  $url" -ForegroundColor Yellow
    Write-Host ""
    Write-Host " Serving folder:" -ForegroundColor Green
    Write-Host "  $AbsolutePath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To stop: Ctrl+C" -ForegroundColor Gray
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    
    Start-Process $url
    
    while ($http.IsListening) {
        $context = $http.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        $timestamp = Get-Date -Format "HH:mm:ss"
        Write-Host "[$timestamp] " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($request.HttpMethod) " -NoNewline -ForegroundColor Cyan
        Write-Host "$($request.Url.LocalPath)" -ForegroundColor White
        
        $requestedPath = $request.Url.LocalPath.TrimStart('/')
        if ([string]::IsNullOrEmpty($requestedPath)) {
            $requestedPath = "index.html"
        }
        
        $filePath = Join-Path $AbsolutePath $requestedPath
        
        if (Test-Path $filePath -PathType Leaf) {
            $content = [System.IO.File]::ReadAllBytes($filePath)
            $response.ContentLength64 = $content.Length
            
            $extension = [System.IO.Path]::GetExtension($filePath)
            $mimeTypes = @{
                '.html' = 'text/html'
                '.css'  = 'text/css'
                '.js'   = 'application/javascript'
                '.json' = 'application/json'
                '.png'  = 'image/png'
                '.jpg'  = 'image/jpeg'
                '.gif'  = 'image/gif'
                '.svg'  = 'image/svg+xml'
                '.ico'  = 'image/x-icon'
                '.txt'  = 'text/plain'
            }
            
            if ($mimeTypes.ContainsKey($extension)) {
                $response.ContentType = $mimeTypes[$extension]
            } else {
                $response.ContentType = 'application/octet-stream'
            }
            
            $response.StatusCode = 200
            $response.OutputStream.Write($content, 0, $content.Length)
        }
        elseif (Test-Path $filePath -PathType Container) {
            $items = Get-ChildItem $filePath | Sort-Object {$_.PSIsContainer}, Name -Descending
            
            $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Index of /$requestedPath</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, sans-serif; margin: 40px; background: #f5f5f5; }
        h1 { color: #333; border-bottom: 3px solid #0078d4; padding-bottom: 10px; }
        table { width: 100%; background: white; border-collapse: collapse; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        th { background: #0078d4; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #eee; }
        tr:hover { background: #f0f0f0; }
        a { color: #0078d4; text-decoration: none; }
        a:hover { text-decoration: underline; }
        .folder::before { content: "📁 "; }
        .file::before { content: "📄 "; }
    </style>
</head>
<body>
    <h1>Index of /$requestedPath</h1>
    <table>
        <tr><th>Name</th><th>Size</th><th>Modified</th></tr>
"@
            
            if ($requestedPath -ne "") {
                $html += "<tr><td><a href='../' class='folder'>..</a></td><td>-</td><td>-</td></tr>"
            }
            
            foreach ($item in $items) {
                $name = $item.Name
                $href = $name
                $size = if ($item.PSIsContainer) { "-" } else { "{0:N0} KB" -f ($item.Length / 1KB) }
                $modified = $item.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
                $class = if ($item.PSIsContainer) { "folder"; $href += "/" } else { "file" }
                
                $html += "<tr><td><a href='$href' class='$class'>$name</a></td><td>$size</td><td>$modified</td></tr>"
            }
            
            $html += "</table></body></html>"
            
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $response.ContentType = 'text/html; charset=utf-8'
            $response.ContentLength64 = $buffer.Length
            $response.StatusCode = 200
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
        }
        else {
            $html = "<html><body><h1>404 - Not Found</h1><p>$requestedPath</p></body></html>"
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $response.ContentType = 'text/html; charset=utf-8'
            $response.ContentLength64 = $buffer.Length
            $response.StatusCode = 404
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
        }
        
        $response.Close()
    }
}
catch {
    Write-Host ""
    Write-Host " Error: $_" -ForegroundColor Red
}
finally {
    $http.Stop()
    Write-Host ""
    Write-Host " Server stopped" -ForegroundColor Yellow
}