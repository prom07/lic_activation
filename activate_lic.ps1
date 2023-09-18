$TOOLS="C:\Program Files\1C\1CE\components\1c-enterprise-ring-0.19.5+12-x86_64" #Директория с утилитой ring
$LICDIR = "C:\ProgramData\1C\licenses" #Директория с файлами лицензий
$dt=(Get-Date -Format "yyyy-MM-dd")
$path_in="C:\ProgramData\1C\licenses\lic_in" #Файлы с данными для активации лицензий
$path_out="C:\ProgramData\1C\licenses\lic_out" #Путь для выгрузки данных для активации лицензий
$result = " license activate " #Строка для хранения переменных
$cluster="c7bc162c-d678-243f-b00a-a436302f6293"
$bin="C:\Program Files\1cv8\8.3.22.1529\bin"
$cls="srv-cls" #Центральный сервер в кластере 1С

Start-Transcript -Path $LICDIR\tech_log_activ_lic_$dt.txt

Write-Output "$($(Get-Date).toString()) Скрипт запущен" >> $LICDIR\lic_activ_$dt.log

#Получаем список лицензий из подготовленных текстовых файлов
$files = Get-ChildItem -Path $path_in -Recurse -Include "*.txt" | ForEach-Object { $_.FullName }

#Переходим в папку с утилитой ring
Set-Location -Path $TOOLS

#Активация лицензий
foreach($file in $files){
    $Serial=($(Select-String -Path $file -Pattern "Serial") -split ': ')[1]
    $Pin=($(Select-String -Path $file -Pattern "Pin") -split ': ')[1]
    $Oldpin=($(Select-String -Path $file -Pattern "Oldpin") -split ': ')[1]
    $File_name=($(Select-String -Path $file -Pattern "File_name") -split ': ')[1]
    $First_name=($(Select-String -Path $file -Pattern "First_name") -split ': ')[1]
    $Middle_name=($(Select-String -Path $file -Pattern "Middle_name") -split ': ')[1]
    $Last_name=($(Select-String -Path $file -Pattern "Last_name") -split ': ')[1]
    $Email=($(Select-String -Path $file -Pattern "Email") -split ': ')[1]
    $Company=($(Select-String -Path $file -Pattern "Company") -split ': ')[1]
    $Country=($(Select-String -Path $file -Pattern "Country") -split ': ')[1]
    $ZIPcode=($(Select-String -Path $file -Pattern "ZIPcode") -split ': ')[1]
    $Region=($(Select-String -Path $file -Pattern "Region") -split ': ')[1]
    $Town=($(Select-String -Path $file -Pattern "Town") -split ': ')[1]
    $Street=($(Select-String -Path $file -Pattern "Street") -split ': ')[1]
    $House=($(Select-String -Path $file -Pattern "House") -split ': ')[1]
    $Building=($(Select-String -Path $file -Pattern "Building") -split ': ')[1]
    $arg = @{'--serial'="$Serial"; '--path'="$LICDIR"; '--pin'="$Pin"; '--previous-pin'="$Oldpin"; '--first-name'="$First_name"; '--middle-name'="$Middle_name"; '--last-name'="$Last_name"; '--email'="$Email"; '--company'="$Company"; '--country'="$Country"; '--region'="$Region"; '--town'="$Town"; '--street'="$Street"; '--house'="$House"; '--building'="$Building"; '--zip-code'="$ZIPcode"; '--send-statistics'='false'}
    # Проверяем каждую переменную, если она не пустая, добавляем ее в строку
    foreach ($key in $arg.Keys){
        $value = $arg[$key]
        if ($value) {
            $result += "$key ""$value"" "
        }
    }
    Write-Output "$result" >> $LICDIR\license_activate_$dt.log
    Start-Process -FilePath $TOOLS\ring.cmd -RedirectStandardOutput $LICDIR\output.txt -ArgumentList "$result" -NoNewWindow >> $LICDIR\lic_activ_$dt.log
    Start-Sleep 2
}

Write-Output "$($(Get-Date).toString()) Активация окончена" >> $LICDIR\lic_activ_$dt.log


if (!(Test-Path "\\srv-002\C`$\ProgramData\1C\licenses\old_lic\")){
    New-Item -Path "\\srv-002\C`$\ProgramData\1C\licenses\old_lic" -ItemType Directory
}

if (!(Test-Path "C:\ProgramData\1C\licenses\old_lic\")){
    New-Item -Path "C:\ProgramData\1C\licenses\old_lic" -ItemType Directory
}

#Удаляем файлы лицензий со старого сервера лицензий
foreach ($license in $licenses){
    $filelic=$license.Substring(27,18)
    if (Test-Path "\\srv-002\C`$\ProgramData\1C\licenses\$filelic"){
        Write-Output "Переносим файлы лицензий в папку old_lic" >> $LICDIR\lic_activ_$dt.log
        Move-Item -Path "\\srv-002\C`$\ProgramData\1C\licenses\$filelic" -Destination "\\srv-002\C$\ProgramData\1C\licenses\old_lic\$filelic" -Force
    }
}

#Удаляем файлы профиля
Remove-Item -Path "\\srv-002\C`$\ProgramData\1C\1cv8\*.pfl" -Force
Remove-Item -Path "C:\ProgramData\1C\1cv8\*.pfl" -Force

#Переносим файлы с информацией о лицензиях в lic_old
Move-Item -Path "$path_in\*.txt" -Destination "$LICDIR\old_lic\" -Force
Move-Item -Path "\\srv-002\C`$\ProgramData\1C\licenses\lic_txt\*.txt" -Destination "\\srv-002\C$\ProgramData\1C\licenses\old_lic\" -Force


#Создаем новые файлы с информацией о лицензиях

$license=@(ring license list)
foreach ($lic in $license) {
    [string[]] $rez=@()
    $name=$lic.Substring(0,26)
    $seriallic=$lic.Substring(16,10)
    $oldpinlic=$lic.Substring(0,15)
    $file_name=$lic.Substring(40,18)
    $rez+="Serial: $seriallic"
    $rez+="Pin: "
    $rez+="Oldpin: $oldpinlic"
    $rez+="File_name: $file_name"
    $dr=$(ring license info --name $name)
    $First_name=($(Write-Output $dr | Select-String -Pattern "First name") -split ': ')[1]
    $rez+="First_name: $First_name"
    $Middle_name=($(Write-Output $dr | Select-String -Pattern "Middle name") -split ': ')[1]
    $rez+="Middle_name: $Middle_name"
    $Last_name=($(Write-Output $dr | Select-String -Pattern "Last name") -split ': ')[1]
    $rez+="Last_name: $Last_name"
    $Email=($(Write-Output $dr | Select-String -Pattern "Email") -split ': ')[1]
    $rez+="Email: $Email"
    $Company=($(Write-Output $dr | Select-String -Pattern "Company") -split ': ')[1]
    $rez+="Company: $Company"
    $Country=($(Write-Output $dr | Select-String -Pattern "Country") -split ': ')[1]
    $rez+="Country: $Country"
    $ZIPcode=($(Write-Output $dr | Select-String -Pattern "ZIP code") -split ': ')[1]
    $rez+="ZIPcode: $ZIPcode"
    $Region=($(Write-Output $dr | Select-String -Pattern "Region") -split ': ')[1]
    $rez+="Region: $Region"
    $Town=($(Write-Output $dr | Select-String -Pattern "Town") -split ': ')[1]
    $rez+="Town: $Town"
    $Street=($(Write-Output $dr | Select-String -Pattern "Street") -split ': ')[1]
    $rez+="Street: $Street"
    $House=($(Write-Output $dr | Select-String -Pattern "House") -split ': ')[1]
    $rez+="House: $House"
    $Building=($(Write-Output $dr | Select-String -Pattern "Building") -split ': ')[1]
    $rez+="Building: $Building"
    $Count=($(Write-Output $dr | Select-String -Pattern "Description") -split ' ')[10]
    $rez+="Count_lic: $Count"
    #Сохраняем результат в файл
    Write-Output $rez | Out-File $path_out\$seriallic-$oldpinlic.txt
}

Write-Output "$($(Get-Date).toString()) Работа скрипта окончена" >> $LICDIR\lic_activ_$dt.log
Write-Output $("-" * 100) >> $LICDIR\lic_activ_$dt.log

$TOOLS="C:\Program Files\1C\1CE\components\1c-enterprise-ring-0.19.5+12-x86_64" #Директория с утилитой ring
$LICDIR = "C:\ProgramData\1C\licenses" #Директория с файлами лицензий
$dt=(Get-Date -Format "yyyy-MM-dd")
$path_in="C:\ProgramData\1C\licenses\lic_in" #Файлы с данными для активации лицензий
$path_out="C:\ProgramData\1C\licenses\lic_out" #Путь для выгрузки данных для активации лицензий
$result = " license activate " #Строка для хранения переменных

Start-Transcript -Path $LICDIR\tech_log_activ_lic_$dt.txt

Write-Output "$($(Get-Date).toString()) Скрипт запущен" >> $LICDIR\lic_activ_$dt.log

#Получаем список лицензий из подготовленных текстовых файлов
$files = Get-ChildItem -Path $path_in -Recurse -Include "*.txt" | ForEach-Object { $_.FullName }

#Переходим в папку с утилитой ring
Set-Location -Path $TOOLS

#Активация лицензий
foreach($file in $files){
    $Serial=($(Select-String -Path $file -Pattern "Serial") -split ': ')[1]
    $Pin=($(Select-String -Path $file -Pattern "Pin") -split ': ')[1]
    $Oldpin=($(Select-String -Path $file -Pattern "Oldpin") -split ': ')[1]
    $File_name=($(Select-String -Path $file -Pattern "File_name") -split ': ')[1]
    $First_name=($(Select-String -Path $file -Pattern "First_name") -split ': ')[1]
    $Middle_name=($(Select-String -Path $file -Pattern "Middle_name") -split ': ')[1]
    $Last_name=($(Select-String -Path $file -Pattern "Last_name") -split ': ')[1]
    $Email=($(Select-String -Path $file -Pattern "Email") -split ': ')[1]
    $Company=($(Select-String -Path $file -Pattern "Company") -split ': ')[1]
    $Country=($(Select-String -Path $file -Pattern "Country") -split ': ')[1]
    $ZIPcode=($(Select-String -Path $file -Pattern "ZIPcode") -split ': ')[1]
    $Region=($(Select-String -Path $file -Pattern "Region") -split ': ')[1]
    $Town=($(Select-String -Path $file -Pattern "Town") -split ': ')[1]
    $Street=($(Select-String -Path $file -Pattern "Street") -split ': ')[1]
    $House=($(Select-String -Path $file -Pattern "House") -split ': ')[1]
    $Building=($(Select-String -Path $file -Pattern "Building") -split ': ')[1]
    $arg = @{'--serial'="$Serial"; '--path'="$LICDIR"; '--pin'="$Pin"; '--previous-pin'="$Oldpin"; '--first-name'="$First_name"; '--middle-name'="$Middle_name"; '--last-name'="$Last_name"; '--email'="$Email"; '--company'="$Company"; '--country'="$Country"; '--region'="$Region"; '--town'="$Town"; '--street'="$Street"; '--house'="$House"; '--building'="$Building"; '--zip-code'="$ZIPcode"; '--send-statistics'='false'}
    # Проверяем каждую переменную, если она не пустая, добавляем ее в строку
    foreach ($key in $arg.Keys){
        $value = $arg[$key]
        if ($value) {
            $result += "$key ""$value"" "
        }
    }
    Write-Output "$result" >> $LICDIR\license_activate_$dt.log
    Start-Process -FilePath $TOOLS\ring.cmd -RedirectStandardOutput $LICDIR\output.txt -ArgumentList "$result" -NoNewWindow >> $LICDIR\lic_activ_$dt.log
    Start-Sleep 2
}

Write-Output "$($(Get-Date).toString()) Активация окончена" >> $LICDIR\lic_activ_$dt.log


if (!(Test-Path "\\srv-002\C`$\ProgramData\1C\licenses\old_lic\")){
    New-Item -Path "\\srv-002\C`$\ProgramData\1C\licenses\old_lic" -ItemType Directory
}

if (!(Test-Path "C:\ProgramData\1C\licenses\old_lic\")){
    New-Item -Path "C:\ProgramData\1C\licenses\old_lic" -ItemType Directory
}

#Удаляем файлы лицензий со старого сервера лицензий
foreach ($license in $licenses){
    $filelic=$license.Substring(27,18)
    if (Test-Path "\\srv-002\C`$\ProgramData\1C\licenses\$filelic"){
        Write-Output "Переносим файлы лицензий в папку old_lic" >> $LICDIR\lic_activ_$dt.log
        Move-Item -Path "\\srv-002\C`$\ProgramData\1C\licenses\$filelic" -Destination "\\srv-002\C$\ProgramData\1C\licenses\old_lic\$filelic" -Force
    }
}

#Удаляем файлы профиля
Remove-Item -Path "\\srv-002\C`$\ProgramData\1C\1cv8\*.pfl" -Force
Remove-Item -Path "C:\ProgramData\1C\1cv8\*.pfl" -Force

#Переносим файлы с информацией о лицензиях в lic_old
Move-Item -Path "$path_in\*.txt" -Destination "$LICDIR\old_lic\" -Force
Move-Item -Path "\\srv-002\C`$\ProgramData\1C\licenses\lic_txt\*.txt" -Destination "\\srv-002\C$\ProgramData\1C\licenses\old_lic\" -Force


#Создаем новые файлы с информацией о лицензиях

$license=@(ring license list)
foreach ($lic in $license) {
    [string[]] $rez=@()
    $name=$lic.Substring(0,26)
    $seriallic=$lic.Substring(16,10)
    $oldpinlic=$lic.Substring(0,15)
    $file_name=$lic.Substring(40,18)
    $rez+="Serial: $seriallic"
    $rez+="Pin: "
    $rez+="Oldpin: $oldpinlic"
    $rez+="File_name: $file_name"
    $dr=$(ring license info --name $name)
    $First_name=($(Write-Output $dr | Select-String -Pattern "First name") -split ': ')[1]
    $rez+="First_name: $First_name"
    $Middle_name=($(Write-Output $dr | Select-String -Pattern "Middle name") -split ': ')[1]
    $rez+="Middle_name: $Middle_name"
    $Last_name=($(Write-Output $dr | Select-String -Pattern "Last name") -split ': ')[1]
    $rez+="Last_name: $Last_name"
    $Email=($(Write-Output $dr | Select-String -Pattern "Email") -split ': ')[1]
    $rez+="Email: $Email"
    $Company=($(Write-Output $dr | Select-String -Pattern "Company") -split ': ')[1]
    $rez+="Company: $Company"
    $Country=($(Write-Output $dr | Select-String -Pattern "Country") -split ': ')[1]
    $rez+="Country: $Country"
    $ZIPcode=($(Write-Output $dr | Select-String -Pattern "ZIP code") -split ': ')[1]
    $rez+="ZIPcode: $ZIPcode"
    $Region=($(Write-Output $dr | Select-String -Pattern "Region") -split ': ')[1]
    $rez+="Region: $Region"
    $Town=($(Write-Output $dr | Select-String -Pattern "Town") -split ': ')[1]
    $rez+="Town: $Town"
    $Street=($(Write-Output $dr | Select-String -Pattern "Street") -split ': ')[1]
    $rez+="Street: $Street"
    $House=($(Write-Output $dr | Select-String -Pattern "House") -split ': ')[1]
    $rez+="House: $House"
    $Building=($(Write-Output $dr | Select-String -Pattern "Building") -split ': ')[1]
    $rez+="Building: $Building"
    $Count=($(Write-Output $dr | Select-String -Pattern "Description") -split ' ')[10]
    $rez+="Count_lic: $Count"
    #Сохраняем результат в файл
    Write-Output $rez | Out-File $path_out\$seriallic-$oldpinlic.txt
}

#После этого в файл licenses.txt необходимо вручную внести новые pin-коды и скопировать его на dr-1clicense001

Set-Location -Path $bin
#Список кластеров на центральном сервере
#.\rac.exe cluster list $cls:1545
#Список серверов в кластере 
#.\rac.exe server list --cluster=$cluster $cls:1545
#Список ТНФ на сервере
#.\rac.exe rule --cluster=$cluster list --server=878c43bd-c1da-4d95-8f59-7492deeedb81 $cls:1545
#Обновление правил ТНФ
.\rac.exe rule --cluster=$cluster update --server=878c43bd-c1da-4d95-8f59-7492deeedb81 --rule=087285dd-a161-4f67-86af-1e1b676ea6c3 --position=0 --rule-type=always --priority=0 $cls:1545
.\rac.exe rule --cluster=$cluster update --server=678sdg45-k2sv-5g23-4f56-8986lkjlkb49 --rule=857987sd-j223-5das-23ff-123sf6esf633 --position=1 --rule-type=always --priority=0 $cls:1545
#Применение ТНФ полное
.\rac.exe rule --cluster=$cluster apply --full $cls:1545

Stop-Transcript


Write-Output "$($(Get-Date).toString()) Работа скрипта окончена" >> $LICDIR\lic_activ_$dt.log
Write-Output $("-" * 100) >> $LICDIR\lic_activ_$dt.log
Stop-Transcript