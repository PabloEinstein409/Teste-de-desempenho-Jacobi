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

