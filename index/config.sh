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
