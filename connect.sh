#!/usr/bin/expect -f

set timeout 20

set IPaddress [lindex $argv 0]
set Port [lindex $argv 1]
set Diagnostics [expr {$Port ne ""}]

if {$IPaddress eq ""} {
    puts "Использование: connect IP ?PORT?"
    exit 1
}

# Учётные данные из установщика
set CredentialsFile [file join $env(HOME) ".config" "connect" "credentials.conf"]
if {![file exists $CredentialsFile]} {
    puts "Ошибка: учётные данные не найдены. Запустите install.sh"
    exit 1
}
source $CredentialsFile
set EnablePassword "zxr10"

set Proto "telnet"
set Username $PersonalUser
set Password $PersonalPassword

# Списки оборудования
set zte_c610 {
    1.1.23.201 1.1.23.202 1.1.23.203 1.1.23.204
}

set cdata_all {
    1.1.23.194 1.1.23.195 1.1.23.197 1.1.23.198 1.1.23.199
    1.1.23.234 1.1.23.235 1.1.23.236 1.1.23.238 1.1.23.239
    1.1.23.240 1.1.23.241 1.1.23.242 1.1.23.244 1.1.23.245
    1.1.23.247 1.1.23.248 1.1.23.249 1.1.23.251 1.1.23.252
    1.1.23.253 1.1.23.254
}

set eltex_ma4000 {
    1.1.23.200
}

# Определение протокола и авторизации
if {$IPaddress in $zte_c610} {
    set Proto "ssh"

} elseif {$IPaddress in $cdata_all} {
    set Proto "ssh"
    set Username $AdminUser

    if {$IPaddress eq "1.1.23.244"} {
        set Password $SpecialPassword
    } else {
        set Password $AdminPassword
    }

} elseif {$IPaddress in $eltex_ma4000} {
    set Proto "telnet"
    set Username $AdminUser
    set Password $AdminPassword
}

# Определение оборудования
set DeviceType "unknown"

if {$IPaddress in $cdata_all} {
    set DeviceType "cdata"

} elseif {$IPaddress in $eltex_ma4000} {
    set DeviceType "eltex_ma4000"

} elseif {$IPaddress in $zte_c610} {
    set DeviceType "zte_c610"

} elseif {$Port ne ""} {

    if {[regexp -nocase {^(fa|gi)[0-9]+/[0-9]+/[0-9]+$} $Port]} {
        set DeviceType "eltex_mes"

    } elseif {[regexp {^[0-9]+/[0-9]+/[0-9]+:[0-9]+$} $Port]} {
        set DeviceType "zte_c320"

    } elseif {[regexp {^[0-9]+/[0-9]+/[0-9]+/[0-9]+$} $Port]} {
        set DeviceType "cdata"

    } elseif {[regexp {^[0-9]+/[0-9]+/[0-9]+$} $Port]} {
        set DeviceType "snr"

    } elseif {[regexp {^[0-9]+/[0-9]+$} $Port]} {
        set DeviceType "eltex_ltp"

    } elseif {[regexp {^[0-9]+$} $Port]} {
        set DeviceType "zyxel"
    }
}

# Проверка порта
if {$Diagnostics} {

    switch -- $DeviceType {

        cdata {
            if {![regexp {^0/([0-9]+)/([0-9]+)/([0-9]+)$} $Port -> Slot Branch Onu]} {
                puts "Ошибка: для C-DATA нужен порт 0/слот/ветка/ONU"
                exit 1
            }
        }

        eltex_ma4000 {
            if {![regexp {^[0-9]+/[0-9]+/[0-9]+$} $Port]} {
                puts "Ошибка: для MA4000 нужен порт слот/ветка/ONU"
                exit 1
            }
        }

        zte_c610 -
        zte_c320 {
            if {![regexp {^[0-9]+/[0-9]+/[0-9]+:[0-9]+$} $Port]} {
                puts "Ошибка: для ZTE нужен порт карта/слот/ветка:ONU"
                exit 1
            }
        }

        unknown {
            puts "Формат порта будет проверен после подключения"
        }
    }

    puts "Тип оборудования: $DeviceType"
    puts "Порт: $Port"
}

# Универсальное ожидание приглашения CLI
proc WaitPrompt {} {
    expect {
        -re {(?m)^[^\r\n]*[>#]\s*$} {
            return 1
        }
        timeout {
            return 0
        }
        eof {
            puts "Соединение закрыто"
            exit 1
        }
    }
}

# Подключение
if {$Proto eq "ssh"} {

    spawn ssh -o StrictHostKeyChecking=no \
              -o UserKnownHostsFile=/dev/null \
              -o KexAlgorithms=+diffie-hellman-group1-sha1,diffie-hellman-group14-sha1 \
              -o HostKeyAlgorithms=+ssh-rsa \
              -o Ciphers=+aes128-cbc,3des-cbc \
              $Username@$IPaddress

    expect {
        -re {(?i)password:\s*$} {
            send -- "$Password\r"
        }

        "Connection refused" {
            puts "Ошибка: SSH отклонён"
            exit 1
        }

        timeout {
            puts "Истекло время ожидания SSH"
            exit 1
        }

        eof {
            puts "SSH-соединение закрыто"
            exit 1
        }
    }

} else {

    spawn telnet $IPaddress

    expect {
        -exact "Username:" {
            send -- "$Username\r"
        }

        -re {(?i)login:} {
            send -- "$Username\r"
        }

        -re {(?i)user name:} {
            send -- "$Username\r"
        }

        "invalid" {
            puts "Ошибка подключения"
            exit 1
        }

        timeout {
            puts "Истекло время ожидания логина"
            exit 1
        }

        eof {
            puts "Telnet-соединение закрыто"
            exit 1
        }
    }

    expect {
        -exact "Password:" {
            send -- "$Password\r"
        }

        timeout {
            puts "Истекло время ожидания пароля"
            exit 1
        }

        eof {
            puts "Telnet-соединение закрыто"
            exit 1
        }
    }
}

# Проверяем успешность авторизации
set LoginOk 0
set Privileged 0

expect {
    -re {(?m)^[^\r\n]*#\s*$} {
        set LoginOk 1
        set Privileged 1
    }

    -re {(?m)^[^\r\n]*>\s*$} {
        set LoginOk 1
    }

    -re {(?i)(permission denied|authentication failed|login incorrect)} {
        puts "Ошибка авторизации"
        exit 1
    }

    -re {(?i)password:\s*$} {
        puts "Пароль отклонён устройством"
        exit 1
    }

    timeout {
        puts "Не дождались приглашения CLI после авторизации"
        exit 1
    }

    eof {
        puts "Соединение закрыто"
        exit 1
    }
}

# Переход в enable для ZTE C320/C610
if {$DeviceType eq "zte_c320" || $DeviceType eq "zte_c610"} {

    if {!$Privileged} {

        puts "\nПереход в enable на ZTE"
        send -- "enable\r"

        expect {
            -exact "Password:" {
                send -- "$EnablePassword\r"

                expect {
                    -re {(?m)^[^\r\n]*#\s*$} {
                        set Privileged 1
                        puts "Режим enable активирован"
                    }

                    -re {(?i)(incorrect|invalid|denied|password:)} {
                        puts "Ошибка пароля enable"
                        exit 1
                    }

                    timeout {
                        puts "Не удалось перейти в enable"
                        exit 1
                    }

                    eof {
                        puts "Соединение закрыто"
                        exit 1
                    }
                }
            }

            -re {(?m)^[^\r\n]*#\s*$} {
                set Privileged 1
                puts "Режим enable активирован"
            }

            timeout {
                puts "Не дождались запроса пароля enable"
                exit 1
            }

            eof {
                puts "Соединение закрыто"
                exit 1
            }
        }
    }
}

# C-DATA: enable -> config
if {$DeviceType eq "cdata"} {

    if {!$Privileged} {

        send -- "enable\r"

        if {![WaitPrompt]} {
            puts "Не удалось перейти в enable на C-DATA"
            exit 1
        }
    }

    send -- "config\r"

    if {![WaitPrompt]} {
        puts "Не удалось перейти в config на C-DATA"
        exit 1
    }
}

# Имена физических интерфейсов из первого столбца таблицы MES.
proc ParseSwitchPorts {output} {
    regsub -all {\x1b\[[0-?]*[ -/]*[@-~]} $output "" output
    set ports [list]
    foreach line [split $output "\n"] {
        if {[regexp -nocase {^\s*([a-z]+[0-9]+(?:/[0-9]+)+)\s+} $line -> port]} {
            if {[lsearch -nocase -exact $ports $port] < 0} {
                lappend ports $port
            }
        }
    }
    return $ports
}

# Проверяем порт по оборудованию, а не по формату аргумента.
if {$Diagnostics && $DeviceType in {eltex_mes snr unknown}} {
    puts "\nПолучение списка интерфейсов: show interface status"
    set InterfaceOutput ""
    set InterfaceComplete 0
    send -- "show interface status\r"
    expect {
        -re {--More--|---- More ----} {
            append InterfaceOutput $expect_out(buffer)
            send -- " "
            exp_continue
        }
        -re {(?m)^[^\r\n]*[>#]\s*$} {
            append InterfaceOutput $expect_out(buffer)
            set InterfaceComplete 1
        }
        full_buffer {
            append InterfaceOutput $expect_out(buffer)
            exp_continue
        }
        timeout {
            puts "Не удалось дождаться завершения show interface status"
        }
        eof {
            puts "Соединение закрыто"
            exit 1
        }
    }

    set AvailablePorts [ParseSwitchPorts $InterfaceOutput]
    if {!$InterfaceComplete || [llength $AvailablePorts] == 0} {
        puts "Не удалось проверить порт по таблице интерфейсов. Переход в интерактивный режим."
        set Diagnostics 0
    } else {
        while {1} {
            set PortIndex [lsearch -nocase -exact $AvailablePorts $Port]
            if {$PortIndex >= 0} {
                set Port [lindex $AvailablePorts $PortIndex]
                puts "Выбран порт: $Port"
                break
            }
            puts "Порт «$Port» не найден на коммутаторе."
            puts "Примеры доступных портов: [join [lrange $AvailablePorts 0 9] {, }]"
            puts -nonewline "Введите порт или нажмите Enter для перехода в интерактивный режим: "
            flush stdout
            # Читаем локальный ввод, не отправляя его оборудованию.
            if {[gets stdin Port] < 0 || [string trim $Port] eq ""} {
                set Diagnostics 0
                puts "Выбор порта отменён. Переход в интерактивный режим."
                break
            }
            set Port [string trim $Port]
        }
    }
}

# Формирование команд диагностики
set Commands [list]
set CommandMessages [list]

if {$Diagnostics} {

    switch -- $DeviceType {

        cdata {
            set CommandMessages [list \
                "Выбор интерфейса GPON" \
                "Состояние ONU" \
                "Оптические параметры ONU" \
                "Состояние Ethernet-портов абонента" \
            ]
            set Commands [list \
                "interface gpon 0/$Slot" \
                "show ont run-info $Branch $Onu" \
                "show ont optical-info $Branch $Onu" \
                "show ont port state $Branch $Onu eth all" \
            ]
        }

        zte_c320 {
            set CommandMessages [list \
                "Состояние ONU" \
                "Состояние Ethernet-портов абонента" \
                "Оптическое затухание линии" \
                "MAC-адрес абонента" \
            ]
            set OnuInterface "gpon-onu_$Port"

            set Commands [list \
                "show gpon onu detail-info $OnuInterface" \
                "show gpon remote-onu interface eth $OnuInterface" \
                "show pon power attenuation $OnuInterface" \
                "show mac-real-time gpon onu $OnuInterface" \
            ]
        }

        zte_c610 {
            set CommandMessages [list \
                "Состояние ONU" \
                "Состояние Ethernet-портов абонента" \
                "MAC-адрес абонента" \
                "Оптическое затухание линии" \
            ]
            set OnuInterface "gpon_onu-$Port"

            # Преобразование 1/3/1:19 -> 1/3/1.19:1
            set Parts [split $Port ":"]
            set PonPath [lindex $Parts 0]
            set OnuId [lindex $Parts 1]
            set Vport "$PonPath.$OnuId:1"

            set Commands [list \
                "show gpon onu detail-info $OnuInterface" \
                "show gpon remote-onu interface eth $OnuInterface" \
                "show mac interface vport-$Vport" \
                "show pon power attenuation $OnuInterface" \
            ]
        }

        eltex_ma4000 {
            set CommandMessages [list \
                "Состояние ONT" \
                "Состояние портов ONT" \
                "MAC-адрес абонента" \
            ]
            set Commands [list \
                "show interface ont $Port state" \
                "show interface ont $Port ports" \
                "show mac interface ont $Port" \
            ]
        }

        default {
            puts "Автоматическая диагностика для $DeviceType пока не настроена"
        }
    }
}

# Выполнение диагностики
if {[llength $Commands] > 0} {

    puts "\nДиагностика $DeviceType: $Port"

    foreach Command $Commands Message $CommandMessages {

        puts "\n$Message"
        puts "\n>>> $Command"
        send -- "$Command\r"

        expect {
            -re {--More--|---- More ----} {
                send -- " "
                exp_continue
            }

            -re {(?m)^[^\r\n]*[>#]\s*$} {
                # Пауза для чтения результата, включая последнюю команду.
                after 3000
            }

            timeout {
                puts "Тайм-аут команды: $Command"
                break
            }

            eof {
                puts "Соединение закрыто"
                exit 1
            }
        }
    }

    puts "\nАвтоматическая диагностика завершена"
}

# Один переход в интерактивную консоль
interact
