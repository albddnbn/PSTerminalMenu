function Start-ProxyServer {
    param (
        [string]$ListenAddress = "127.0.0.1",
        [int]$ListenPort = 8080
    )
    
    $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Parse($ListenAddress), $ListenPort)
    $listener.Start()
    
    Write-Host "Proxy server started on $ListenAddress : $ListenPort"
    
    while ($true) {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        $buffer = New-Object Byte[] 4096
        $data = ""
        
        while (($bytesRead = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $data += [System.Text.Encoding]::ASCII.GetString($buffer, 0, $bytesRead)
            
            if ($data -match "`r`n`r`n$") {
                # Here you can manipulate and inspect the received request
                # before forwarding it to the original recipient.
                
                # Example: Display the received request
                Write-Host "Received request:"
                Write-Host $data
                
                # Forward the request to the original recipient (not implemented in this example)
                
                # Clear the buffer and data for the next request
                $buffer = New-Object Byte[] 4096
                $data = ""
            }
        }
        
        $client.Close()
    }
}
# .\proxy.ps1 -ListenAddress "127.0.0.1" -ListenPort 8080
