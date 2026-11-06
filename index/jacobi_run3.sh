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
