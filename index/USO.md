# Declaração de Uso de Inteligência Artificial

## Identificação
* **Discente:** Alexandre Pereira Velozo
* **Ferramenta / Modelo:** Google Gemini (modelo **Gemini 4 Hydrogen**)
* **Atividade:** Análise de Desempenho do Método de Jacobi Paralelo com `perf` (Linux)

---

## Escopo e Finalidade de Uso

Em conformidade com as diretrizes de transparência acadêmica, declara-se que a ferramenta de Inteligência Artificial mencionada foi utilizada como suporte técnico e metodológico durante o desenvolvimento deste trabalho, especificamente nas seguintes frentes:

1. **Reformulação e Aprimoramento do Código de Coleta:**
   * Revisão estrutural do script de automação em *Bash* responsável pela execução dos experimentos.
   * Adequação do controle de afinidade e paralelismo (`taskset -c 0-3`, `OMP_NUM_THREADS=4` e `OMP_DYNAMIC=FALSE`), inclusão de execução prévia de aquecimento (*warm-up*) para carregamento dos binários na *page cache*, separação da coleta dos eventos de hardware (`cycles:u`, `cycles:u,instructions:u` e `branch-misses:u`) em baterias independentes para evitar multiplexação da PMU e organização da etapa pós-medição de validação numérica (`diff-mat.exec`).

2. **Análise e Consolidação de Métricas:**
   * Apoio na estruturação estatística dos resultados brutos (consolidação de média aritmética, mediana, desvio padrão $\pm 1\sigma$, coeficiente de variação $\text{CV}\%$ e cálculo de $\text{MPKI}$).
   * Conferência de escalas, unidades, barras de erro e tipos de representação gráfica produzidos no LibreOffice Calc, bem como formatação das tabelas de especificações de hardware e resultados consolidados em LaTeX.

3. **Interpretação de Conceitos Arquiteturais:**
   * Esclarecimento e aprofundamento teórico de conceitos de microarquitetura e sistemas operacionais aplicados aos fenômenos observados nos gráficos, tais como saturação da largura de banda de memória (*Memory Wall*), pressão e falhas na TLB (*Translation Lookaside Buffer*), contenção de recursos em *Simultaneous Multithreading* (SMT / *Hyper-Threading*), impacto de instruções vetoriais (`AVX`, `AVX2` e `FMA`) sobre o CPI, comportamento da predição de desvios e efeitos de mitigações do kernel (`PTI`).

4. **Aquisição de dados de hardware das máquinas utilizadas:**
    * Criação de um script em *Bash* para a extração dos dados estruturais das máquinas.
---

## Responsabilidade e Autoria

Toda a execução experimental nas máquinas de teste, a extração dos dados brutos via `perf`, a geração dos gráficos e a revisão final do texto técnico foram conduzidas e validadas integralmente por **Alexandre Velozo**, que assume total responsabilidade pela veracidade, precisão e integridade acadêmica do conteúdo apresentado.


## Detalhamento 1

Na tentativa inicial de criar um script bash com nossas experiências prévias, havíamos chegado na primeira versão da nossa automação `jacobi_run_v1.sh`:

```bash
MX_DIM=0
for k in $(seq 1 5)
do
   MX_DIM=$k

   for i in $(seq 1 3)
   do
      PARAM_EXEC=O3
      if((i==2)); then
         PARAM_EXEC="O3-native"
      fi
      if((i==3)); then
         PARAM_EXEC=O0
      fi

# 1. Executa o taskset e o perf stat, salvando as métricas limpas diretamente no arquivo de relatório
      taskset -c 0-4 perf stat -o MX_REPORT_${MX_DIM}000_${PARAM_EXEC}.txt ./solver-jacobi-mt-${PARAM_EXEC}.exec 1E-10 1 A${MX_DIM}000.bin B${MX_DIM}000.bin MX_${MX_DIM}000_${PARAM_EXEC}.bin >> MX_REPORT_${MX_DIM}000_${PARAM_EXEC}.txt

# 2. Anexa a saída do diff ao final do mesmo arquivo de relatório
      ./diff-mat.exec 1E-10 X${MX_DIM}000.bin MX_${MX_DIM}000_${PARAM_EXEC}.bin >> MX_REPORT_${MX_DIM}000_${PARAM_EXEC}.txt
   done
echo "Rodou!"
done
```

Porém devido ao escopo do projeto, e a falta de experiência sólida trabalhando com as ferramentas do ambiente Linux pedimos um incremento a nossa lógica de automação, isso deu origem a versão 2 do programa `jacobi_run_v2.sh`

```bash
#!/bin/bash

for k in $(seq 1 5)
do
   MX_DIM=$k
   DIM_REAL=$((MX_DIM * 1000))

   for i in $(seq 1 3)
   do
      if ((i == 1)); then
         PARAM_EXEC="O3"
         EXEC_NAME="solver-jacobi-mt-O3.exec"
      elif ((i == 2)); then
         PARAM_EXEC="O3-native"
         EXEC_NAME="solver-jacobi-mt-O3-native.exec"
      else
         PARAM_EXEC="O0"
         EXEC_NAME="solver-jacobi-mt-O0.exec"
      fi

      REL_FILE="MX_REPORT_${DIM_REAL}_${PARAM_EXEC}.txt"

      if [ ! -f "./$EXEC_NAME" ]; then
         continue
      fi

      # 1. Roda o perf silenciosamente (&> /dev/null joga toda a poluição visual fora)
      taskset -c 0-3 perf stat -o "$REL_FILE" \
         ./$EXEC_NAME 1E-10 1 A${DIM_REAL}.bin B${DIM_REAL}.bin MX_${DIM_REAL}_${PARAM_EXEC}.bin >> "$REL_FILE" 2>&1

      # 2. Anexa o diff também de forma silenciosa na tela
      ./diff-mat.exec 1E-10 X${DIM_REAL}.bin MX_${DIM_REAL}_${PARAM_EXEC}.bin >> "$REL_FILE" 2>&1
   done
   echo "Dimensão ${DIM_REAL} concluída."
done
```

O programa funcionou como esperado, mas não havíamos nos atentado em fazer a coleta dos dados evitando a multiplexação, quando passamos a considerar essa necessidade o modelo
de LLM também nos sugeriu métodos que otimizariam a coleta para evitar ruídos, como a execução previa para o carregamento dos binários (warm-up). Dando origem a versão final da nossa automação de coleta
`jacobi_run_v3.sh`

```bash
#!/bin/bash
# Controle fixo de threads compatível com taskset -c 0-3 (Seção 2.3)
export OMP_NUM_THREADS=4
export OMP_DYNAMIC=FALSE

# Definição das pastas de métricas e seus respectivos eventos no perf
METRICAS_DIR=("ciclos" "cpi" "branch-misses")
METRICAS_PERF=("cycles:u" "cycles:u,instructions:u" "branch-misses:u")

for k in $(seq 1 5)
do
   DIM_REAL=$((k * 1000))

   for i in $(seq 1 3)
   do
      if ((i == 1)); then
         PARAM_EXEC="O3"
         EXEC_NAME="solver-jacobi-mt-O3.exec"
      elif ((i == 2)); then
         PARAM_EXEC="O3-native"
         EXEC_NAME="solver-jacobi-mt-O3-native.exec"
      else
         PARAM_EXEC="O0"
         EXEC_NAME="solver-jacobi-mt-O0.exec"
      fi

      if [ ! -f "./$EXEC_NAME" ]; then
         echo "Aviso: ./$EXEC_NAME não encontrado, pulando..."
         continue
      fi

      # Aquecimento (warm-up) para carregar os arquivos .bin no cache do SO antes de medir
      taskset -c 0-3 ./$EXEC_NAME 1E-10 0 A${DIM_REAL}.bin B${DIM_REAL}.bin MX_${DIM_REAL}_${PARAM_EXEC}.bin > /dev/null 2>&1

      # Loop pelas 3 métricas (ciclos, cpi, branch-misses)
      for m in "${!METRICAS_DIR[@]}"
      do
         DIR_METRICA="${METRICAS_DIR[$m]}"
         EVENTO_PERF="${METRICAS_PERF[$m]}"
         OUT_DIR="M${DIM_REAL}/${PARAM_EXEC}/${DIR_METRICA}"

         # Cria a árvore de diretórios (ex: M1000/O0/ciclos)
         mkdir -p "$OUT_DIR"

         # 10 execuções independentes (01 a 10)
         for rep in $(seq -f "%02g" 1 10)
         do
            REL_FILE="${OUT_DIR}/M${DIM_REAL}-${PARAM_EXEC}-${rep}.txt"

            # 1. Roda o perf salvando a saída limpa no arquivo (-o) e silenciando o solver (> /dev/null)
            taskset -c 0-3 perf stat -o "$REL_FILE" -e "$EVENTO_PERF" \
               ./$EXEC_NAME 1E-10 0 A${DIM_REAL}.bin B${DIM_REAL}.bin MX_${DIM_REAL}_${PARAM_EXEC}.bin > /dev/null 2>&1

            # 2. Anexa a validação numérica ao final do relatório
            if [ -f "./diff-mat.exec" ]; then
               ./diff-mat.exec 1E-10 X${DIM_REAL}.bin MX_${DIM_REAL}_${PARAM_EXEC}.bin >> "$REL_FILE" 2>&1
            fi
         done
      done
      echo "Concluído: M${DIM_REAL} | Versão ${PARAM_EXEC}"
   done
done
```

## Detalhamento 2

Criação de um script para obter as configurações de cada máquina utilizada nos testes e armazedas em "logs_ambiente.txt".

```bash
#!/bin/bash

mkdir -p logs_ambiente
OUT="logs_ambiente/configuracao_ambiente.txt"

{
    echo "=========================================="
    echo "DATA DA COLETA: $(date)"
    echo "HOSTNAME: $(hostname)"
    echo "=========================================="

    echo -e "\n--- 1. CPU, NÚCLEOS E CACHES (lscpu) ---"
    lscpu

    echo -e "\n--- 2. TOPOLOGIA DETALHADA DE CPUS / P-CORES E E-CORES (lscpu -e) ---"
    lscpu -e

    echo -e "\n--- 3. PMUs EXPOSTAS PELO KERNEL (Seção 2.3 / Seção 6) ---"
    ls -d /sys/bus/event_source/devices/cpu* 2>/dev/null
    for pmu in /sys/bus/event_source/devices/cpu*; do
        if [ -f "$pmu/cpus" ]; then
            echo "$pmu/cpus: $(cat "$pmu/cpus")"
        fi
    done

    echo -e "\n--- 4. MEMÓRIA RAM INSTALADA (free -h) ---"
    free -h

    echo -e "\n--- 5. SISTEMA OPERACIONAL E KERNEL ---"
    cat /etc/os-release 2>/dev/null | grep -E "^(NAME|VERSION)="
    uname -a

    echo -e "\n--- 6. COMPILADOR GCC E RUNTIME OPENMP ---"
    gcc --version | head -n 1
    echo | gcc -fopenmp -dM -E - 2>/dev/null | grep -i "_OPENMP"
    ldd ./solver-jacobi-mt-O3.exec 2>/dev/null | grep -i "gomp"

    echo -e "\n--- 7. VERSÃO DO PERF E PARANOID ---"
    perf --version
    echo "perf_event_paranoid: $(cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null)"

    echo -e "\n--- 8. FREQUÊNCIA DINÂMICA, GOVERNOR E TURBO BOOST ---"
    echo "Governor (CPU 0): $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'N/A')"
    echo "Driver cpufreq: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null || echo 'N/A')"
    if [ -f /sys/devices/system/cpu/cpufreq/boost ]; then
        echo "AMD/Generic Boost (1=ativo, 0=desativado): $(cat /sys/devices/system/cpu/cpufreq/boost)"
    elif [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
        echo "Intel no_turbo (0=turbo ativo, 1=desativado): $(cat /sys/devices/system/cpu/intel_pstate/no_turbo)"
    fi

    echo -e "\n--- 9. CARGA CONCORRENTE NO MOMENTO ---"
    uptime
} > "$OUT"

echo "Informações salvas com sucesso em $OUT"

```
