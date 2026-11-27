# Jacobi Multithread (OpenMP) — Benchmark e Validação (`maq 1` / `lab08100` e `maq 2` / `Lab280859`)

Documentação unificada para execução, medição de desempenho e validação numérica do *solver* Jacobi multithread (`solver-jacobi-mt`) na **máquina 1** (`maq 1`, hostname `lab08100`) e na **máquina 2** (`maq 2`, hostname `Lab280859`), utilizando `perf stat` e `diff-mat.exec`.

## Visão Geral e Objetivo

Avaliar o comportamento do *solver* Jacobi multithread (`solver-jacobi-mt`) across diferentes níveis de otimização de compilação (`O3`, `O3-native` e `O0`) e dimensões de problema (`DIM_REAL` de `1000` a `5000`), comparando a **máquina 1** (`maq 1` — `lab08100`) e a **máquina 2** (`maq 2` — `Lab280859`) quanto a topologia de CPU, caches, políticas de *cpufreq* e disponibilidade de memória, enquanto se valida a correção numérica contra a matriz de referência `X<DIM>.bin`.

---

## Ambiente e Versões por Máquina

### Comparativo rápido

| Item | Máquina 1 (`maq 1` — `lab08100`) | Máquina 2 (`maq 2` — `Lab280859`) |
| :--- | :--- | :--- |
| **Hostname** | `lab08100` (`maq 1`) | `Lab280859` (`maq 2`) |
| **Data da coleta** | `16/11/2026 08:40:35 -03` | `16/11/2026 10:15:15 -03` |
| **Sistema operacional** | Ubuntu 22.04.5 LTS (Jammy Jellyfish) | Ubuntu 22.04.3 LTS (Jammy Jellyfish) |
| **Kernel** | Linux `6.8.0-138-generic` (`x86_64`) | Linux `6.8.0-138-generic` (`x86_64`) |
| **CPU** | AMD Ryzen 5 5600G (Família 25, Modelo 80, Step 0) | Intel Core i3-2120 @ 3.30GHz (Família 6, Modelo 42, Step 7) |
| **Núcleos físicos / Threads lógicas** | 6 núcleos / 12 threads (`0-11`), 1 nó NUMA | 2 núcleos / 4 threads (`0-3`), 1 nó NUMA |
| **Caches L1d / L1i / L2 / L3** | `192 KiB` (×6) / `192 KiB` (×6) / `3 MiB` (×6) / `16 MiB` (×1) | `64 KiB` (×2) / `64 KiB` (×2) / `512 KiB` (×2) / `3 MiB` (×1) |
| **Frequência nominal / observada** | `400 MHz` – `4464 MHz` | `1600 MHz` – `3300 MHz` (`~3399 MHz` na coleta) |
| **Driver / Governor / Turbo** | `amd-pstate-epp` / `powersave` / n/a (`no_turbo` não reportado) | `intel_cpufreq` / `schedutil` / `no_turbo: 1` (Turbo desativado) |
| **RAM total / Disponível na coleta** | `15 GiB` / `~12 GiB` | `3,8 GiB` / `1,6 GiB` |
| **Swap total / Em uso na coleta** | `2,0 GiB` / `0 B` | `3,9 GiB` / `672 MiB` |
| **Compilador / OpenMP** | `gcc 11.4.0` (`_OPENMP 201511`) | `gcc 11.4.0` (`_OPENMP 201511`, `libgomp.so.1`) |
| **Ferramenta `perf` / `paranoid`** | `perf 6.8.12` / `perf_event_paranoid: 2` | `perf 6.8.12` / `perf_event_paranoid: 0` |
| **Diretório PMU** | `/sys/bus/event_source/devices/cpu` | `/sys/bus/event_source/devices/cpu` |
| **Load average na coleta** | `0,06`, `0,32`, `0,66` (uptime `1:02`) | `1,52`, `1,81`, `1,16` (uptime `12 min`) |

### Detalhes da Máquina 1 (`maq 1` — `lab08100`)

* **Identificação:** Máquina 1 (`maq 1`), hostname `lab08100`.
* **SO e Kernel:** Ubuntu 22.04.5 LTS, `Linux lab08100 6.8.0-138-generic #138~22.04.1-Ubuntu SMP PREEMPT_DYNAMIC x86_64`.
* **Hardware:** 1 soquete, 6 núcleos físicos (`CORE 0-5`), 2 threads/núcleo (12 CPUs lógicas `0-11`), 1 nó NUMA (`0-11`), `15 GiB` de RAM (`~12 GiB` livres na coleta), `2,0 GiB` de swap (`0 B` em uso).
* **Frequência e medição:** *clock* entre `400 MHz` e `4464 MHz`, driver `amd-pstate-epp`, *governor* `powersave`; `perf 6.8.12` com `perf_event_paranoid: 2` e PMU em `/sys/bus/event_source/devices/cpu`.

### Detalhes da Máquina 2 (`maq 2` — `Lab280859`)

* **Identificação:** Máquina 2 (`maq 2`), hostname `Lab280859`.
* **SO e Kernel:** Ubuntu 22.04.3 LTS, `Linux Lab280859 6.8.0-138-generic #138~22.04.1-Ubuntu SMP PREEMPT_DYNAMIC x86_64`.
* **Hardware:** 1 soquete, 2 núcleos físicos (`CORE 0-1`), 2 threads/núcleo (4 CPUs lógicas `0-3`), 1 nó NUMA (`0-3`), `3,8 GiB` de RAM (`1,6 GiB` disponíveis na coleta), `3,9 GiB` de swap (`672 MiB` em uso na coleta).
* **Frequência e medição:** *clock* de `1600 MHz` a `3300 MHz` nominais (`~3399 MHz` na coleta), driver `intel_cpufreq`, *governor* `schedutil`, `no_turbo: 1` (Turbo desativado); `perf 6.8.12` com `perf_event_paranoid: 0` e PMU em `/sys/bus/event_source/devices/cpu`.

---

## Threads e Afinidade de CPU

O script de referência configura `OMP_NUM_THREADS=4`, `OMP_DYNAMIC=FALSE` e `taskset -c 0-3`. O efeito desse mapeamento muda conforme a topologia física de cada máquina:

### Mapeamento na Máquina 1 (`maq 1` — `lab08100`, 6 núcleos físicos / 12 CPUs lógicas)

| Núcleo físico (`CORE`) | Thread 0 (`CPU`) | Thread 1 (`CPU`) |
| :--- | :---: | :---: |
| `0` | `0` | `6` |
| `1` | `1` | `7` |
| `2` | `2` | `8` |
| `3` | `3` | `9` |
| `4` | `4` | `10` |
| `5` | `5` | `11` |

* Com `OMP_NUM_THREADS=4` e `taskset -c 0-3`, cada thread ocupa um núcleo físico distinto (`CORE 0` a `CORE 3`) na `maq 1` (`lab08100`), sem disputa por *SMT siblings* (`6..9`).
* Em testes exploratórios na `maq 1` (`lab08100`), 1 thread por núcleo físico corresponde a `0-5` (até 6 threads), enquanto `0-11` habilita SMT em todos os núcleos.

### Mapeamento na Máquina 2 (`maq 2` — `Lab280859`, 2 núcleos físicos / 4 CPUs lógicas)

| Núcleo físico (`CORE`) | Thread 0 (`CPU`) | Thread 1 (`CPU`) |
| :--- | :---: | :---: |
| `0` | `0` | `2` |
| `1` | `1` | `3` |

* Com `OMP_NUM_THREADS=4` e `taskset -c 0-3`, **2 threads compartilham cada núcleo físico** (`0/2` no `CORE 0` e `1/3` no `CORE 1`) na `maq 2` (`Lab280859`), dividindo unidades de execução e caches locais (`L1d`/`L1i`/`L2`).
* Para isolar 1 thread por núcleo físico na `maq 2` (`Lab280859`), utiliza-se `OMP_NUM_THREADS=2` com `taskset -c 0,1` (CPUs `0` e `1` em núcleos físicos distintos).

---

## Parâmetros e Entradas do Experimento

### Variáveis de ambiente e controle do script

| Variável / Parâmetro | Valor no script | Descrição |
| :--- | :--- | :--- |
| `OMP_NUM_THREADS` | `4` | Número fixo de threads OpenMP |
| `OMP_DYNAMIC` | `FALSE` | Impede o runtime OpenMP de alterar o número de threads em execução |
| `DIM_REAL` (`k * 1000`, `k=1..5`) | `1000`, `2000`, `3000`, `4000`, `5000` | Dimensão do problema usada para nomear os arquivos de entrada, referência e saída |
| `PARAM_EXEC` / `EXEC_NAME` | `O3` (`solver-jacobi-mt-O3.exec`), `O3-native` (`solver-jacobi-mt-O3-native.exec`), `O0` (`solver-jacobi-mt-O0.exec`) | Variantes compiladas do *solver* testadas para cada dimensão |

### Argumentos posicionais dos binários

* **Solver (`solver-jacobi-mt-*.exec`):**
  ```text
  ./<EXEC_NAME> 1E-10 0 A<DIM>.bin B<DIM>.bin MX_<DIM>_<PARAM_EXEC>.bin