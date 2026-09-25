# Language / locale

## CDE — English only (нет русского в CDE 2.5.3)

CDE (Common Desktop Environment) **2.5.3 не содержит русской локализации**.

Проверено по исходникам (`programs/localized/`): доступны только каталоги
сообщений:

```
C (английский, дефолт)
de_DE.UTF-8  fr_FR.UTF-8  es_ES.UTF-8  it_IT.UTF-8  sv_SE.UTF-8
el_GR.UTF-8  ja_JP.UTF-8  ko_KR.UTF-8  zh_CN.UTF-8  zh_TW.UTF-8
```

`ru_RU.UTF-8` **отсутствует** (вверх по течению CDE так и не переведён на
русский). Поэтому рабочий стол CDE (dtwm/dtterm/dtfile/dtpad, меню, диалоги)
остаётся англоязычным — это ограничение самого CDE 2.5.3, а не сборки.

## System locale — C.UTF-8 запрошен, но не установлен

В `configs/thinkpad600x_defconfig` заданы `BR2_TOOLCHAIN_BUILDROOT_LOCALE=y`
и whitelist `BR2_ENABLE_LOCALE_WHITELIST="C en_US.UTF-8"`. В Buildroot
2026.05.2 `BR2_TOOLCHAIN_BUILDROOT_LOCALE` — опция uClibc; при выбранной
glibc-сборке эта строка не остаётся отдельным параметром generated `.config`.
`BR2_PACKAGE_LOCALE_SUPPORT` в этом дереве отсутствует. Whitelist ограничивает
purge locale-каталогов, но сам по себе не генерирует glibc-локаль.

`/etc/profile` и `/usr/sbin/autostart-cde` экспортируют `LANG=C.UTF-8` и
`LC_ALL=C.UTF-8`; `/etc/locale.conf` в фактическом образе отсутствует.
`C.UTF-8` — валидное имя поддерживаемой glibc 2.43 locale, но glibc не встраивает
её в libc: locale должна быть сгенерирована и установлена. В текущем `rootfs`
нет ни `/usr/lib/locale/locale-archive`, ни данных `C.UTF-8`, поэтому export сам
по себе не гарантирует UTF-8 locale (при неудачном `setlocale` процесс остаётся
в `C`). Каталоги X11 `en_US.UTF-8` — отдельные X11-данные, не glibc locale.
В образе также нет BusyBox locale support: в его config
`# CONFIG_LOCALE_SUPPORT is not set`. Exports задают запрошенное UTF-8-окружение
для `btop`, `fastfetch` и терминалов, но не заменяют locale-данные.

## Как включить русский в консоли (опционально)

Сам CDE останется англоязычным, но **системную локаль можно переключить на
русскую** для консольных утилит (`ls`, `date`, сообщения `btop`, `fastfetch`).
В текущем образе нет target-утилиты `localedef`; locale генерируется на этапе
сборки Buildroot 2026.05.2 через его host-инструмент:

```sh
# 1. В конфигурации Buildroot добавить locale и пересобрать образ:
BR2_ENABLE_LOCALE_WHITELIST="C en_US.UTF-8 ru_RU.UTF-8"
BR2_GENERATE_LOCALE="C.UTF-8 en_US.UTF-8 ru_RU.UTF-8"

# 2. Переключить окружение (на лету или в /etc/profile):
export LANG=ru_RU.UTF-8
export LC_ALL=ru_RU.UTF-8
```

`BR2_GENERATE_LOCALE` для glibc создаёт `/usr/lib/locale/locale-archive` через
`localedef` на build host; текущий defconfig оставляет эту опцию пустой. После
пересборки `C.UTF-8` и `ru_RU.UTF-8` можно выбирать в системе. CDE всё равно
остаётся английским, потому что в CDE 2.5.3 нет русского перевода. Базовый
образ без locale-архива фактически остаётся в `C`, хотя `/etc/profile` запрашивает
`C.UTF-8`; это позволяет не добавлять лишнюю генерацию локалей на 64 MB-машине.
