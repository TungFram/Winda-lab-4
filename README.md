# Winda-lab-4
***4 лаба по винде, у24 5 семестр.***

### По поводу скрипта:
#### **Протестировал, всё работает!**

###### Важно, чтобы не было старой записи об обработке отказа. Чтобы убрать ее (на обоих серваках), [вот ссылочка](https://social.technet.microsoft.com/Forums/en-US/856a7076-ebb4-40b8-b6ec-8a84dcbd766e/how-to-remove-all-failover-scopes-using-powershell?forum=winserveripamdhcpdns), там в ответе гайд.

Если ролей нет и мы запускаем скрипт с начала, то *будет пару ошибок* о том, что не нашли что-то. Это нормально, я оборачивал их в try-catch, но они все равно выбрасываются, хрен его знает.
Если запускать еще раз, то, вроде, нормально все отрабатывает.

***Каждый шаг я принтил, так что все должно быть понятно что происходит.***

На вход принимает 2 пути: JSON файл к данными о серверах (адрес в локальной сети, адрес 4 версии (у меня просто они различаются),
JSON файл с данными об области, которую создаем в DHCP.
C JSON'ом я так и не разобрался, поэтому хранил все данные в виде хэштаблиц. Эти же таблицы в sourseDataTables, в одну строку, чтобы можно было в консоль PowerShell вбить и не париться.

Собственно, суть его в том, что мы получаем имена серверов по их адресам, потом
проверяем доступ к ним по сети. Если нет доступа, - значит они выключены.

Дальше устанавливаем в любом случае на сервере роль DHCP и его подмодули.
Далее, если это основной сервак, то там создаем область и ее как надо настраиваем;
иначе у нас неосновной сервак, и мы устанавливаем там обработку отказа (failover), чтобы поддерживать отказоустойчивость основного сервера и не дать домену упасть.

Инфа по командлетам и прочему:
+ [Get-ADDomainController и как находить серваки](https://pwsh.ru/get-addomaincontroller-получение-информации-о-контролл/)
+ [Get-ADComputer и как находить все компьютеры в сети](https://winitpro.ru/index.php/2015/09/28/powershell-get-adcomputer-poluchenie-dannyx-o-kompyuterax-v-active-directory/)
+ [Test-NetConnection и как проверять в сети ли комп](https://winitpro.ru/index.php/2016/09/08/tcp-port-ping-s-pomoshhyu-powershell/)
+ [Set-DhcpServerv4OptionValue (как добавить маршрутизатор в политике или адреса DNS & router в облать](https://learn.microsoft.com/en-us/powershell/module/dhcpserver/set-dhcpserverv4optionvalue?view=windowsserver2022-ps)
+ [Как в принципе работать с DHCP](https://winitpro.ru/index.php/2015/11/10/nastrojka-dhcp-servera-s-pomoshhyu-powershell/)
+ [Резервация для мас адреса](https://vmblog.ru/rezervaciya-adresov-dhcp-windows-server/)
+ [Add-DhcpServerv4Policy и как добавлять политику и основные ее настройки](https://learn.microsoft.com/ru-ru/powershell/module/dhcpserver/add-dhcpserverv4policy?view=windowsserver2022-ps)
+ [Вот еще инфа от майкрософта](https://learn.microsoft.com/ru-ru/windows-server/networking/technologies/dhcp/dhcp-deploy-wps)
+ [Add-DhcpServerv4PolicyIPRange и как добавить в политику диапазон, к которому она будет применяться](https://learn.microsoft.com/en-us/powershell/module/dhcpserver/add-dhcpserverv4policyiprange?view=windowsserver2022-ps)
+ [Set-DhcpServerv4Policy и как дбавить в политику условие для мас адреса](https://learn.microsoft.com/en-us/powershell/module/dhcpserver/set-dhcpserverv4policy?view=windowsserver2022-ps)
+ [Add-DhcpServerv4Failover и как включать обработку отказа (у нас акти-пассив)](https://learn.microsoft.com/en-us/powershell/module/dhcpserver/add-dhcpserverv4failover?view=windowsserver2022-ps)
+ [тут про лепликацию, но как я понял, это когда ты создаешь failover сразу на основном серваке и потои реплицируешь на остальные, но я создавал на запасных](https://learn.microsoft.com/en-us/powershell/module/dhcpserver/invoke-dhcpserverv4failoverreplication?view=windowsserver2022-ps)
+ [Из JSON](https://learn.microsoft.com/ru-ru/powershell/module/microsoft.powershell.utility/convertfrom-json?view=powershell-7.2)
+ [В JSON](https://learn.microsoft.com/ru-ru/powershell/module/microsoft.powershell.utility/convertto-json?view=powershell-7.2)
