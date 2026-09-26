# Optimization profile

Актуальный профиль оптимизации для IBM ThinkPad 600X (Pentium III 500 MHz,
64 MB RAM, i686, отсутствие SSE2).

## Применено (в сборке)

| Уровень | Флаг/опция | Зачем |
|---------|-----------|-------|
| CPU | `-march=pentium3` | ISA-совместимость: MMX+SSE, **без SSE2** (иначе SIGILL на PIII) |
| CPU | `-mtune=pentium3` | планировщик под 10/12-стадийный конвейер PIII |
| Опт. | `-O2` (`BR2_OPTIMIZE_2`) | баланс размер/скорость |
| Ядро | `CONFIG_CC_OPTIMIZE_FOR_SIZE` | ядро `-Os` — меньше резидентного ядра (критично для 64 MB) |
| Ядро | `CONFIG_MPENTIUMIII`, `SMP off` | точный CPU, без лишних спинов блокировок |
| Ядро | `PREEMPT` не задан → kernel-default `CONFIG_PREEMPT_NONE=y` | без принудительного вытеснения (throughput-профиль) |
| Ядро | `CONFIG_EXT4_USE_FOR_EXT2` | один FS-драйвер на ext2/3/4 |
| Сборка | `BR2_CCACHE=y` | ускорение итераций |

## Preemption: что на самом деле

В `board/thinkpad600x/linux.config` опции `PREEMPT` нет вообще
(`grep -c PREEMPT board/thinkpad600x/linux.config` → `0`), то есть выбор модели
вытеснения не настраивается проектом и остаётся на значении по умолчанию ядра.
Проверено в сгенерированном конфиге сборки
(`~/br2-out/build/linux-6.12.104/include/config/auto.conf`, linux 6.12.104):

- `CONFIG_PREEMPT_NONE=y` — «No Forced Preemption (Server)». Это значение
  выбора `choice "Preemption Model"`: в `kernel/Kconfig.preempt` у choice стоит
  `default PREEMPT_NONE`.
- `CONFIG_PREEMPT_DYNAMIC=y` — включается тоже по умолчанию, потому что сам
  символ объявлен как `default y if HAVE_PREEMPT_DYNAMIC_CALL`, а для нашей
  цели (x86) это условие выполняется: `arch/x86/Kconfig` делает
  `select HAVE_PREEMPT_DYNAMIC_CALL`. Это не альтернатива `PREEMPT_NONE`, а
  возможность сменить модель на лету: `preempt=` в cmdline. В дереве нет ни
  одной строки с `preempt=` (`grep -rn 'preempt=' .` пусто), так что переключать
  нечего.

Итоговая модель выбирается в `preempt_dynamic_init()`
(`kernel/sched/core.c`): при `IS_ENABLED(CONFIG_PREEMPT_NONE)` вызывается
`sched_dynamic_update(preempt_dynamic_none)`, то есть ядро стартует как
`Dynamic Preempt: none`.

Почему прежняя формулировка выглядела правдоподобной: строка `PREEMPT_DYNAMIC`
дейтельно попадает в бинарь (`strings release/bzImage | grep -o 'PREEMPT_[A-Z]*'`
→ `PREEMPT_DYNAMIC`) — это имя режима, поддерживаемого конфигурацией, а не
признак того, что вытеснение динамическое. Раннее утверждение «runtime
`voluntary`» не подтверждается ничем: `voluntary` не выбран ни в одном
конфиге.

> Не проверено: строка `Dynamic Preempt: none` — это сообщение раннего лога
> ядра во время загрузки (`pr_info` в `kernel/sched/core.c`), не строка build
> лога. Ни в одном логе сборки в VM (`build.log`, `build3.log`…`build9.log`)
> её нет: единственное вхождение `preempt` — это баннер самого хоста-VM
> (`Linux lima-br2 6.8.0-139-generic … PREEMPT_DYNAMIC`), то есть ядра Ubuntu,
> а не целевого ядра. Вывод выше сделан по исходникам ядра и `auto.conf`.

## Ключевой факт про SSE2

`-march=pentium3` гарантирует, что **компилятор не генерирует SSE2/SSE3/AVX**
в основном коде. Единственные SIMD-инструкции (SSE2/AVX) в бинарях — внутри
**runtime-cpuid-диспетчеризуемых** библиотек (libjpeg-turbo, OpenSSL, gnulib в
coreutils, pixman, imlib2, mpg123). На Pentium III `cpuid` не рекламирует SSE2,
и эти пути не исполняются (стандартный, 20-летний проверенный механизм).

## Рассмотрено и ОТКЛОНЕНО глобально (с причиной)

| Вариант | Вердикт | Причина |
|---------|---------|---------|
| `-O3` глобально | отклонён | рост кода → промахи i-cache на 500 MHz + 64 MB; выигрыш не доказан (Gentoo wiki рекомендует -O2) |
| `-Os` глобально | не принят глобально | применён только к ядру; user-space -O2 (баланс) |
| `-Ofast` | отклонён | ломает float-семантику (небезопасно для CDE/браузера/офиса) |
| `-flto` (LTO) глобально | отклонён | риск ломки легаси-autotools (OpenMotif/CDE) + рост времени сборки |
| `-ffunction-sections -fdata-sections` + `--gc-sections` | не применено | риск для лоадер-модулей Xorg (`libvgahw.so` и т.п. — weak-символы) |
| PGO (`-fprofile-use`) | не применено | нет представительной тренировочной нагрузки; каркас в BENCHMARKS.md |
| `-funsafe-math-optimizations` | отклонён | небезопасная численная семантика |
| PIE глобально | не отключён | Buildroot generated config uses `BR2_PIC_PIE=y`; это toolchain default, не отдельная оптимизация |
| `-mfpmath=sse` | не применяется явно | `-march=pentium3` включает SSE в ISA, но сам по себе не выбирает SSE math ABI; менять `-mfpmath` не нужно |

## Package-specific (документировано)

- Ядро: `-Os` (+ MPENTIUMIII).
- glibc/toolchain: `-O2` (управляется Buildroot, не LTO).
- CDE/OpenMotif: `-O2`; CDE добавляет `-Wno-error=*` для gcc 14, а OpenMotif
  добавляет `-include string.h`, `-include stdlib.h` и `-include stdio.h` для
  cross-build.
- mpg123/mupdf (численные): могли бы `-O3`, оставлены `-O2` (общий профиль).

## Итог

Оптимальный для этой машины профиль: **`-O2 -march=pentium3 -mtune=pentium3`**
для userspace + **`-Os`** для ядра. Полный двигатель генерации кода (`-O3`,
LTO, PGO, агрессивная векторизация SSE) на Pentium III/64 MB НЕ даёт измеримого
выигрыша и несёт риск — поэтому не применён глобально (решение по измерениям,
не по моде).