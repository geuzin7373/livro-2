param(
    [int]$Port = 8000
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$prefix = "http://localhost:$Port/"

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".js" = "text/javascript; charset=utf-8"
    ".css" = "text/css; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".webmanifest" = "application/manifest+json; charset=utf-8"
    ".png" = "image/png"
    ".jpg" = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".gif" = "image/gif"
    ".mp3" = "audio/mpeg"
    ".ogg" = "audio/ogg"
    ".mp4" = "video/mp4"
    ".webm" = "video/webm"
}

function Get-ContentType($path) {
    $extension = [System.IO.Path]::GetExtension($path).ToLowerInvariant()
    if ($mimeTypes.ContainsKey($extension)) {
        return $mimeTypes[$extension]
    }

    return "application/octet-stream"
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()

Write-Host "Servidor PWA rodando em $prefix"
Write-Host "Pressione Ctrl+C para parar."

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $requestPath = [System.Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart("/"))

        if ([string]::IsNullOrWhiteSpace($requestPath)) {
            $requestPath = "index.html"
        }

        $candidate = Join-Path $root $requestPath
        $fullPath = [System.IO.Path]::GetFullPath($candidate)

        if (-not $fullPath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
            $context.Response.StatusCode = 403
            $context.Response.Close()
            continue
        }

        if ((Test-Path -LiteralPath $fullPath -PathType Container)) {
            $fullPath = Join-Path $fullPath "index.html"
        }

        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            $context.Response.StatusCode = 404
            $context.Response.Close()
            continue
        }

        $context.Response.ContentType = Get-ContentType $fullPath
        $context.Response.Headers.Set("Cache-Control", "no-cache")

        if ([System.IO.Path]::GetFileName($fullPath).Equals("sw.js", [System.StringComparison]::OrdinalIgnoreCase)) {
            $context.Response.Headers.Set("Service-Worker-Allowed", "/")
        }

        $stream = [System.IO.File]::OpenRead($fullPath)
        try {
            $context.Response.ContentLength64 = $stream.Length
            $stream.CopyTo($context.Response.OutputStream)
        }
        finally {
            $stream.Dispose()
            $context.Response.OutputStream.Close()
        }
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
