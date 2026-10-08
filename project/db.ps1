param(
    [string]$path    = "C:\Users\User\OneDrive\桌面\semester 1\website\582_A3\project\database.sql",
    [string]$Dbhost     = "127.0.0.1",
    [int]   $port     = 3307,
    [string]$user     = "root",
    [string]$pw = "ray10506",
    [string]$DbName     = "",  
    [string]$MysqlExe   = "mysql",
    [string]$Container  = "my-mysql"
)

if (-not (Test-Path $path)) { Write-Error "找不到 $path"; exit 1 }

if (-not $pw) {
    $secure = Read-Host "MySQL password for $user" -AsSecureString
    $pw = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
}

$full = (Resolve-Path $path).Path
$dir  = Split-Path $full -Parent
$leaf = Split-Path $full -Leaf

docker cp $full "${Container}:/tmp/$leaf"
docker exec -e MYSQL_PWD=$pw $Container mysql -u $user $DbName -e "source /tmp/$leaf"
$code = $LASTEXITCODE

if ($code -ne 0) { Write-Error "SQL 執行失敗(exit code $code)"; exit 1 }
Write-Host "Done: $path"