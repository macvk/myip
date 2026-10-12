# My IP

The clients show your public IPv4 and IPv6 addresses, country, and ASN. They also try usable local source addresses to detect additional public routes.

## POSIX shell

The shell client requires `curl` and standard Unix networking tools.

1. Download `myip.sh`:

```sh
curl -fLO https://raw.githubusercontent.com/macvk/myip/master/myip.sh
chmod +x myip.sh
```

2. Run it:

```sh
./myip.sh
```

## Python

The Python client requires Python 3 and uses only the standard library.

```sh
curl -fLO https://raw.githubusercontent.com/macvk/myip/master/myip.py
python3 myip.py
```

On Windows, run `python myip.py`.

## Go

The Go client uses only the standard library.

```sh
curl -fLO https://raw.githubusercontent.com/macvk/myip/master/myip.go
go build -o myip myip.go
./myip
```

On Windows:

```bat
go build -o myip.exe myip.go
myip.exe
```

## Windows batch file

The batch client requires Windows PowerShell and `curl.exe`.

```powershell
powershell -command "& { (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/macvk/myip/master/myip.bat', 'myip.bat') }"
```

```bat
myip.bat
```
