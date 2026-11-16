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
